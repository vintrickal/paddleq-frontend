import 'package:equatable/equatable.dart';
import 'package:paddleq/core/models/_json.dart';
import 'package:paddleq/core/models/session_dtos.dart';

/// QueueEntry status as returned by the API. Frozen string set so the UI
/// can pattern-match exhaustively.
enum QueueEntryStatus {
  waiting,
  playing,
  resting,
  finished,
  noShow,
  unknown;

  static QueueEntryStatus parse(String? raw) => switch (raw) {
        'Waiting' => QueueEntryStatus.waiting,
        'Playing' => QueueEntryStatus.playing,
        'Resting' => QueueEntryStatus.resting,
        'Finished' => QueueEntryStatus.finished,
        'NoShow' => QueueEntryStatus.noShow,
        _ => QueueEntryStatus.unknown,
      };
}

/// Mirrors `QueueEntryResponse` in api-spec.json.
class QueueEntryResponse extends Equatable {
  const QueueEntryResponse({
    required this.queueEntryId,
    required this.playerId,
    required this.playerName,
    required this.skillLevel,
    required this.status,
    required this.gamesPlayed,
    required this.createdAt,
    required this.checkedInAt,
    required this.lastPlayedAt,
  });

  final int queueEntryId;

  /// Public player GUID.
  final String playerId;
  final String playerName;
  final double skillLevel;
  final QueueEntryStatus status;

  /// Raw status string as sent by the server — preserved for round-tripping
  /// and for unknown statuses that don't map to the enum.
  final int gamesPlayed;
  final DateTime createdAt;
  final DateTime? checkedInAt;
  final DateTime? lastPlayedAt;

  factory QueueEntryResponse.fromJson(Map<String, dynamic> json) =>
      QueueEntryResponse(
        queueEntryId: json['queueEntryId'] as int,
        playerId: json['playerId'] as String,
        playerName: (json['playerName'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        status: QueueEntryStatus.parse(json['status'] as String?),
        gamesPlayed: json['gamesPlayed'] as int,
        createdAt: parseUtc(json['createdAt']),
        checkedInAt: parseUtcOrNull(json['checkedInAt']),
        lastPlayedAt: parseUtcOrNull(json['lastPlayedAt']),
      );

  @override
  List<Object?> get props => [
        queueEntryId,
        playerId,
        playerName,
        skillLevel,
        status,
        gamesPlayed,
        createdAt,
        checkedInAt,
        lastPlayedAt,
      ];
}

/// Mirrors `QueueSummary` in api-spec.json.
class QueueSummary extends Equatable {
  const QueueSummary({
    required this.waiting,
    required this.playing,
    required this.resting,
    required this.finished,
    required this.noShow,
    required this.total,
  });

  final int waiting;
  final int playing;
  final int resting;
  final int finished;
  final int noShow;
  final int total;

  static const empty = QueueSummary(
    waiting: 0,
    playing: 0,
    resting: 0,
    finished: 0,
    noShow: 0,
    total: 0,
  );

  factory QueueSummary.fromJson(Map<String, dynamic> json) => QueueSummary(
        waiting: (json['waiting'] ?? 0) as int,
        playing: (json['playing'] ?? 0) as int,
        resting: (json['resting'] ?? 0) as int,
        finished: (json['finished'] ?? 0) as int,
        noShow: (json['noShow'] ?? 0) as int,
        total: (json['total'] ?? 0) as int,
      );

  @override
  List<Object?> get props => [waiting, playing, resting, finished, noShow, total];
}

/// Mirrors `QueueResponse` — full snapshot for the host dashboard.
class QueueResponse extends Equatable {
  const QueueResponse({
    required this.activeSession,
    required this.entries,
    required this.summary,
  });

  /// `null` when no session is active. Per spec, the endpoint never errors
  /// for a missing session — it just returns an empty payload.
  final SessionResponse? activeSession;
  final List<QueueEntryResponse> entries;
  final QueueSummary summary;

  factory QueueResponse.fromJson(Map<String, dynamic> json) => QueueResponse(
        activeSession: json['activeSession'] == null
            ? null
            : SessionResponse.fromJson(
                json['activeSession'] as Map<String, dynamic>),
        entries: ((json['entries'] as List?) ?? const [])
            .map((e) => QueueEntryResponse.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        summary: json['summary'] == null
            ? QueueSummary.empty
            : QueueSummary.fromJson(json['summary'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [activeSession, entries, summary];
}

/// Mirrors `CheckInRequest` — used for both check-in and leave.
class CheckInRequest extends Equatable {
  const CheckInRequest({required this.qrCode});

  /// Up to 255 chars.
  final String qrCode;

  Map<String, dynamic> toJson() => {'qrCode': qrCode};

  @override
  List<Object?> get props => [qrCode];
}

/// Body for `POST /api/queue/check-in-by-id` — manual check-in flow when
/// the player has lost their QR code and is identified by their public id
/// (e.g. via the name search).
class CheckInByIdRequest extends Equatable {
  const CheckInByIdRequest({required this.playerId});

  /// Public GUID returned by `PlayerSearchResult.playerId`.
  final String playerId;

  Map<String, dynamic> toJson() => {'playerId': playerId};

  @override
  List<Object?> get props => [playerId];
}

/// Mirrors `CheckInResponse`.
class CheckInResponse extends Equatable {
  const CheckInResponse({
    required this.queueEntryId,
    required this.playerId,
    required this.playerName,
    required this.skillLevel,
    required this.status,
    required this.checkedInAt,
  });

  final int queueEntryId;
  final String playerId;
  final String playerName;
  final double skillLevel;
  final QueueEntryStatus status;
  final DateTime checkedInAt;

  factory CheckInResponse.fromJson(Map<String, dynamic> json) =>
      CheckInResponse(
        queueEntryId: json['queueEntryId'] as int,
        playerId: json['playerId'] as String,
        playerName: (json['playerName'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        status: QueueEntryStatus.parse(json['status'] as String?),
        checkedInAt: parseUtc(json['checkedInAt']),
      );

  @override
  List<Object?> get props =>
      [queueEntryId, playerId, playerName, skillLevel, status, checkedInAt];
}

/// Mirrors `LeaveQueueResponse`.
class LeaveQueueResponse extends Equatable {
  const LeaveQueueResponse({
    required this.queueEntryId,
    required this.playerId,
    required this.playerName,
    required this.status,
    required this.leftAt,
  });

  final int queueEntryId;
  final String playerId;
  final String playerName;
  final QueueEntryStatus status;
  final DateTime leftAt;

  factory LeaveQueueResponse.fromJson(Map<String, dynamic> json) =>
      LeaveQueueResponse(
        queueEntryId: json['queueEntryId'] as int,
        playerId: json['playerId'] as String,
        playerName: (json['playerName'] ?? '') as String,
        status: QueueEntryStatus.parse(json['status'] as String?),
        leftAt: parseUtc(json['leftAt']),
      );

  @override
  List<Object?> get props =>
      [queueEntryId, playerId, playerName, status, leftAt];
}
