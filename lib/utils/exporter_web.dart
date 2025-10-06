import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation that triggers a browser download for given bytes.
Future<String?> saveBytesAsFile(Uint8List bytes, String filename) async {
  try {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement;
    anchor.href = url;
    anchor.download = filename;
    // Some browsers require the anchor to be in the document
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return filename;
  } catch (e) {
    return null;
  }
}
