part of 'player_profile_cubit.dart';

/// Possible top-level states for the Player Profile view.
///
/// `unavailable` is the gated state — the player exists but either
/// (a) no session is currently active, or (b) a session is active but
/// the player hasn't been checked in to it yet. The specific cause is
/// carried on [PlayerProfileState.unavailableReason] so the view can
/// pick the right copy. We still hold [PlayerProfileState.player] in
/// this state so the gated view can greet the viewer by name.
enum PlayerProfileStatus { initial, loading, success, failure, unavailable }

/// Why the profile is currently in the `unavailable` state. Drives the
/// secondary copy on the gated view.
enum UnavailableReason {
  /// No session has ever been hosted, or the latest one has ended.
  noActiveSession,

  /// A session is active but the player has not been scanned / manually
  /// checked in to it. The host needs to check them in.
  notCheckedIn,
}

final class PlayerProfileState extends Equatable {
  const PlayerProfileState({
    required this.status,
    this.player,
    this.activeSession,
    this.latestSession,
    this.queue = const [],
    this.leaderboard = const [],
    this.history = const [],
    this.activeMatches = const [],
    this.unavailableReason,
    this.error,
  });

  const PlayerProfileState.initial()
      : this(status: PlayerProfileStatus.initial);

  final PlayerProfileStatus status;
  final PlayerResponse? player;
  final SessionResponse? activeSession;

  /// Most-recent session known to the backend (active or closed),
  /// regardless of whether it's currently visible. Used by the gated
  /// "unavailable" view to tell the viewer when play last happened.
  final SessionResponse? latestSession;
  final List<QueueEntryResponse> queue;
  final List<LeaderboardEntryResponse> leaderboard;
  final List<MatchResponse> history;
  final List<MatchResponse> activeMatches;

  /// Populated whenever [status] is [PlayerProfileStatus.unavailable].
  /// Tells the view *why* — so we can show "ask the host to check you in"
  /// vs. "no session is active right now".
  final UnavailableReason? unavailableReason;
  final String? error;

  PlayerProfileState copyWith({
    PlayerProfileStatus? status,
    PlayerResponse? player,
    SessionResponse? activeSession,
    bool clearActiveSession = false,
    SessionResponse? latestSession,
    bool clearLatestSession = false,
    List<QueueEntryResponse>? queue,
    List<LeaderboardEntryResponse>? leaderboard,
    List<MatchResponse>? history,
    List<MatchResponse>? activeMatches,
    UnavailableReason? unavailableReason,
    bool clearUnavailableReason = false,
    String? error,
    bool clearError = false,
  }) =>
      PlayerProfileState(
        status: status ?? this.status,
        player: player ?? this.player,
        activeSession:
            clearActiveSession ? null : (activeSession ?? this.activeSession),
        latestSession:
            clearLatestSession ? null : (latestSession ?? this.latestSession),
        queue: queue ?? this.queue,
        leaderboard: leaderboard ?? this.leaderboard,
        history: history ?? this.history,
        activeMatches: activeMatches ?? this.activeMatches,
        unavailableReason: clearUnavailableReason
            ? null
            : (unavailableReason ?? this.unavailableReason),
        error: clearError ? null : (error ?? this.error),
      );

  // ─── Derived helpers ───────────────────────────────────────────────────

  /// This player's row on the active-session leaderboard, or null if they
  /// haven't played any completed match yet.
  LeaderboardEntryResponse? get myLeaderboardEntry {
    final id = player?.id;
    if (id == null) return null;
    for (final e in leaderboard) {
      if (e.playerId == id) return e;
    }
    return null;
  }

  /// This player's current queue entry, or null if they aren't in the
  /// active session (or there is no active session).
  QueueEntryResponse? get myQueueEntry {
    final id = player?.id;
    if (id == null) return null;
    for (final e in queue) {
      if (e.playerId == id) return e;
    }
    return null;
  }

  /// Completed matches in the active session that this player participated
  /// in, server-ordered newest-first.
  List<MatchResponse> get myHistory {
    final id = player?.id;
    if (id == null) return const [];
    return history
        .where((m) => m.players.any((p) => p.playerId == id))
        .toList(growable: false);
  }

  /// Current win streak — counts consecutive wins from the most recent
  /// completed match backwards, stopping at the first loss / unknown.
  int get currentStreak {
    final id = player?.id;
    if (id == null) return 0;
    var streak = 0;
    for (final m in myHistory) {
      final winning = m.winningTeam;
      if (winning == null) continue;
      MatchPlayerInfo? mine;
      for (final p in m.players) {
        if (p.playerId == id) {
          mine = p;
          break;
        }
      }
      if (mine == null) break;
      if (mine.team == winning) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// True when this player is currently in an in-progress match — useful
  /// for highlighting their row on the Courts tab.
  bool isInMatch(MatchResponse match) {
    final id = player?.id;
    if (id == null) return false;
    return match.players.any((p) => p.playerId == id);
  }

  @override
  List<Object?> get props => [
        status,
        player,
        activeSession,
        latestSession,
        queue,
        leaderboard,
        history,
        activeMatches,
        unavailableReason,
        error,
      ];
}
