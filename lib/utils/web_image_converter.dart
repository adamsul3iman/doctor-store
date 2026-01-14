// Platform-agnostic entry point for WebImageConverter.
//
// On web, this exports the implementation that uses `dart:html` and canvas
// to convert images to WebP.
// On non-web platforms (Android, iOS, desktop), it exports a lightweight
// implementation that simply returns the original bytes.
export 'web_image_converter_io.dart'
    if (dart.library.html) 'web_image_converter_web.dart';
