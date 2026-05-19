import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/models/queue_dtos.dart';
import 'package:paddleq/core/storage/court_names_store.dart';
import 'package:paddleq/features/home/cubit/home_cubit.dart';

part 'court_state.dart';

class CourtCubit extends Cubit<CourtState> {
  CourtCubit({
    required PaddleqApi api,
    required GameMode mode,
    required int courtCount,
    String sessionName = '',
    int? sessionId,
    CourtNamesStore? courtNamesStore,
  })  : _api = api,
        _courtNamesStore = courtNamesStore ?? CourtNamesStore(),
        super(
          CourtState(
            mode: mode,
            courtCount: courtCount,
            currentCourt: 1,
            tab: CourtTab.courts,
            filter: PlayerFilter.all,
            players: const [],
            sessionName: sessionName,
            sessionId: sessionId,
          ),
        ) {
    if (sessionId != null) unawaited(_hydrateCourtNames(sessionId));
  }

  final PaddleqApi _api;
  final CourtNamesStore _courtNamesStore;

  /// Pulls any previously-saved court labels for this session out of
  /// SharedPreferences (which is `localStorage` on web). Only applies when
  /// the user hasn't already started renaming during this run — we don't
  /// want to clobber in-flight edits with a slow-loading hydration.
  Future<void> _hydrateCourtNames(int sessionId) async {
    final saved = await _courtNamesStore.load(sessionId);
    if (isClosed || saved.isEmpty) return;
    if (state.courtNames.isNotEmpty) return;
    emit(state.copyWith(courtNames: saved));
  }
  Timer? _flashTimer;

  void selectTab(CourtTab tab) => emit(state.copyWith(tab: tab));
  void selectFilter(PlayerFilter f) => emit(state.copyWith(filter: f));

  void prevCourt() {
    if (state.currentCourt <= 1) return;
    emit(state.copyWith(currentCourt: state.currentCourt - 1));
  }

  void nextCourt() {
    if (state.currentCourt >= state.courtCount) return;
    emit(state.copyWith(currentCourt: state.currentCourt + 1));
  }

  void jumpToCourt(int idx) {
    final clamped = idx.clamp(1, state.courtCount);
    emit(state.copyWith(currentCourt: clamped));
  }

  /// Renames the court at [idx] for this session. Trimmed; an empty name
  /// clears the override and the UI reverts to the default `Court N` label.
  ///
  /// Persisted to [CourtNamesStore] keyed by [CourtState.sessionId] so the
  /// rename survives browser refreshes. The backend doesn't know about
  /// court labels — this is purely a client-side convenience.
  void renameCourt(int idx, String name) {
    final trimmed = name.trim();
    final next = Map<int, String>.from(state.courtNames);
    if (trimmed.isEmpty) {
      next.remove(idx);
    } else {
      next[idx] = trimmed;
    }
    emit(state.copyWith(courtNames: next));

    final id = state.sessionId;
    if (id != null) unawaited(_courtNamesStore.save(id, next));
  }

  /// Pulls the current session snapshot from the server in one shot:
  /// `GET /api/queue` (roster), `GET /api/matches/active` (live courts),
  /// `GET /api/matches/history` (completed matches), and
  /// `GET /api/matches/leaderboard` (per-session standings).
  ///
  /// All four are fetched in parallel via [Future.wait] so the page
  /// hydrates in roughly the time of the slowest response. The matches-
  /// active payload is also used to map each player to the court they're
  /// currently on (the queue endpoint doesn't carry that).
  ///
  /// Called automatically when [CourtPage] mounts so the list survives
  /// in-app navigation. Safe to call again at any time; the
  /// [QueueLoadStatus] field reflects the in-flight state.
  Future<void> loadQueue() async {
    emit(state.copyWith(
      queueStatus: QueueLoadStatus.loading,
      clearQueueError: true,
    ));
    try {
      final results = await Future.wait<Object>([
        _api.getQueue(),
        _api.getActiveMatches(),
        _api.getMatchHistory(),
        _api.getLeaderboard(),
      ]);
      final response = results[0] as QueueResponse;
      final matches = results[1] as List<MatchResponse>;
      final history = results[2] as List<MatchResponse>;
      final leaderboard = results[3] as List<LeaderboardEntryResponse>;

      final courtByPlayer = <String, int>{};
      for (final match in matches) {
        final court = match.courtNumber;
        if (court == null) continue;
        for (final mp in match.players) {
          courtByPlayer[mp.playerId] = court;
        }
      }

      final mapped = response.entries
          .map((e) => Player(
                id: e.playerId,
                name: e.playerName,
                skill: _formatSkill(e.skillLevel),
                status: _statusFromResponse(e.status),
                court: courtByPlayer[e.playerId],
                gamesPlayed: e.gamesPlayed,
              ))
          .toList(growable: false);
      emit(state.copyWith(
        players: mapped,
        activeMatches: matches,
        matchHistory: history,
        leaderboard: leaderboard,
        queueStatus: QueueLoadStatus.success,
        clearQueueError: true,
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(
        queueStatus: QueueLoadStatus.failure,
        queueError: e.message,
      ));
    }
  }

  /// `POST /api/matches/next` — asks the matchmaker to form the next match.
  ///
  /// When [courtNumber] is supplied, the backend pins the match to that
  /// specific court. This is what the host expects when they tap "Queue
  /// Players" on a particular empty court card (otherwise the matchmaker
  /// would silently put the new match on the lowest-numbered free court).
  /// Omitted → backend picks the lowest free court itself.
  ///
  /// On success the cubit refreshes the snapshot so the new match appears
  /// on the assigned court. Re-throws [ApiException] so the view can
  /// present the skill-mix retry dialog on a 409.
  Future<FormMatchResponse> formNextMatch({
    bool allowSkillMix = false,
    int? courtNumber,
  }) async {
    final response = await _api.formNextMatch(
      allowSkillMix: allowSkillMix,
      courtNumber: courtNumber,
    );
    final court = response.match.courtNumber;
    _flash(response.usedSkillMix
        ? 'Match formed (skill mix · court $court)'
        : 'Match formed on court $court');
    await loadQueue();
    return response;
  }

  /// `POST /api/matches/{id}/complete` — records the winning team for the
  /// match currently on [courtIdx]. Refreshes the snapshot afterwards so
  /// the players return to the queue.
  ///
  /// No-ops with a flash if the local state has no record of a match on
  /// that court (out-of-sync). Re-throws [ApiException] for the view.
  Future<void> completeMatchOnCourt(int courtIdx, int winningTeam) async {
    final match = state.matchOnCourt(courtIdx);
    if (match == null) {
      _flash('No active match on court $courtIdx');
      return;
    }
    await _api.completeMatch(
      match.id,
      CompleteMatchRequest(winningTeam: winningTeam),
    );
    _flash('Team $winningTeam wins court $courtIdx!');
    await loadQueue();
  }

  /// `POST /api/matches/{id}/void` — cancels the match on [courtIdx]
  /// because [unavailablePlayerId] can't continue. Backend moves that
  /// player to Resting, returns the others to Waiting, and frees the
  /// court without touching any W/L/games counters.
  ///
  /// No-ops with a flash if state has no record of a match on the
  /// court. Re-throws [ApiException] for the view to surface.
  Future<void> voidMatchOnCourt(
    int courtIdx, {
    required String unavailablePlayerId,
    String? reason,
  }) async {
    final match = state.matchOnCourt(courtIdx);
    if (match == null) {
      _flash('No active match on court $courtIdx');
      return;
    }
    await _api.voidMatch(
      match.id,
      VoidMatchRequest(
        unavailablePlayerId: unavailablePlayerId,
        reason: reason,
      ),
    );
    _flash('Court $courtIdx — match cancelled');
    await loadQueue();
  }

  /// `POST /api/queue/check-in` — checks a player into the active session
  /// using their permanent QR code. Inserts the resulting player into the
  /// local list (or updates them if their playerId is already known).
  ///
  /// Returns the [CheckInResponse] so the view can show success feedback.
  /// Re-throws [ApiException] on failure.
  Future<CheckInResponse> checkInByQrCode(String qrCode) async {
    final response = await _api.checkIn(CheckInRequest(qrCode: qrCode));
    _upsertPlayer(Player(
      id: response.playerId,
      name: response.playerName,
      skill: _formatSkill(response.skillLevel),
      status: _statusFromResponse(response.status),
    ));
    _flash('${response.playerName} — checked in');
    return response;
  }

  /// `POST /api/queue/check-in-by-id` — manual check-in when the player's
  /// QR isn't available; we identified them via name search and use their
  /// public id directly. Same local upsert + flash as the QR flow.
  Future<CheckInResponse> checkInByPlayerId(String playerId) async {
    final response =
        await _api.checkInById(CheckInByIdRequest(playerId: playerId));
    _upsertPlayer(Player(
      id: response.playerId,
      name: response.playerName,
      skill: _formatSkill(response.skillLevel),
      status: _statusFromResponse(response.status),
    ));
    _flash('${response.playerName} — checked in');
    return response;
  }

  /// `POST /api/queue/leave` — moves a Waiting player to Resting using
  /// their permanent QR code. Backend rejects this with 409 while the
  /// player is currently Playing; surfaced via [ApiException] for the view.
  Future<LeaveQueueResponse> restPlayer(String qrCode) async {
    final response = await _api.leaveQueue(CheckInRequest(qrCode: qrCode));
    _flash('${response.playerName} — resting');
    await loadQueue();
    return response;
  }

  /// `PUT /api/players/{publicId}` — full replacement of the player's
  /// editable profile. Both [name] and [skillLevel] are sent on every
  /// call so the backend never defaults a missing field to zero and
  /// trips its own skill-range validator. Refreshes the snapshot so
  /// the new values flow through the queue list and the live court
  /// display. Re-throws [ApiException] for the view to surface.
  Future<PlayerResponse> updatePlayer({
    required String publicId,
    required String name,
    required double skillLevel,
  }) async {
    final response = await _api.updatePlayer(
      publicId,
      UpdatePlayerRequest(name: name, skillLevel: skillLevel),
    );
    _flash('${response.name} — updated');
    await loadQueue();
    return response;
  }

  /// `POST /api/players` then `POST /api/queue/check-in` — registers a new
  /// player and immediately checks them in. The returned [PlayerResponse]
  /// carries their permanent `qrCode` for display.
  ///
  /// Re-throws [ApiException] on failure (caller should keep the form open
  /// and surface the error).
  Future<PlayerResponse> registerAndCheckIn({
    required String name,
    required double skillLevel,
  }) async {
    final player = await _api.registerPlayer(
      CreatePlayerRequest(name: name, skillLevel: skillLevel),
    );
    await _api.checkIn(CheckInRequest(qrCode: player.qrCode));
    _upsertPlayer(Player(
      id: player.id,
      name: player.name,
      skill: _formatSkill(player.skillLevel),
      status: PlayerStatus.waiting,
    ));
    _flash('${player.name} — added & checked in');
    return player;
  }

  void _upsertPlayer(Player p) {
    final existingIdx = state.players.indexWhere((x) => x.id == p.id);
    final next = [...state.players];
    if (existingIdx >= 0) {
      next[existingIdx] = p;
    } else {
      next.add(p);
    }
    emit(state.copyWith(players: next));
  }

  /// Backend status string → local enum. Anything we don't recognize falls
  /// back to `waiting` so the player still appears in the UI.
  PlayerStatus _statusFromResponse(QueueEntryStatus status) => switch (status) {
        QueueEntryStatus.playing => PlayerStatus.active,
        QueueEntryStatus.resting => PlayerStatus.resting,
        QueueEntryStatus.waiting => PlayerStatus.waiting,
        QueueEntryStatus.finished => PlayerStatus.waiting,
        QueueEntryStatus.noShow => PlayerStatus.waiting,
        QueueEntryStatus.unknown => PlayerStatus.waiting,
      };

  /// 3.0 → "3.0", 3.5 → "3.5".
  String _formatSkill(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(1) : v.toString();

  void _flash(String message) {
    emit(state.copyWith(flash: message));
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (isClosed) return;
      emit(state.copyWith(clearFlash: true));
    });
  }

  @override
  Future<void> close() {
    _flashTimer?.cancel();
    return super.close();
  }
}
