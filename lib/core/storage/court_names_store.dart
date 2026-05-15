import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent storage for host-renamed court labels, keyed by session id.
///
/// On Flutter Web this hits `localStorage`, so renames survive browser
/// refreshes for the same active session. The data is purely a UX
/// convenience — court labels aren't part of the backend's domain model.
///
/// One entry per session: starting a fresh session (new id) yields a clean
/// slate. Old entries hang around in storage indefinitely; harmless given
/// their small size, but [clear] is available if a future "reset" feature
/// wants to use it.
class CourtNamesStore {
  CourtNamesStore({SharedPreferences? prefs}) : _override = prefs;

  /// Allow injecting a pre-resolved [SharedPreferences] (used by tests).
  final SharedPreferences? _override;

  static const _keyPrefix = 'paddleq.court_names.';

  String _keyFor(int sessionId) => '$_keyPrefix$sessionId';

  Future<SharedPreferences> _prefs() async =>
      _override ?? await SharedPreferences.getInstance();

  /// Returns the saved court-name map for [sessionId], or an empty map if
  /// nothing has been persisted yet. Never throws — corrupt entries are
  /// treated as missing.
  Future<Map<int, String>> load(int sessionId) async {
    final prefs = await _prefs();
    final raw = prefs.getString(_keyFor(sessionId));
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <int, String>{};
      for (final entry in decoded.entries) {
        final idx = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (idx == null || value is! String) continue;
        out[idx] = value;
      }
      return out;
    } catch (_) {
      return const {};
    }
  }

  /// Persists [names] for [sessionId]. An empty map clears the entry
  /// rather than storing a stale `{}`.
  Future<void> save(int sessionId, Map<int, String> names) async {
    final prefs = await _prefs();
    final key = _keyFor(sessionId);
    if (names.isEmpty) {
      await prefs.remove(key);
      return;
    }
    final stringified = <String, String>{
      for (final entry in names.entries) entry.key.toString(): entry.value,
    };
    await prefs.setString(key, jsonEncode(stringified));
  }

  /// Drops the saved entry for [sessionId]. No-op when nothing's stored.
  Future<void> clear(int sessionId) async {
    final prefs = await _prefs();
    await prefs.remove(_keyFor(sessionId));
  }
}
