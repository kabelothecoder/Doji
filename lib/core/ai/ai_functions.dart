import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/markets/data/mt5_api.dart' show supabaseClientProvider;

/// Why an AI call gave no answer. Every caller falls back to its on-device
/// fake, so the screen never hangs on a failed call.
sealed class AiFailure implements Exception {
  const AiFailure(this.code);

  final String code;

  @override
  String toString() => 'AiFailure($code)';
}

/// Not signed in: the functions need the Supabase session.
class AiNoSession extends AiFailure {
  const AiNoSession() : super('NO_SESSION');
}

class AiOffline extends AiFailure {
  const AiOffline() : super('OFFLINE');
}

class AiRateLimited extends AiFailure {
  const AiRateLimited() : super('RATE_LIMITED');
}

/// Free plan: today's brief went to another instrument (counted on the server).
class AiBriefUsed extends AiFailure {
  const AiBriefUsed() : super('BRIEF_USED');
}

class AiUnavailable extends AiFailure {
  const AiUnavailable([super.code = 'AI_UNAVAILABLE']);
}

/// The door to the `ai-*` edge functions (Gemini lives behind them; the app
/// never holds a model key).
abstract interface class AiFunctions {
  /// POSTs [body] to [name]; the decoded JSON, or throws an [AiFailure].
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> body);
}

class SupabaseAiFunctions implements AiFunctions {
  const SupabaseAiFunctions(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, Object?> body) async {
    if (_client.auth.currentSession == null) throw const AiNoSession();
    try {
      final res = await _client.functions.invoke(name, body: body);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw const AiUnavailable('BAD_RESPONSE');
    } on FunctionException catch (e) {
      throw switch (e.status) {
        401 => const AiNoSession(),
        402 => const AiBriefUsed(),
        429 => const AiRateLimited(),
        _ => AiUnavailable('HTTP_${e.status}'),
      };
    } on AiFailure {
      rethrow;
    } on Object {
      throw const AiOffline();
    }
  }
}

/// Null without Supabase (local runs and tests): the fakes answer.
final aiFunctionsProvider = Provider<AiFunctions?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAiFunctions(client);
});
