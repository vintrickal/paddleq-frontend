import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/theme/app_theme.dart';
import 'package:paddleq/features/home/cubit/past_sessions_cubit.dart';
import 'package:paddleq/features/welcome/view/welcome_page.dart';

class PaddleQApp extends StatelessWidget {
  const PaddleQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PaddleqApi>(create: (_) => PaddleqApi()),
      ],
      child: BlocProvider<PastSessionsCubit>(
        // Hydrates from localStorage at app start; lives for the whole
        // app lifetime so Home, the post-session LeaderboardPage, and the
        // past-session dialogs all share the same source of truth.
        create: (_) => PastSessionsCubit()..hydrate(),
        child: MaterialApp(
          title: 'PaddleQ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const WelcomePage(),
        ),
      ),
    );
  }
}
