import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit() : super(const HomeState());

  Timer? _bumpTimer;

  void selectMode(GameMode mode) => emit(state.copyWith(mode: mode));

  void setSessionName(String name) =>
      emit(state.copyWith(sessionName: name));

  void increment() => _setCourts(state.courts + 1);
  void decrement() => _setCourts(state.courts - 1);
  void setCourts(int next) => _setCourts(next);

  void confirm() => emit(state.copyWith(confirmed: true));
  void dismissConfirm() => emit(state.copyWith(confirmed: false));

  void _setCourts(int next) {
    final clamped = next.clamp(1, state.maxCourts);
    if (clamped == state.courts) return;
    emit(state.copyWith(courts: clamped, bumping: true));

    _bumpTimer?.cancel();
    _bumpTimer = Timer(const Duration(milliseconds: 200), () {
      if (isClosed) return;
      emit(state.copyWith(bumping: false));
    });
  }

  @override
  Future<void> close() {
    _bumpTimer?.cancel();
    return super.close();
  }
}
