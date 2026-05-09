# PaddleQ — Project Context for Claude Code

> This document captures the design decisions, architecture, and current state of the PaddleQ backend, intended as context for AI assistants helping build the Flutter frontend. Read this carefully before writing any code.

---

## What PaddleQ Is

PaddleQ is a queueing app for pickleball venues. A host runs a session, players check in by QR code, and the system forms balanced matches and rotates players through courts. The MVP target is **one venue, phone-first**, deployed as a Flutter Web PWA.

### Primary users

1. **Host (front desk):** Runs sessions, sees the queue dashboard, completes matches. Uses a phone (Android) or tablet at the venue.
2. **Players:** Check in via QR code, see their queue status, view their profile. Use their personal phones.
3. **Public viewers (future):** Visit player profile pages to see match history. Not yet built.

---

## Tech Stack

### Backend (built and working)

- **ASP.NET Core Web API** (.NET 8)
- **Entity Framework Core** for data access
- **SQL Server** (managed via SSMS, schema built by hand — not using EF migrations)
- **Swagger / Swashbuckle** with annotations for API documentation
- Layered architecture:
  - `PaddleQ.API` — controllers, services, DTOs
  - `PaddleQ.DAL` — entities, repositories, DbContext

### Frontend (to be built)

- **Flutter Web** with PWA support
- **Phone-first responsive design**, expanding to tablet/desktop later
- One codebase serves Host view and Player view (route-based or context-based switching)
- Deployment target: Cloudflare Pages or similar static host
- Backend deployment target: Azure App Service + Azure SQL (eventually)

---

## Architecture Principles

These shaped every backend decision and should inform the frontend:

1. **Layered separation.** Controllers handle HTTP, services handle business logic, repositories handle data. The frontend should mirror this with separate concerns: UI widgets, API client, state management.
2. **DTOs are contracts.** The backend never returns raw EF entities — everything is mapped to a DTO. The frontend should have matching Dart model classes that mirror these DTOs exactly.
3. **UTC everywhere.** All datetimes in the API are UTC (ISO 8601). The frontend should display in local time but never store or transmit anything but UTC.
4. **Public vs. internal IDs.** Players have an internal `int Id` (used for FK relationships) and a `PublicId` (GUID, exposed in the API). The frontend only ever sees and uses GUIDs. Sessions and matches use int IDs because they're not publicly addressable.
5. **HTTP status codes are meaningful.**
   - 200 OK for successful reads/updates
   - 201 Created for new resources (with Location header)
   - 400 for validation failures
   - 404 for missing resources
   - 409 for state conflicts (e.g., "session already active", "player already in queue", "all courts full")
   - The frontend should handle each appropriately.

---

## Domain Model

### Player

A registered person who can play. Players are persistent across sessions.

- `Id` (int, internal) / `PublicId` (GUID, exposed)
- `Name` (string, 1–100 chars)
- `SkillLevel` (decimal, must be one of: 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0 — self-rated USA pickleball tier)
- `QrCode` (permanent string, used for check-in)
- `Wins`, `Losses` (cumulative across sessions)
- `CreatedAt` (UTC datetime)

### Session

A block of organized play. **Only one Session can be Active at a time** (enforced).

- `Id` (int)
- `Name` (optional string, e.g. "Tuesday Open Play")
- `MatchType` ("Singles" or "Doubles")
- `NumberOfCourts` (1–20)
- `Status` ("Active" or "Closed")
- `StartedAt`, `EndedAt` (UTC datetimes)

Hosts manually create sessions when ready (no scheduling). Sessions have no preset duration — they end when the host says so.

### QueueEntry

A player's state within a session. Created on first check-in, updated as they move through statuses.

- `Id` (int)
- `PlayerId`, `SessionId` (FKs)
- `Status` — finite state machine: `Waiting` → `Playing` → `Waiting` (rotation), or `Waiting` ↔ `Resting` (voluntary leave/rejoin), terminal: `Finished`, `NoShow`
- `GamesPlayed` (int, increments after each completed match — used for fairness sort)
- `CreatedAt`, `CheckedInAt`, `LastPlayedAt` (UTC datetimes)

### Match

A game between 2 (singles) or 4 (doubles) players.

- `Id` (int)
- `MatchType`, `Status` (`Pending`, `InProgress`, `Completed`, `Cancelled`)
- `WinningTeam` (1, 2, or null until completed)
- `CourtNumber` (1–N, assigned when match starts)
- `StartedAt`, `CompletedAt`, `CreatedAt` (UTC datetimes)
- `SessionId` (FK)

### MatchPlayer (join table)

Links players to a match with their team assignment.

- `MatchId`, `PlayerId` (FKs)
- `Team` (1 or 2)

A singles match has 2 MatchPlayer rows; a doubles match has 4 (two per team).

---

## Matchmaking Algorithm (summary)

The backend automatically forms matches when the host clicks "Form Next Match." The frontend doesn't implement this logic — it just calls the endpoint and renders the result.

**The algorithm:**

1. Build candidate pool from QueueEntries with `Status = Waiting`, sorted by:
   - `GamesPlayed` ascending (fewest games first)
   - `LastPlayedAt` ascending (longest waiting first; nulls treated as "never played" and sorted first)
   - `CreatedAt` ascending (earliest check-in as final tiebreaker)
2. Pick the **anchor** = top of pool. They're guaranteed to play.
3. Find skill-compatible partners:
   - Default: strict match (same SkillLevel)
   - Fallback (only if `allowSkillMix=true` query param): ±0.5 SkillLevel
4. Prefer partners who **didn't play with the anchor in their previous match** (repeat avoidance — soft preference, not a hard rule)
5. Split into teams (random for doubles)
6. Atomically: create Match (`Status: InProgress`), create MatchPlayers, move QueueEntries from Waiting → Playing, assign next available court

**On match completion:**
- Match status becomes `Completed`
- Winning team's players: Wins++; Losing team's players: Losses++
- All players' QueueEntries: Status back to Waiting, GamesPlayed++, LastPlayedAt = now

**Full rotation** (no king-of-the-court): everyone goes back to the queue after a match.

---

## API Endpoints Reference

Base URL: `https://localhost:7276` (dev). All bodies JSON. All datetimes UTC ISO 8601.

### Players

#### `POST /api/players` — Register a player
**Request:**
```json
{ "name": "Alice Chen", "skillLevel": 3.5 }
```
**Response 201:**
```json
{
  "id": "8f2a1c3d-9b4e-4a12-bc55-9d2e1f4a3b8c",
  "name": "Alice Chen",
  "skillLevel": 3.5,
  "qrCode": "abc123def456...",
  "wins": 0,
  "losses": 0,
  "createdAt": "2026-05-07T18:30:00Z"
}
```
**Errors:** 400 (invalid input)

#### `GET /api/players/{publicId}` — Get player profile by GUID
**Response 200:** same shape as above
**Errors:** 404

---

### Sessions

#### `POST /api/sessions` — Start a session (immediately Active)
**Request:**
```json
{ "name": "Tuesday Open Play", "matchType": "Doubles", "numberOfCourts": 4 }
```
- `name` optional, max 100 chars
- `matchType`: "Singles" or "Doubles"
- `numberOfCourts`: 1–20

**Response 201:**
```json
{
  "id": 1,
  "name": "Tuesday Open Play",
  "matchType": "Doubles",
  "numberOfCourts": 4,
  "status": "Active",
  "startedAt": "2026-05-07T18:30:00Z",
  "endedAt": null
}
```
**Errors:** 400 (invalid input), 409 (already an active session)

#### `GET /api/sessions` — List all sessions, most recent first
**Response 200:** array of session objects

#### `GET /api/sessions/active` — Get currently active session
**Response 200:** session object
**Errors:** 404 (no active session)

#### `GET /api/sessions/{id}` — Get session by ID
**Response 200:** session object
**Errors:** 404

#### `POST /api/sessions/{id}/end` — End the session
Closes Waiting/Resting queue entries (sets to Finished). Refuses if any matches are still in progress.
**Response 200:** updated session with Status="Closed"
**Errors:** 404, 409 (not Active, or matches still in progress)

#### `PUT /api/sessions/{id}` — Update session settings (partial update)
**Request:** any subset of `{ name, matchType, numberOfCourts }`
**Response 200:** updated session
**Errors:** 404, 409 (not Active)

---

### Queue

#### `POST /api/queue/check-in` — Check player in by QR code
Idempotent for Resting players: reactivates their entry rather than creating a duplicate.

**Request:**
```json
{ "qrCode": "abc123def456..." }
```
**Response 200:**
```json
{
  "queueEntryId": 42,
  "playerId": "8f2a1c3d-...",
  "playerName": "Alice Chen",
  "skillLevel": 3.5,
  "status": "Waiting",
  "checkedInAt": "2026-05-07T18:35:00Z"
}
```
**Errors:** 404 (no player for QR), 409 (no active session, already in queue, or already Finished)

#### `POST /api/queue/leave` — Player leaves queue (becomes Resting)
**Request:** same as check-in (just the QR code)
**Response 200:**
```json
{
  "queueEntryId": 42,
  "playerId": "8f2a1c3d-...",
  "playerName": "Alice Chen",
  "status": "Resting",
  "leftAt": "2026-05-07T19:15:00Z"
}
```
**Errors:** 404 (no player), 409 (no active session, not in queue, already Resting, or currently Playing)

#### `GET /api/queue` — Full queue for active session
Returns session info, all entries, and a status summary.

**Response 200:**
```json
{
  "activeSession": {
    "id": 1,
    "name": "Tuesday Open Play",
    "matchType": "Doubles",
    "numberOfCourts": 4,
    "status": "Active",
    "startedAt": "2026-05-07T18:30:00Z",
    "endedAt": null
  },
  "entries": [
    {
      "queueEntryId": 42,
      "playerId": "8f2a1c3d-...",
      "playerName": "Alice Chen",
      "skillLevel": 3.5,
      "status": "Waiting",
      "gamesPlayed": 0,
      "createdAt": "2026-05-07T18:35:00Z",
      "checkedInAt": "2026-05-07T18:35:00Z",
      "lastPlayedAt": null
    }
  ],
  "summary": {
    "waiting": 5,
    "playing": 4,
    "resting": 2,
    "finished": 0,
    "noShow": 0,
    "total": 11
  }
}
```

**If no active session:** returns 200 with `activeSession: null`, empty entries, all summary counts 0. Never returns an error for missing session.

---

### Matches

#### `POST /api/matches/next` — Form the next match
**Query parameter:** `allowSkillMix` (bool, default false). When true, allows ±0.5 skill range fallback.

**Request body:** none

**Response 200:**
```json
{
  "match": {
    "id": 7,
    "matchType": "Doubles",
    "status": "InProgress",
    "courtNumber": 2,
    "winningTeam": null,
    "startedAt": "2026-05-07T18:40:00Z",
    "completedAt": null,
    "players": [
      { "playerId": "8f2a...", "playerName": "Alice Chen", "skillLevel": 3.5, "team": 1 },
      { "playerId": "5b1c...", "playerName": "Bob Patel", "skillLevel": 3.5, "team": 1 },
      { "playerId": "9d3f...", "playerName": "Carol Lee", "skillLevel": 3.5, "team": 2 },
      { "playerId": "2e4a...", "playerName": "Dave Kumar", "skillLevel": 3.5, "team": 2 }
    ]
  },
  "usedSkillMix": false,
  "message": null
}
```
When `usedSkillMix: true`, `message` will explain. UI should highlight this so the host knows.

**Errors:** 409 (no active session, all courts in use, or insufficient compatible players). The 409 message text suggests retrying with `allowSkillMix=true` when applicable — UI should detect this and offer a retry button.

#### `POST /api/matches/{id}/complete` — Record match result
**Request:**
```json
{ "winningTeam": 1 }
```
- `winningTeam`: 1 or 2

**Response 200:** completed match object
**Errors:** 404, 409 (not InProgress)

#### `GET /api/matches/{id}` — Get match details
**Response 200:** match object
**Errors:** 404

#### `GET /api/matches/active` — List in-progress matches in active session
Ordered by court number.
**Response 200:** array of match objects (empty if no active session)

---

## UI → API Mapping

### Player view

| UI Element | Endpoint |
|---|---|
| Registration form | `POST /api/players` |
| Profile page | `GET /api/players/{publicId}` |
| "Check me in" button | `POST /api/queue/check-in` |
| "Leave queue / take a break" button | `POST /api/queue/leave` |
| "I'm back" button (after resting) | `POST /api/queue/check-in` (same endpoint handles reactivation) |

### Host view

| UI Element | Endpoint |
|---|---|
| "Start Session" form | `POST /api/sessions` |
| Session header (always visible) | `GET /api/sessions/active` |
| "End Session" button | `POST /api/sessions/{id}/end` |
| Edit session settings | `PUT /api/sessions/{id}` |
| Main queue dashboard | `GET /api/queue` |
| "Form Next Match" button | `POST /api/matches/next` |
| "Try with skill mix" retry button (after 409) | `POST /api/matches/next?allowSkillMix=true` |
| Court status panel | `GET /api/matches/active` |
| Match details (tap a court) | `GET /api/matches/{id}` |
| "Team 1 won" / "Team 2 won" | `POST /api/matches/{id}/complete` |
| Manual player check-in (host scans/types QR) | `POST /api/queue/check-in` |

---

## Error Response Shape

All error responses use this shape:
```json
{ "message": "Human-readable explanation" }
```

Validation errors (400) come in ASP.NET Core's standard `ValidationProblemDetails` format with field-specific messages.

**UI handling guidance:**
- 404: friendly "not found" with retry where applicable
- 409: show `message` directly — it's written to be user-readable
- 400: surface field-level errors next to form inputs
- 500 / network: "Something went wrong, please try again"

---

## Design Decisions and Why

These came up in design discussions and shaped the system. Future changes should respect these unless explicitly revisited.

1. **Strict skill matching by default, ±0.5 only on host opt-in.** Fairness over convenience. The host explicitly chooses the tradeoff per match.
2. **Per-session `GamesPlayed` counter, not "target games."** Late arrivals are handled naturally by sorting on fewest-games-first; no special "catch-up" logic that could feel unfair.
3. **One Session active at a time.** MVP simplification. Multi-tenancy / multi-session is a future migration.
4. **QR code on Player (permanent), not on QueueEntry.** Players have one QR forever; check-in creates queue entries against it.
5. **PublicId (GUID) for player URLs, internal int Id for FKs.** Best of both worlds: fast joins, non-enumerable public addresses.
6. **Full rotation, no king-of-the-court.** Everyone returns to queue after a match.
7. **Repeat-avoidance is a preference, not a hard rule.** With small queues (<6 players) it's mathematically impossible to always avoid repeats; the algorithm degrades gracefully.
8. **Sessions are manually started/ended.** No scheduled times. No pressure if the host arrives late.
9. **Closing a session cleans up automatically.** Waiting/Resting entries become Finished. In-progress matches block session end (safety).
10. **UTC everywhere in storage and API.** Local time is a display-only concern.

---

## What's NOT Built Yet

The frontend will need to handle these gracefully when they don't exist, and the backend will need extending when it's time:

- **Frontend (Flutter)** — this is what we're building now
- **Multi-venue / multi-tenancy** — currently one venue; design discussed but not implemented
- **User accounts / authentication** — currently no auth; the API is wide open
- **Pair-locked partners** — players who want to always be on the same team
- **Public player profiles** — viewable by anyone, deep-linkable
- **Match history queries** — `GET /api/matches?playerId=...&from=...&to=...` style
- **Offline support** — no caching/queue for actions taken while offline
- **Push notifications** — "Your match is on Court 3"
- **Camera-based QR scanning** — currently the API takes a QR string; the frontend will handle scanning

---

## Frontend Build Strategy

When implementing, work in **vertical slices** rather than building all data layers then all UI:

1. **Project scaffolding** — Flutter Web project, PWA config, folder structure, API client class, simple `Responsive` helper widget for mobile/tablet/desktop branches. Don't implement screens yet.
2. **Player check-in slice** — one screen, fully wired, end-to-end with the real backend, before moving on.
3. **Host queue dashboard slice** — pulls `GET /api/queue`, displays grouped by status, refreshes on demand.
4. **Form-next-match slice** — button that calls the endpoint, handles the 409+retry-with-skill-mix flow, shows the formed match.
5. **Match completion slice** — record winner, players return to queue.
6. **Polish, navigation, error handling.**

Each slice should be **tested against the running backend** before moving on. Don't accept generated code that hasn't been verified to work end-to-end.

---

## Frontend Conventions to Adopt

These will keep the frontend code clean and consistent with the backend's quality:

- **One Dart model per backend DTO**, with `fromJson` / `toJson`. Don't pass raw maps around.
- **API client class** centralizes HTTP — no `http.get` calls scattered through widgets.
- **Phone-first responsive layouts** using a custom `Responsive` widget; don't reach for a package until you've outgrown the simple version.
- **Material Design 3** as the visual base.
- **Flutter's built-in `setState`** for state management at first; introduce Riverpod/Bloc only when state coordination across screens demands it.
- **All datetimes parsed as UTC** then converted to local for display.
- **Errors surfaced with their backend `message` field** when present — don't swallow useful error info.

---

*This document was generated from a multi-week design conversation between the developer and Claude. When in doubt about a design decision, ask the developer rather than guessing.*
