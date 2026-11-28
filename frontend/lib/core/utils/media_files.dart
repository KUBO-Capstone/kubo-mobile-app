import 'dart:io';

import 'package:http_parser/http_parser.dart' show MediaType;

/// Largest video the app sends; the server refuses anything bigger.
const int maxVideoBytes = 10 * 1024 * 1024;

/// Whether a URL or file path is a video, from its extension (the query of
/// a presigned URL ignored).
bool isVideoSource(String source) =>
    RegExp(r'\.(mp4|mov|webm|m4v)$', caseSensitive: false).hasMatch(source.split(RegExp(r'[?#]')).first);

/// The multipart content type for an upload, from its file name. The server
/// checks the bytes anyway; this only has to be plausible.
MediaType uploadContentType(String path) {
  return switch (path.split('.').last.toLowerCase()) {
    'png' => MediaType('image', 'png'),
    'webp' => MediaType('image', 'webp'),
    'mp4' || 'm4v' => MediaType('video', 'mp4'),
    'mov' => MediaType('video', 'quicktime'),
    'webm' => MediaType('video', 'webm'),
    _ => MediaType('image', 'jpeg'),
  };
}

/// "Videos must be 10 MB or smaller." when [file] is a video over the limit;
/// null otherwise.
Future<String?> videoTooLargeMessage(File file) async {
  if (!isVideoSource(file.path)) return null;
  final bytes = await file.length();
  return bytes > maxVideoBytes ? 'Videos must be 10 MB or smaller.' : null;
}
