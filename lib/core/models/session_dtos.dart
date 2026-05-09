import 'package:equatable/equatable.dart';
import 'package:paddleq/core/models/_json.dart';

/// Mirrors `SessionResponse` in api-spec.json.
class SessionResponse extends Equatable {
  const SessionResponse({
    required this.id,
    required this.name,
    required this.matchType,
    required this.numberOfCourts,
    required this.status,
    required this.startedAt,
    required this.endedAt,
  });

  final int id;

  /// Free-form host-supplied label, e.g. "Tuesday Open Play". May be empty.
  final String name;

  /// "Singles" or "Doubles".
  final String matchType;
  final int numberOfCourts;

  /// "Active" or "Closed".
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;

  factory SessionResponse.fromJson(Map<String, dynamic> json) =>
      SessionResponse(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        matchType: (json['matchType'] ?? '') as String,
        numberOfCourts: json['numberOfCourts'] as int,
        status: (json['status'] ?? '') as String,
        startedAt: parseUtc(json['startedAt']),
        endedAt: parseUtcOrNull(json['endedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'matchType': matchType,
        'numberOfCourts': numberOfCourts,
        'status': status,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
      };

  bool get isActive => status == 'Active';

  @override
  List<Object?> get props =>
      [id, name, matchType, numberOfCourts, status, startedAt, endedAt];
}

/// Mirrors `CreateSessionRequest` in api-spec.json.
class CreateSessionRequest extends Equatable {
  const CreateSessionRequest({
    this.name,
    required this.matchType,
    required this.numberOfCourts,
  });

  /// Optional, max 100 chars.
  final String? name;

  /// "Singles" or "Doubles".
  final String matchType;

  /// 1–20.
  final int numberOfCourts;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        'matchType': matchType,
        'numberOfCourts': numberOfCourts,
      };

  @override
  List<Object?> get props => [name, matchType, numberOfCourts];
}

/// Mirrors `UpdateSessionRequest` (partial update — all fields optional).
class UpdateSessionRequest extends Equatable {
  const UpdateSessionRequest({this.name, this.matchType, this.numberOfCourts});

  final String? name;
  final String? matchType;
  final int? numberOfCourts;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (matchType != null) 'matchType': matchType,
        if (numberOfCourts != null) 'numberOfCourts': numberOfCourts,
      };

  @override
  List<Object?> get props => [name, matchType, numberOfCourts];
}
