part of 'home_cubit.dart';

enum GameMode { singles, doubles }

extension GameModeX on GameMode {
  int get playersPerCourt => this == GameMode.singles ? 2 : 4;
  String get label => this == GameMode.singles ? 'Singles' : 'Doubles';
}

final class HomeState extends Equatable {
  const HomeState({
    this.mode = GameMode.doubles,
    this.courts = 1,
    this.confirmed = false,
    this.maxCourts = 8,
    this.bumping = false,
    this.showRecent = true,
    this.sessionName = '',
  });

  final GameMode mode;
  final int courts;
  final bool confirmed;
  final int maxCourts;

  /// Drives the brief scale-up animation on the counter readout.
  final bool bumping;
  final bool showRecent;

  /// Free-form name the user gives this play session — surfaced on the Court
  /// page above the live-courts header.
  final String sessionName;

  int get playersPerCourt => mode.playersPerCourt;
  int get totalPlayers => playersPerCourt * courts;

  HomeState copyWith({
    GameMode? mode,
    int? courts,
    bool? confirmed,
    int? maxCourts,
    bool? bumping,
    bool? showRecent,
    String? sessionName,
  }) =>
      HomeState(
        mode: mode ?? this.mode,
        courts: courts ?? this.courts,
        confirmed: confirmed ?? this.confirmed,
        maxCourts: maxCourts ?? this.maxCourts,
        bumping: bumping ?? this.bumping,
        showRecent: showRecent ?? this.showRecent,
        sessionName: sessionName ?? this.sessionName,
      );

  @override
  List<Object?> get props =>
      [mode, courts, confirmed, maxCourts, bumping, showRecent, sessionName];
}
