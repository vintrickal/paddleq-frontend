import 'package:paddleq/core/api/api_client.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/models/queue_dtos.dart';
import 'package:paddleq/core/models/session_dtos.dart';

/// High-level facade for the PaddleQ backend.
///
/// One method per endpoint in api-spec.json. Cubits depend on this; widgets
/// never. Errors propagate as [ApiException] from the underlying [ApiClient].
class PaddleqApi {
  PaddleqApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  String get baseUrl => _client.baseUrl;

  void close() => _client.close();

  // ─── Players ─────────────────────────────────────────────────────────────

  /// `POST /api/players` — register a new player.
  Future<PlayerResponse> registerPlayer(CreatePlayerRequest body) async {
    final json = await _client.postJson('/api/players', body: body.toJson());
    return PlayerResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/players/{publicId}` — fetch a player by their public GUID.
  Future<PlayerResponse> getPlayer(String publicId) async {
    final json = await _client.getJson('/api/players/$publicId');
    return PlayerResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/players/search?name=...` — case-insensitive name search;
  /// returns up to 20 matches with each player's current queue status
  /// when an active session is running.
  Future<List<PlayerSearchResult>> searchPlayers(String name) async {
    final json = await _client.getJson(
      '/api/players/search',
      query: {'name': name},
    );
    return (json as List)
        .map((e) => PlayerSearchResult.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `PUT /api/players/{publicId}` — partial update of a player's profile
  /// (name and/or skill level). Returns the updated [PlayerResponse].
  Future<PlayerResponse> updatePlayer(
    String publicId,
    UpdatePlayerRequest body,
  ) async {
    final json =
        await _client.putJson('/api/players/$publicId', body: body.toJson());
    return PlayerResponse.fromJson(json as Map<String, dynamic>);
  }

  // ─── Sessions ────────────────────────────────────────────────────────────

  /// `POST /api/sessions` — start a new session (immediately Active).
  /// Throws [ApiException] with statusCode 409 if a session is already active.
  Future<SessionResponse> startSession(CreateSessionRequest body) async {
    final json = await _client.postJson('/api/sessions', body: body.toJson());
    return SessionResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/sessions` — list sessions, most recent first.
  Future<List<SessionResponse>> listSessions() async {
    final json = await _client.getJson('/api/sessions');
    return (json as List)
        .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /api/sessions/active` — fetch the currently active session.
  /// Throws [ApiException] with statusCode 404 if none.
  Future<SessionResponse> getActiveSession() async {
    final json = await _client.getJson('/api/sessions/active');
    return SessionResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/sessions/{id}` — fetch by id.
  Future<SessionResponse> getSession(int id) async {
    final json = await _client.getJson('/api/sessions/$id');
    return SessionResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `PUT /api/sessions/{id}` — partial update of an active session.
  Future<SessionResponse> updateSession(
    int id,
    UpdateSessionRequest body,
  ) async {
    final json = await _client.putJson('/api/sessions/$id', body: body.toJson());
    return SessionResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `POST /api/sessions/{id}/end` — close the session.
  Future<SessionResponse> endSession(int id) async {
    final json = await _client.postJson('/api/sessions/$id/end');
    return SessionResponse.fromJson(json as Map<String, dynamic>);
  }

  // ─── Queue ───────────────────────────────────────────────────────────────

  /// `POST /api/queue/check-in` — scan a player into the active session.
  /// Idempotent for resting players (reactivates without duplicating).
  Future<CheckInResponse> checkIn(CheckInRequest body) async {
    final json = await _client.postJson('/api/queue/check-in', body: body.toJson());
    return CheckInResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `POST /api/queue/check-in-by-id` — manual check-in by player public id
  /// (used when the QR code is unavailable and we identified the player
  /// via name search). Same response shape and idempotency as `checkIn`.
  Future<CheckInResponse> checkInById(CheckInByIdRequest body) async {
    final json = await _client.postJson(
      '/api/queue/check-in-by-id',
      body: body.toJson(),
    );
    return CheckInResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `POST /api/queue/leave` — Waiting → Resting. Refused while Playing.
  Future<LeaveQueueResponse> leaveQueue(CheckInRequest body) async {
    final json = await _client.postJson('/api/queue/leave', body: body.toJson());
    return LeaveQueueResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/queue` — full queue snapshot for the active session.
  /// Returns an empty payload (no error) when there's no active session.
  Future<QueueResponse> getQueue() async {
    final json = await _client.getJson('/api/queue');
    return QueueResponse.fromJson(json as Map<String, dynamic>);
  }

  // ─── Matches ─────────────────────────────────────────────────────────────

  /// `POST /api/matches/next` — form the next match.
  ///
  /// When [courtNumber] is supplied, the backend pins the match to that
  /// specific court (the host tapped a particular empty court and expects
  /// it to be the assignment). Omitted → backend picks the lowest free
  /// court automatically.
  ///
  /// On 409, the backend message hints whether retrying with [allowSkillMix]
  /// could succeed. UI should surface this for a one-tap retry button.
  Future<FormMatchResponse> formNextMatch({
    bool allowSkillMix = false,
    int? courtNumber,
  }) async {
    final json = await _client.postJson(
      '/api/matches/next',
      query: {
        'allowSkillMix': allowSkillMix,
        if (courtNumber != null) 'courtNumber': courtNumber,
      },
    );
    return FormMatchResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `POST /api/matches/{id}/complete` — record the winning team.
  Future<MatchResponse> completeMatch(int id, CompleteMatchRequest body) async {
    final json = await _client.postJson(
      '/api/matches/$id/complete',
      body: body.toJson(),
    );
    return MatchResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `POST /api/matches/{id}/void` — cancels an in-progress match where a
  /// player became unavailable. No counters increment; the court frees up.
  Future<MatchResponse> voidMatch(int id, VoidMatchRequest body) async {
    final json = await _client.postJson(
      '/api/matches/$id/void',
      body: body.toJson(),
    );
    return MatchResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/matches/{id}` — fetch a match by id.
  Future<MatchResponse> getMatch(int id) async {
    final json = await _client.getJson('/api/matches/$id');
    return MatchResponse.fromJson(json as Map<String, dynamic>);
  }

  /// `GET /api/matches/active` — in-progress matches, ordered by court.
  Future<List<MatchResponse>> getActiveMatches() async {
    final json = await _client.getJson('/api/matches/active');
    return (json as List)
        .map((e) => MatchResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /api/matches/history` — completed matches in the active session,
  /// newest first. Empty when there's no active session.
  Future<List<MatchResponse>> getMatchHistory() async {
    final json = await _client.getJson('/api/matches/history');
    return (json as List)
        .map((e) => MatchResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `GET /api/matches/leaderboard` — players in the active session ranked
  /// by wins → win-rate → games-played. Empty when there's no active
  /// session or no completed matches yet.
  Future<List<LeaderboardEntryResponse>> getLeaderboard() async {
    final json = await _client.getJson('/api/matches/leaderboard');
    return (json as List)
        .map((e) => LeaderboardEntryResponse.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
