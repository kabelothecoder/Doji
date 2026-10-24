import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app/bootstrap.dart';

/// Smallest Windows window, and the size it opens at. Keeps the wide plans
/// layout (300 + 380 columns plus margins) from being squashed.
const Size _windowsMinSize = Size(1100, 700);

Future<void> main() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: _windowsMinSize, minimumSize: _windowsMinSize, center: true),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  await bootstrap();
}
