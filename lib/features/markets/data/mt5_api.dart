import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/market_data.dart';

/// The app's side of the `mt5` edge function (supabase/functions/mt5). The
/// MetaRPC key, the terminal id and the MT5 password never reach the device:
/// the app sends its Supabase session and a [TradingAccount] id.
abstract interface class Mt5Api {
  /// Calls [action] for the account [accountRef]. Throws [Mt5Failure] when the
  /// function or the broker refuses, [FeedUnavailable] when it can't be reached.
  Future<Map<String, dynamic>> call(String action, String accountRef, [Map<String, Object?> body = const {}]);
}

/// The function answered with an error ("not linked", wrong password, …).
class Mt5Failure implements Exception {
  const Mt5Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'Mt5Failure($code): $message';
}

class SupabaseMt5Api implements Mt5Api {
  const SupabaseMt5Api(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> call(
    String action,
    String accountRef, [
    Map<String, Object?> body = const {},
  ]) async {
    if (_client.auth.currentSession == null) throw const Mt5Failure('sign in to use your broker.');
    try {
      final res = await _client.functions.invoke(
        'mt5',
        body: {...body, 'action': action, 'accountRef': accountRef},
      );
      final data = res.data;
      return data is Map<String, dynamic> ? data : const {};
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? '${details['error'] ?? 'broker refused'}' : 'broker refused';
      final code = details is Map ? details['code'] as String? : null;
      if (e.status >= 500 && code == null) throw FeedUnavailable(message);
      throw Mt5Failure(message, code: code);
    } on Mt5Failure {
      rethrow;
    } on Object catch (e) {
      throw FeedUnavailable('$e');
    }
  }
}

/// Set in bootstrap when Supabase started; null runs the app fully local
/// (and in tests).
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Null without Supabase: broker links, MT5 prices and live rates are then off.
final mt5ApiProvider = Provider<Mt5Api?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseMt5Api(client);
});
