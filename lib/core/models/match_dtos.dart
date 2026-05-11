import 'package:equatable/equatable.dart';
import 'package:paddleq/core/models/_json.dart';

/// Match status values used by the backend FSM.
enum MatchStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  unknown;

  static MatchStatus parse(String? raw) => switch (raw) {
        'Pending' => MatchStatus.pending,
        'InProgress' => MatchStatus.inProgress,
        'Completed' => MatchStatus.completed,
        'Cancelled' => MatchStatus.cancelled,
        _ => MatchStatus.unknown,
      };
}

/// Mirrors `MatchPlayerInfo`.
class MatchPlayerInfo extends Equatable {
  const MatchPlayerInfo({
    required this.playerId,
    required this.playerName,
    required this.skillLevel,
    required this.team,
  });

  final String playerId;
  final String playerName;
  final double skillLevel;

  /// 1 or 2.
  final int team;

  factory MatchPlayerInfo.fromJson(Map<String, dynamic> json) =>
      MatchPlayerInfo(
        playerId: json['playerId'] as String,
        playerName: (json['playerName'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        team: json['team'] as int,
      );

  @override
  List<Object?> get props => [playerId, playerName, skillLevel, team];
}

/// Mirrors `MatchResponse`.
class MatchResponse extends Equatable {
  const MatchResponse({
    required this.id,
    required this.matchType,
    required this.status,
    required this.courtNumber,
    required this.winningTeam,
    required this.startedAt,
    required this.completedAt,
    required this.players,
  });

  final int id;

  /// "Singles" or "Doubles".
  final String matchType;
  final MatchStatus status;

  /// Assigned when the match goes InProgress; null otherwise.
  final int? courtNumber;

  /// 1, 2, or null until completed.
  final int? winningTeam;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<MatchPlayerInfo> players;

  factory MatchResponse.fromJson(Map<String, dynamic> json) => MatchResponse(
        id: json['id'] as int,
        matchType: (json['matchType'] ?? '') as String,
        status: MatchStatus.parse(json['status'] as String?),
        courtNumber: json['courtNumber'] as int?,
        winningTeam: json['winningTeam'] as int?,
        startedAt: parseUtcOrNull(json['startedAt']),
        completedAt: parseUtcOrNull(json['completedAt']),
        players: ((json['players'] as List?) ?? const [])
            .map((e) => MatchPlayerInfo.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  /// Convenience: only the players on the given team (1 or 2).
  Iterable<MatchPlayerInfo> playersOnTeam(int team) =>
      players.where((p) => p.team == team);

  @override
  List<Object?> get props => [
        id,
        matchType,
        status,
        courtNumber,
        winningTeam,
        startedAt,
        completedAt,
        players,
      ];
}

/// Mirrors `FormMatchResponse`.
class FormMatchResponse extends Equatable {
  const FormMatchResponse({
    required this.match,
    required this.usedSkillMix,
    required this.message,
  });

  final MatchResponse match;

  /// True when the matchmaker fell back to ±0.5 skill range. UI should
  /// surface this so the host knows the match isn't strict-matched.
  final bool usedSkillMix;

  /// Optional explanation, populated when [usedSkillMix] is true.
  final String? message;

  factory FormMatchResponse.fromJson(Map<String, dynamic> json) =>
      FormMatchResponse(
        match: MatchResponse.fromJson(json['match'] as Map<String, dynamic>),
        usedSkillMix: (json['usedSkillMix'] ?? false) as bool,
        message: json['message'] as String?,
      );

  @override
  List<Object?> get props => [match, usedSkillMix, message];
}

/// Mirrors `CompleteMatchRequest`.
class CompleteMatchRequest extends Equatable {
  const CompleteMatchRequest({required this.winningTeam});

  /// 1 or 2.
  final int winningTeam;

  Map<String, dynamic> toJson() => {'winningTeam': winningTeam};

  @override
  List<Object?> get props => [winningTeam];
}

/// Body for `POST /api/matches/{id}/void` — cancels a match because one
/// player became unavailable.
///
/// On the backend the unavailable player is moved to Resting, the rest
/// return to Waiting, no W/L/games counters are incremented, and the
/// court frees up.
class VoidMatchRequest extends Equatable {
  const VoidMatchRequest({required this.unavailablePlayerId, this.reason});

  /// Public GUID of the player who can't continue.
  final String unavailablePlayerId;

  /// Optional explanation, max 500 chars.
  final String? reason;

  Map<String, dynamic> toJson() => {
        'unavailablePlayerId': unavailablePlayerId,
        if (reason != null) 'reason': reason,
      };

  @override
  List<Object?> get props => [unavailablePlayerId, reason];
}

/// Mirrors `LeaderboardEntryResponse` — one row in the active-session
/// leaderboard, pre-ranked by the backend (wins desc → winRate desc →
/// gamesPlayed desc). Only includes players with at least one completed
/// match in the current session.
class LeaderboardEntryResponse extends Equatable {
  const LeaderboardEntryResponse({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.skillLevel,
    required this.wins,
    required this.losses,
    required this.gamesPlayed,
    required this.winRate,
  });

  /// 1-indexed; ties broken by the backend's secondary sort.
  final int rank;
  final String playerId;
  final String playerName;
  final double skillLevel;
  final int wins;
  final int losses;
  final int gamesPlayed;

  /// 0.0 to 1.0 — multiply by 100 for a percentage.
  final double winRate;

  factory LeaderboardEntryResponse.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntryResponse(
        rank: json['rank'] as int,
        playerId: json['playerId'] as String,
        playerName: (json['playerName'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        wins: json['wins'] as int,
        losses: json['losses'] as int,
        gamesPlayed: json['gamesPlayed'] as int,
        winRate: parseDouble(json['winRate']),
      );

  @override
  List<Object?> get props => [
        rank,
        playerId,
        playerName,
        skillLevel,
        wins,
        losses,
        gamesPlayed,
        winRate,
      ];
}
