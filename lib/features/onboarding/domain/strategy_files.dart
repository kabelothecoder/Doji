/// Files a trader can attach to their strategy during onboarding: a PDF,
/// a chart screenshot or a short screen recording. Kept on the device as
/// sources of the first account; the AI reads them once sync is on.
/// TODO(backend): upload to Storage `sources` and let `ai-strategy` read them.
enum StrategyFileKind { pdf, image, video }

const kStrategyFileExtensions = ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'mp4', 'mov', 'm4v'];

/// Videos above this are refused: they would not upload on a phone connection.
const kMaxVideoBytes = 200 * 1024 * 1024;

StrategyFileKind? strategyFileKind(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return switch (name.substring(dot + 1).toLowerCase()) {
    'pdf' => StrategyFileKind.pdf,
    'png' || 'jpg' || 'jpeg' || 'webp' => StrategyFileKind.image,
    'mp4' || 'mov' || 'm4v' => StrategyFileKind.video,
    _ => null,
  };
}

/// Doji's line when a file can't be attached, or null when it can.
String? strategyFileProblem(String name, int bytes) {
  final kind = strategyFileKind(name);
  if (kind == null) return 'that file type won\'t open here. a pdf, image or video works.'; // doji voice
  if (kind == StrategyFileKind.video && bytes > kMaxVideoBytes) {
    return 'that video is over 200 mb. a shorter clip works.'; // doji voice
  }
  return null;
}
