import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/doji_theme.dart';
import '../features/app_lock/presentation/app_lock_gate.dart';
import 'router.dart';

class DojiApp extends ConsumerWidget {
  const DojiApp({super.key});

  /// "Dynamic Type / text scaling up to 200% without clipping."
  static const maxTextScale = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'doji',
      debugShowCheckedModeBanner: false,
      // Dark first. The light theme is a stub for a later slice.
      theme: dojiDarkTheme(),
      darkTheme: dojiDarkTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxTextScale,
        child: AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
