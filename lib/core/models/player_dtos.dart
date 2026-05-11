import 'package:equatable/equatable.dart';
import 'package:paddleq/core/models/_json.dart';

/// Mirrors `PlayerResponse` in api-spec.json.
class PlayerResponse extends Equatable {
  const PlayerResponse({
    required this.id,
    required this.name,
    required this.skillLevel,
    required this.qrCode,
    required this.wins,
    required this.losses,
    required this.createdAt,
  });

  /// Public GUID — the only player identifier the frontend uses.
  final String id;
  final String name;
  final double skillLevel;
  final String qrCode;
  final int wins;
  final int losses;
  final DateTime createdAt;

  factory PlayerResponse.fromJson(Map<String, dynamic> json) => PlayerResponse(
        id: json['id'] as String,
        name: (json['name'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        qrCode: (json['qrCode'] ?? '') as String,
        wins: json['wins'] as int,
        losses: json['losses'] as int,
        createdAt: parseUtc(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'skillLevel': skillLevel,
        'qrCode': qrCode,
        'wins': wins,
        'losses': losses,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, skillLevel, qrCode, wins, losses, createdAt];
}

/// Mirrors `CreatePlayerRequest` in api-spec.json.
class CreatePlayerRequest extends Equatable {
  const CreatePlayerRequest({required this.name, required this.skillLevel});

  /// 1–100 chars per backend validation.
  final String name;

  /// One of {2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0}.
  final double skillLevel;

  Map<String, dynamic> toJson() => {
        'name': name,
        'skillLevel': skillLevel,
      };

  @override
  List<Object?> get props => [name, skillLevel];
}

/// Mirrors `PlayerSearchResult` — one hit from `GET /api/players/search`.
///
/// Returns up to 20 case-insensitive name matches. When there's an active
/// session, [currentQueueStatus] reflects the player's current state in
/// that session (`Waiting` / `Playing` / `Resting` / `Finished` / `NoShow`),
/// or null when the player isn't in the queue / there's no active session.
class PlayerSearchResult extends Equatable {
  const PlayerSearchResult({
    required this.playerId,
    required this.name,
    required this.skillLevel,
    required this.currentQueueStatus,
  });

  /// Public GUID — what the check-in-by-id endpoint expects.
  final String playerId;
  final String name;
  final double skillLevel;
  final String? currentQueueStatus;

  factory PlayerSearchResult.fromJson(Map<String, dynamic> json) =>
      PlayerSearchResult(
        playerId: json['playerId'] as String,
        name: (json['name'] ?? '') as String,
        skillLevel: parseDouble(json['skillLevel']),
        currentQueueStatus: json['currentQueueStatus'] as String?,
      );

  @override
  List<Object?> get props => [playerId, name, skillLevel, currentQueueStatus];
}

/// Body for `PUT /api/players/{publicId}` — full replacement. Both fields
/// are required: send the player's intended `name` and `skillLevel` every
/// time, even if only one of them is changing. (Partial updates with
/// either field omitted made the backend default the missing value to 0
/// and then reject it via the skill-range validator.)
class UpdatePlayerRequest extends Equatable {
  const UpdatePlayerRequest({required this.name, required this.skillLevel});

  /// 1–100 chars per backend validation.
  final String name;

  /// One of {2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0}.
  final double skillLevel;

  Map<String, dynamic> toJson() => {
        'name': name,
        'skillLevel': skillLevel,
      };

  @override
  List<Object?> get props => [name, skillLevel];
}
