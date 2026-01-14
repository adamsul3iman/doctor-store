import 'dart:typed_data';

/// Cross-platform fallback implementation for non-web targets (Android, iOS, desktop).
///
/// On these platforms we simply return the original bytes without attempting WebP conversion.
class WebImageConverter {
  static Future<Uint8List> convertToWebP(
    Uint8List bytes, {
    int quality = 75,
    int maxDimension = 1024,
  }) async {
    // On non-web targets we don't perform any canvas-based conversion.
    // The parameter [maxDimension] is kept for API compatibility and
    // to mirror the web implementation but is not used here.
    return bytes;
  }
}
