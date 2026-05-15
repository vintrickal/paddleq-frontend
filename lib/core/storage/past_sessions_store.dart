import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:paddleq/core/models/_json.dart';
import 'package:paddleq/core/models/match_dtos.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One past session's frozen-in-time snapshot — used by Home to render the
/// "Past sessions" list and the per-session leaderboard modal.
///
/// The backend's leaderboard endpoint only returns the **active** session,
/// so we have to capture the ranking from the cubit at end-time. The full
/// snapshot is then persisted to `localStorage` via [PastSessionsStore].
///
/// This is per-browser-per-device. Cross-device history would require a
/// backend endpoint (`GET /api/sessions/{id}/leaderboard`), which the
/// repository layer already supports but isn't exposed yet.
class PastSession extends Equatable {
  const PastSession({
    required this.sessionId,
    required this.name,
    required this.matchType,
    required this.numberOfCourts,
    required this.startedAt,
    required this.endedAt,
    required this.leaderboard,
  });

  final int sessionId;
  final String name;
  final String matchType;
  final int numberOfCourts;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LeaderboardEntryResponse> leaderboard;

  factory PastSession.fromJson(Map<String, dynamic> json) => PastSession(
        sessionId: json['sessionId'] as int,
        name: (json['name'] ?? '') as String,
        matchType: (json['matchType'] ?? '') as String,
        numberOfCourts: json['numberOfCourts'] as int,
        startedAt: parseUtc(json['startedAt']),
        endedAt: parseUtc(json['endedAt']),
        leaderboard: ((json['leaderboard'] as List?) ?? const [])
            .map((e) =>
                LeaderboardEntryResponse.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'name': name,
        'matchType': matchType,
        'numberOfCourts': numberOfCourts,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'leaderboard': leaderboard.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props => [
        sessionId,
        name,
        matchType,
        numberOfCourts,
        startedAt,
        endedAt,
        leaderboard,
      ];
}

/// Persists [PastSession]s to `SharedPreferences` (web `localStorage`).
///
/// Ordering: newest first. A soft cap of 50 entries keeps the JSON blob
/// small enough that we can afford to read+write the whole list on each
/// mutation; sessions older than that are dropped on append.
class PastSessionsStore {
  PastSessionsStore({SharedPreferences? prefs}) : _override = prefs;

  final SharedPreferences? _override;
  static const _key = 'paddleq.past_sessions.v1';
  static const _maxEntries = 50;

  Future<SharedPreferences> _prefs() async =>
      _override ?? await SharedPreferences.getInstance();

  /// Returns all known past sessions, newest-first. Corrupt entries are
  /// dropped silently rather than blowing up the home screen.
  Future<List<PastSession>> loadAll() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final out = <PastSession>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        try {
          out.add(PastSession.fromJson(entry.cast<String, dynamic>()));
        } catch (_) {
          // skip individual broken rows
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Inserts [session] at the front of the list. If an entry with the
  /// same `sessionId` already exists, the older one is replaced. The
  /// list is then trimmed to [_maxEntries].
  Future<List<PastSession>> append(PastSession session) async {
    final current = await loadAll();
    final filtered =
        current.where((s) => s.sessionId != session.sessionId).toList();
    filtered.insert(0, session);
    final trimmed = filtered.take(_maxEntries).toList(growable: false);
    final prefs = await _prefs();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
    return trimmed;
  }

  /// Drops every saved past session. Currently unused by the UI; available
  /// for a future "Clear history" affordance.
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_key);
  }
}
