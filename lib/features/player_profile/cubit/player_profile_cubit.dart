import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/api_exception.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:paddleq/core/models/player_dtos.dart';
import 'package:paddleq/core/models/queue_dtos.dart';
import 'package:paddleq/core/models/session_dtos.dart';

part 'player_profile_state.dart';

/// Cubit for the public, deep-linked Player Profile page.
///
/// Hydrates with one call per slice:
///   * `GET /api/players/{publicId}` — required; identifies whose profile.
///   * `GET /api/sessions` — to determine the visibility gate (see below).
///   * `GET /api/queue` — to discover the active session and the player's
///     current queue status.
///   * `GET /api/matches/leaderboard` — to find the player's rank.
///   * `GET /api/matches/history` — to compute the player's win/loss list.
///   * `GET /api/matches/active` — to render the read-only courts panel.
///
/// ### Visibility gate
///
/// The profile is only viewable while the player is participating in a
/// live session. Two conditions must both hold; either failing → the
/// state is [PlayerProfileStatus.unavailable].
///   * The most-recent session is `Active` (not closed, not absent).
///   * The player has a queue entry in that session (any status —
///     Waiting / Playing / Resting all count as "checked in"; missing
///     entirely means they haven't been scanned in yet).
///
/// There is intentionally no grace window — once the host ends the
/// session, or the player hasn't yet been checked in, the profile flips
/// to unavailable on the next poll tick.
///
/// ### Polling
///
/// After the initial load the cubit polls every [pollInterval] in *all*
/// post-load states (`success`, `unavailable`) — so check-in or a
/// freshly started session lights the page up without the viewer having
/// to refresh, and a session ending mid-view closes the page on the next
/// tick. Overlapping ticks are dropped.
class PlayerProfileCubit extends Cubit<PlayerProfileState> {
  PlayerProfileCubit({
    required PaddleqApi api,
    required this.publicId,
    this.pollInterval = const Duration(seconds: 5),
  })  : _api = api,
        super(const PlayerProfileState.initial());

  final PaddleqApi _api;
  final String publicId;

  /// How often to re-fetch the session-scoped slices and re-evaluate the
  /// gate once the initial load has finished. Five seconds is fast enough
  /// that a new match showing up on the host feels near-instant on the
  /// viewer's profile, slow enough that we're not hammering the API.
  final Duration pollInterval;

  Timer? _pollTimer;
  bool _refreshing = false;

  Future<void> load() async {
    _stopPolling();
    emit(state.copyWith(
      status: PlayerProfileStatus.loading,
      clearError: true,
    ));
    try {
      final player = await _api.getPlayer(publicId);
      final latest = await _fetchLatestSession();

      if (isClosed) return;

      // Gate condition 1: must have an active session.
      if (latest == null || !latest.isActive) {
        emit(_unavailable(
          player: player,
          latest: latest,
          reason: UnavailableReason.noActiveSession,
        ));
        _startPolling();
        return;
      }

      // Need the queue to evaluate gate condition 2 (player is checked in),
      // and the other slices to render the loaded view if they are. Fetch
      // them all up front rather than serially.
      final slices = await _fetchSessionSlices();
      if (isClosed) return;

      final checkedIn = _isCheckedIn(slices.queue.entries, player.id);
      if (!checkedIn) {
        emit(_unavailable(
          player: player,
          latest: latest,
          reason: UnavailableReason.notCheckedIn,
        ));
        _startPolling();
        return;
      }

      emit(state.copyWith(
        status: PlayerProfileStatus.success,
        player: player,
        latestSession: latest,
        activeSession: slices.queue.activeSession,
        clearActiveSession: slices.queue.activeSession == null,
        queue: slices.queue.entries,
        leaderboard: slices.leaderboard,
        history: slices.history,
        activeMatches: slices.activeMatches,
        clearUnavailableReason: true,
      ));
      _startPolling();
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: PlayerProfileStatus.failure,
        error: e.message,
      ));
    }
  }

  /// Background refresh — re-evaluates the visibility gate and, if
  /// accessible, re-emits the four session-scoped slices. Never changes
  /// status to `loading` (the welcome animation only plays once on initial
  /// load); transitions between `success` and `unavailable` are silent.
  ///
  /// Drops the call entirely if another refresh is already in flight, so a
  /// slow network never causes overlapping requests to pile up.
  Future<void> refresh() async {
    if (_refreshing) return;
    // Only poll once we know who the player is. Re-trying after a hard
    // failure has to go through `load()` (the user taps the retry button).
    if (state.status != PlayerProfileStatus.success &&
        state.status != PlayerProfileStatus.unavailable) {
      return;
    }
    final player = state.player;
    if (player == null) return;

    _refreshing = true;
    try {
      final latest = await _fetchLatestSession();
      if (isClosed) return;

      if (latest == null || !latest.isActive) {
        emit(_unavailable(
          player: player,
          latest: latest,
          reason: UnavailableReason.noActiveSession,
        ));
        return;
      }

      final slices = await _fetchSessionSlices();
      if (isClosed) return;

      final checkedIn = _isCheckedIn(slices.queue.entries, player.id);
      if (!checkedIn) {
        emit(_unavailable(
          player: player,
          latest: latest,
          reason: UnavailableReason.notCheckedIn,
        ));
        return;
      }

      emit(state.copyWith(
        status: PlayerProfileStatus.success,
        latestSession: latest,
        activeSession: slices.queue.activeSession,
        clearActiveSession: slices.queue.activeSession == null,
        queue: slices.queue.entries,
        leaderboard: slices.leaderboard,
        history: slices.history,
        activeMatches: slices.activeMatches,
        clearUnavailableReason: true,
      ));
    } finally {
      _refreshing = false;
    }
  }

  /// Whether the player has a queue entry for the active session — any
  /// status (Waiting / Playing / Resting) counts. Missing entirely means
  /// the host hasn't scanned them in for tonight's session yet.
  ///
  /// [playerId] is the public-id GUID (the same `playerId` field on
  /// [QueueEntryResponse]), not the internal row id.
  bool _isCheckedIn(List<QueueEntryResponse> entries, String playerId) {
    for (final e in entries) {
      if (e.playerId == playerId) return true;
    }
    return false;
  }

  /// Builds the `unavailable` state in one place — both load() and
  /// refresh() emit it from two different branches, and this keeps the
  /// "clear everything session-scoped" boilerplate from drifting.
  PlayerProfileState _unavailable({
    required PlayerResponse player,
    required SessionResponse? latest,
    required UnavailableReason reason,
  }) {
    return state.copyWith(
      status: PlayerProfileStatus.unavailable,
      player: player,
      latestSession: latest,
      clearLatestSession: latest == null,
      // Clear any stale session-scoped data from a previous load — the
      // unavailable view shouldn't expose results from a session the
      // player is no longer in.
      clearActiveSession: true,
      queue: const [],
      leaderboard: const [],
      history: const [],
      activeMatches: const [],
      unavailableReason: reason,
    );
  }

  /// Most-recent session known to the backend (active or closed). Errors
  /// (network down, server error) resolve to null — same as "no sessions"
  /// — so the gate fails closed and the viewer sees the unavailable view
  /// instead of a half-broken profile.
  Future<SessionResponse?> _fetchLatestSession() async {
    try {
      final sessions = await _api.listSessions();
      if (sessions.isEmpty) return null;
      return sessions.first;
    } on ApiException {
      return null;
    }
  }

  Future<_SessionSlices> _fetchSessionSlices() async {
    const emptyQueue = QueueResponse(
      activeSession: null,
      entries: [],
      summary: QueueSummary.empty,
    );

    final results = await Future.wait<Object>([
      _api
          .getQueue()
          .then<Object>((v) => v)
          .catchError((Object _) => emptyQueue),
      _api
          .getLeaderboard()
          .then<Object>((v) => v)
          .catchError((Object _) => <LeaderboardEntryResponse>[]),
      _api
          .getMatchHistory()
          .then<Object>((v) => v)
          .catchError((Object _) => <MatchResponse>[]),
      _api
          .getActiveMatches()
          .then<Object>((v) => v)
          .catchError((Object _) => <MatchResponse>[]),
    ]);

    return _SessionSlices(
      queue: results[0] as QueueResponse,
      leaderboard: results[1] as List<LeaderboardEntryResponse>,
      history: results[2] as List<MatchResponse>,
      activeMatches: results[3] as List<MatchResponse>,
    );
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(pollInterval, (_) => refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}

/// Bundle of the four session-scoped slices, returned by
/// [PlayerProfileCubit._fetchSessionSlices] so the initial load and the
/// background refresh can share the same fetch logic.
class _SessionSlices {
  const _SessionSlices({
    required this.queue,
    required this.leaderboard,
    required this.history,
    required this.activeMatches,
  });

  final QueueResponse queue;
  final List<LeaderboardEntryResponse> leaderboard;
  final List<MatchResponse> history;
  final List<MatchResponse> activeMatches;
}
