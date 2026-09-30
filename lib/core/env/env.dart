import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration. Priority: `--dart-define` > `assets/env/.env` > empty.
///
/// Never hardcode keys here. Empty values mean "run fully local": the app
/// skips Supabase and onboarding still works end to end.
class Env {
  const Env({required this.supabaseUrl, required this.supabaseAnonKey});

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<Env> load() async {
    await dotenv.load(fileName: 'assets/env/.env', isOptional: true);
    String pick(String define, String key) => define.isNotEmpty ? define : (dotenv.maybeGet(key) ?? '');
    return Env(
      supabaseUrl: pick(_defineUrl, 'SUPABASE_URL'),
      supabaseAnonKey: pick(_defineKey, 'SUPABASE_ANON_KEY'),
    );
  }
}
