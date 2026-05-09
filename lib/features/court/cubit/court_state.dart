part of 'court_cubit.dart';

// `MatchResponse` lives in core/models — referenced via the public part-of
// import in court_cubit.dart.

enum PlayerStatus { active, waiting, resting }

extension PlayerStatusX on PlayerStatus {
  String get label => switch (this) {
        PlayerStatus.active => 'Active match',
        PlayerStatus.waiting => 'Waiting',
        PlayerStatus.resting => 'Resting',
      };
}

enum CourtTab { courts, players }

enum PlayerFilter { all, active, waiting, resting }

extension PlayerFilterX on PlayerFilter {
  String get label => switch (this) {
        PlayerFilter.all => 'ALL',
        PlayerFilter.active => 'ACTIVE',
        PlayerFilter.waiting => 'WAITING',
        PlayerFilter.resting => 'RESTING',
      };
}

final class Player extends Equatable {
  const Player({
    required this.id,
    required this.name,
    required this.skill,
    required this.status,
    this.court,
    this.gamesPlayed = 0,
  });

  final String id;
  final String name;
  final String skill;
  final PlayerStatus status;
  final int? court;

  /// Per-session match count, mirrored from `QueueEntryResponse.gamesPlayed`
  /// on every queue refresh. Zero for fresh check-ins until a server
  /// snapshot replaces it.
  final int gamesPlayed;

  Player copyWith({
    String? name,
    String? skill,
    PlayerStatus? status,
    int? court,
    bool clearCourt = false,
    int? gamesPlayed,
  }) =>
      Player(
        id: id,
        name: name ?? this.name,
        skill: skill ?? this.skill,
        status: status ?? this.status,
        court: clearCourt ? null : (court ?? this.court),
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      );

  @override
  List<Object?> get props => [id, name, skill, status, court, gamesPlayed];
}

final class CourtState extends Equatable {
  const CourtState({
    required this.mode,
    required this.courtCount,
    required this.currentCourt,
    required this.tab,
    required this.filter,
    required this.players,
    this.activeMatches = const [],
    this.matchHistory = const [],
    this.leaderboard = const [],
    this.flash,
    this.sessionName = '',
    this.sessionId,
    this.queueStatus = QueueLoadStatus.idle,
    this.queueError,
    this.courtNames = const {},
  });

  final GameMode mode;
  final int courtCount;
  final int currentCourt;
  final CourtTab tab;
  final PlayerFilter filter;
  final List<Player> players;

  /// In-progress matches in this session, keyed by court via [matchOnCourt].
  /// Populated by `GET /api/matches/active` whenever [CourtCubit.loadQueue]
  /// runs, so the UI can wire winner buttons to a real match id.
  final List<MatchResponse> activeMatches;

  /// Completed matches for the active session, newest-first. From
  /// `GET /api/matches/history`.
  final List<MatchResponse> matchHistory;

  /// Leaderboard for the active session, pre-ranked by the backend.
  /// From `GET /api/matches/leaderboard`.
  final List<LeaderboardEntryResponse> leaderboard;

  /// User-supplied label for this play session, shown above the live-courts
  /// header. May be empty (the header just collapses).
  final String sessionName;

  /// Backend session id this Court page is bound to. Null until the session
  /// has been created (currently only set by the Setup-court flow).
  final int? sessionId;

  /// Tracks the most recent `GET /api/queue` call so the UI can show first-
  /// load spinners, refresh indicators, and retry buttons.
  final QueueLoadStatus queueStatus;

  /// Last queue-load failure message — surfaced as a banner with a retry CTA.
  /// Null in any non-failure state.
  final String? queueError;

  /// Per-session custom court names, keyed by court index. Populated only
  /// when the host renames a court via the edit pencil; entries are
  /// in-memory only — they reset when the cubit is recreated (e.g. browser
  /// refresh or returning to Home then Setup).
  final Map<int, String> courtNames;

  /// Display label for [idx] — the host's custom name when set, otherwise
  /// the default `Court N`.
  String courtLabel(int idx) =>
      (courtNames[idx]?.trim().isNotEmpty ?? false)
          ? courtNames[idx]!.trim()
          : 'Court $idx';

  /// Transient toast text shown briefly above the court list. Cleared
  /// after ~1.4s by the cubit.
  final String? flash;

  CourtState copyWith({
    GameMode? mode,
    int? courtCount,
    int? currentCourt,
    CourtTab? tab,
    PlayerFilter? filter,
    List<Player>? players,
    List<MatchResponse>? activeMatches,
    List<MatchResponse>? matchHistory,
    List<LeaderboardEntryResponse>? leaderboard,
    String? flash,
    bool clearFlash = false,
    String? sessionName,
    int? sessionId,
    QueueLoadStatus? queueStatus,
    String? queueError,
    bool clearQueueError = false,
    Map<int, String>? courtNames,
  }) =>
      CourtState(
        mode: mode ?? this.mode,
        courtCount: courtCount ?? this.courtCount,
        currentCourt: currentCourt ?? this.currentCourt,
        tab: tab ?? this.tab,
        filter: filter ?? this.filter,
        players: players ?? this.players,
        activeMatches: activeMatches ?? this.activeMatches,
        matchHistory: matchHistory ?? this.matchHistory,
        leaderboard: leaderboard ?? this.leaderboard,
        flash: clearFlash ? null : (flash ?? this.flash),
        sessionName: sessionName ?? this.sessionName,
        sessionId: sessionId ?? this.sessionId,
        queueStatus: queueStatus ?? this.queueStatus,
        queueError:
            clearQueueError ? null : (queueError ?? this.queueError),
        courtNames: courtNames ?? this.courtNames,
      );

  List<Player> playersOnCourt(int idx) =>
      players.where((p) => p.court == idx).toList(growable: false);

  /// Returns the in-progress match assigned to [idx], or null if the court
  /// is empty.
  MatchResponse? matchOnCourt(int idx) {
    for (final m in activeMatches) {
      if (m.courtNumber == idx) return m;
    }
    return null;
  }

  int get activeCount => players.where((p) => p.status == PlayerStatus.active).length;
  int get waitingCount => players.where((p) => p.status == PlayerStatus.waiting).length;
  int get restingCount => players.where((p) => p.status == PlayerStatus.resting).length;

  bool get isFirstLoad =>
      queueStatus == QueueLoadStatus.loading && players.isEmpty;
  bool get isRefreshing =>
      queueStatus == QueueLoadStatus.loading && players.isNotEmpty;

  @override
  List<Object?> get props => [
        mode,
        courtCount,
        currentCourt,
        tab,
        filter,
        players,
        activeMatches,
        matchHistory,
        leaderboard,
        flash,
        sessionName,
        sessionId,
        queueStatus,
        queueError,
        courtNames,
      ];
}

/// Lifecycle of the most recent queue-fetch attempt.
enum QueueLoadStatus { idle, loading, success, failure }
