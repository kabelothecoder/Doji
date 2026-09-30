import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/platform/platform_info.dart';

enum VoiceAvailability { available, permissionDenied, unsupported }

/// Dictation for "describe your strategy". Everything degrades to typing:
/// if this says anything other than [VoiceAvailability.available], the mic
/// button hides and the text field carries on.
abstract interface class VoiceInput {
  /// Cheap, no permission prompt: false when this platform has no dictation,
  /// so the mic button never shows at all.
  bool get mightBeAvailable;

  /// May show the OS microphone / speech prompts. Call on the first mic tap.
  Future<VoiceAvailability> prepare();

  Future<void> start({
    required void Function(String words, bool isFinal) onResult,
    required VoidCallback onStopped,
  });

  Future<void> stop();
}

class SpeechToTextVoiceInput implements VoiceInput {
  SpeechToTextVoiceInput([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  VoidCallback? _onStopped;
  bool _ready = false;

  @override
  bool get mightBeAvailable => true;

  @override
  Future<VoiceAvailability> prepare() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) return VoiceAvailability.permissionDenied;
      _ready = await _speech.initialize(
        onStatus: (s) {
          if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) {
            _onStopped?.call();
          }
        },
        onError: (_) => _onStopped?.call(),
      );
      if (!_ready) {
        return await _speech.hasPermission
            ? VoiceAvailability.unsupported
            : VoiceAvailability.permissionDenied;
      }
      return VoiceAvailability.available;
    } on Object {
      // MissingPluginException, PlatformException: treat as no voice.
      return VoiceAvailability.unsupported;
    }
  }

  @override
  Future<void> start({
    required void Function(String words, bool isFinal) onResult,
    required VoidCallback onStopped,
  }) async {
    if (!_ready) return onStopped();
    _onStopped = onStopped;
    await _speech.listen(
      onResult: (SpeechRecognitionResult r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }
}

/// Windows (for now), tests, and anywhere speech isn't wired: text only.
class UnavailableVoiceInput implements VoiceInput {
  const UnavailableVoiceInput();

  @override
  bool get mightBeAvailable => false;

  @override
  Future<VoiceAvailability> prepare() async => VoiceAvailability.unsupported;

  @override
  Future<void> start({
    required void Function(String words, bool isFinal) onResult,
    required VoidCallback onStopped,
  }) async => onStopped();

  @override
  Future<void> stop() async {}
}

/// TODO(next-slice): try speech_to_text_windows (beta) behind a flag before
/// enabling dictation on Windows.
final voiceInputProvider = Provider<VoiceInput>(
  (ref) => PlatformInfo.isWindows || kIsWeb ? const UnavailableVoiceInput() : SpeechToTextVoiceInput(),
);
