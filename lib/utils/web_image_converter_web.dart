// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

/// Web-only implementation that converts images to WebP using HTML canvas APIs.
class WebImageConverter {
  /// Converts raw image bytes to WebP format using a canvas in the browser.
  ///
  /// - Resizes the image so that the longest side is at most [maxDimension].
  /// - Encodes as WebP with the given [quality] (0–100).
  ///
  /// If conversion fails for any reason, the original [bytes] are returned.
  static Future<Uint8List> convertToWebP(
    Uint8List bytes, {
    int quality = 75,
    int maxDimension = 1024,
  }) async {
    // Create a Blob URL from the original bytes
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrl(blob);

    try {
      final img = html.ImageElement(src: url);
      await img.onLoad.first;

      int srcWidth = img.width ?? 0;
      int srcHeight = img.height ?? 0;

      if (srcWidth <= 0 || srcHeight <= 0) {
        return bytes;
      }

      // Clamp the longest side to [maxDimension] while preserving aspect ratio
      final maxSide = srcWidth > srcHeight ? srcWidth : srcHeight;
      double scale = 1.0;
      if (maxSide > maxDimension) {
        scale = maxDimension / maxSide;
      }

      final targetWidth = (srcWidth * scale).round();
      final targetHeight = (srcHeight * scale).round();

      final canvas = html.CanvasElement(
        width: targetWidth,
        height: targetHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImageScaled(img, 0, 0, targetWidth, targetHeight);

      final webpBlob = await _canvasToWebPBlob(canvas, quality);
      if (webpBlob == null) {
        return bytes;
      }

      final reader = html.FileReader();
      final completer = Completer<Uint8List>();

      reader.onError.listen((_) {
        completer.complete(bytes);
      });

      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is ByteBuffer) {
          completer.complete(Uint8List.view(result));
        } else if (result is Uint8List) {
          completer.complete(result);
        } else {
          completer.complete(bytes);
        }
      });

      reader.readAsArrayBuffer(webpBlob);
      return completer.future;
    } finally {
      // Always revoke the temporary URL
      html.Url.revokeObjectUrl(url);
    }
  }

  static Future<html.Blob?> _canvasToWebPBlob(
    html.CanvasElement canvas,
    int quality,
  ) {
    final q = quality.clamp(0, 100) / 100;

    // Modern `toBlob` API on web returns a Future<Blob?> directly.
    return canvas.toBlob('image/webp', q);
  }
}
