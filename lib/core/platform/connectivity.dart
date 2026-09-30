import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` while the device has any network interface up.
///
/// Onboarding is local-first, so this only drives the
/// "> connection lost. your answers are saved._" line; nothing blocks on it.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) => r.isNotEmpty && !r.every((c) => c == ConnectivityResult.none);
  try {
    yield online(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(online);
  } catch (_) {
    // Plugin unavailable (tests, unsupported platform): assume online.
    yield true;
  }
});
