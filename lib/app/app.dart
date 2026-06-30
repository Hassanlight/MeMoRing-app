/// Root app widget.
library;

import 'package:flutter/material.dart';
import 'package:memoring/app/router/app_router.dart';
import 'package:memoring/app/theme/app_theme.dart';

class MemoringApp extends StatelessWidget {
  MemoringApp({super.key});

  final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Memoring',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
