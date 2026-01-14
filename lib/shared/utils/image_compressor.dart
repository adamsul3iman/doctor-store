import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'package:doctor_store/utils/web_image_converter.dart';

/// Result object returned by [AppImageCompressor].
class CompressedImageResult {
  final Uint8List bytes;
  final String extension; // e.g. "webp", "jpg"

  const CompressedImageResult({required this.bytes, required this.extension});
}

/// High-level image compression helper used before uploading to Supabase.
///
/// Goals:
/// - Resize huge images down to a safe max dimension (1024px).
/// - Prefer WebP when available for smaller size.
/// - Try to keep the payload under ~1MB to avoid HTTP 413 errors.
/// - Use flutter_image_compress on mobile/desktop and a canvas-based
///   converter on web.
class AppImageCompressor {
  /// Target upper bound for the encoded image size.
  static const int _maxBytes = 1024 * 1024; // 1 MB

  /// Maximum width/height of the compressed image.
  static const int _maxDimension = 1024;

  /// Compresses [originalBytes] into a smaller, upload-friendly image.
  ///
  /// [originalExtension] is only used as a best-effort fallback when
  /// WebP conversion fails.
  static Future<CompressedImageResult> compress(
    Uint8List originalBytes, {
    String? originalExtension,
  }) async {
    if (originalBytes.isEmpty) {
      return CompressedImageResult(
        bytes: originalBytes,
        extension: (originalExtension ?? 'jpg').toLowerCase(),
      );
    }

    final ext = (originalExtension ?? 'jpg').toLowerCase();

    if (kIsWeb) {
      return _compressForWeb(originalBytes, ext);
    } else {
      return _compressForMobile(originalBytes, ext);
    }
  }

  /// Web implementation: use the HTML canvas based [WebImageConverter]
  /// and iteratively reduce quality until we are under [_maxBytes]
  /// or we hit a minimum quality threshold.
  static Future<CompressedImageResult> _compressForWeb(
    Uint8List bytes,
    String originalExt,
  ) async {
    try {
      int quality = 80;
      Uint8List current = bytes;

      while (true) {
        current = await WebImageConverter.convertToWebP(
          bytes,
          quality: quality,
          maxDimension: _maxDimension,
        );

        if (current.lengthInBytes <= _maxBytes || quality <= 50) {
          break;
        }

        quality -= 10;
      }

      return CompressedImageResult(bytes: current, extension: 'webp');
    } catch (_) {
      // Fallback: return original bytes. This might exceed 1MB in extreme
      // cases, but it's better than breaking the UX.
      return CompressedImageResult(bytes: bytes, extension: originalExt);
    }
  }

  /// Mobile/desktop implementation using flutter_image_compress.
  ///
  /// We always try to encode as WebP for better size characteristics and
  /// progressively lower the quality until we are under [_maxBytes]
  /// or we reach a minimum quality threshold.
  static Future<CompressedImageResult> _compressForMobile(
    Uint8List bytes,
    String originalExt,
  ) async {
    try {
      int quality = 80;
      Uint8List current = bytes;

      while (true) {
        current = await FlutterImageCompress.compressWithList(
          bytes,
          format: CompressFormat.webp,
          quality: quality,
          minWidth: _maxDimension,
          minHeight: _maxDimension,
        );

        if (current.lengthInBytes <= _maxBytes || quality <= 50) {
          break;
        }

        quality -= 10;
      }

      return const CompressedImageResultExtension().fromBytes(current);
    } catch (_) {
      // If compression fails (very rare), return the original data.
      return CompressedImageResult(bytes: bytes, extension: originalExt);
    }
  }
}

/// Small helper extension to keep [AppImageCompressor] code tidy.
class CompressedImageResultExtension {
  const CompressedImageResultExtension();

  CompressedImageResult fromBytes(Uint8List bytes) {
    return CompressedImageResult(bytes: bytes, extension: 'webp');
  }
}
