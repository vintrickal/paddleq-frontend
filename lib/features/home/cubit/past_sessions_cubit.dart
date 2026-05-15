import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/storage/past_sessions_store.dart';

/// App-lifetime cubit holding the list of past sessions surfaced on Home.
///
/// Hydrates from [PastSessionsStore] on construction and rebroadcasts the
/// updated list whenever [recordSession] writes a new entry. UI binds to
/// it via `BlocBuilder<PastSessionsCubit, List<PastSession>>`.
class PastSessionsCubit extends Cubit<List<PastSession>> {
  PastSessionsCubit({PastSessionsStore? store})
      : _store = store ?? PastSessionsStore(),
        super(const []);

  final PastSessionsStore _store;

  /// One-shot load on app start.
  Future<void> hydrate() async {
    final all = await _store.loadAll();
    if (isClosed) return;
    emit(all);
  }

  /// Inserts [session] (replacing any existing row with the same id) and
  /// emits the updated, newest-first list.
  Future<void> recordSession(PastSession session) async {
    final next = await _store.append(session);
    if (isClosed) return;
    emit(next);
  }
}
