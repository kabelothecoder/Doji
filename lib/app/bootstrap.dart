import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env/env.dart';
import '../features/markets/data/mt5_api.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import 'app.dart';

final envProvider = Provider<Env>((ref) => const Env(supabaseUrl: '', supabaseAnonKey: ''));

/// Starts the app. The native splash (flutter_native_splash) stays up until
/// the intro's first frame, which paints the same icon, so the hand-over is
/// seamless.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = await Env.load();
  SupabaseClient? supabase;
  if (env.hasSupabase) {
    try {
      // supabase_flutter 2.18 names the client key "publishable"; a legacy anon key works too.
      await Supabase.initialize(url: env.supabaseUrl, publishableKey: env.supabaseAnonKey);
      supabase = Supabase.instance.client;
    } on Object catch (e) {
      // Local-first: a bad or unreachable config must never block onboarding.
      debugPrint('supabase init skipped: $e');
    }
  }
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        envProvider.overrideWithValue(env),
        supabaseClientProvider.overrideWithValue(supabase),
      ],
      child: const DojiApp(),
    ),
  );
}
