import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:paddleq/core/api/paddleq_api.dart';
import 'package:paddleq/core/theme/app_theme.dart';
import 'package:paddleq/features/welcome/view/welcome_page.dart';

class PaddleQApp extends StatelessWidget {
  const PaddleQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<PaddleqApi>(
      create: (_) => PaddleqApi(),
      child: MaterialApp(
        title: 'PaddleQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const WelcomePage(),
      ),
    );
  }
}
