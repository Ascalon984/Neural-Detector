import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation using native File input to access lastModified reliably.
Future<Map<String, dynamic>?> pickFileWeb({List<String>? accept}) {
  final completer = Completer<Map<String, dynamic>?>();

  final input = html.FileUploadInputElement();
  input.accept = accept?.join(',') ?? '';
  input.multiple = false;

  void changeHandler(html.Event e) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files[0];
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    Uint8List? bytes;
    if (result is ByteBuffer) bytes = Uint8List.view(result);

    completer.complete({
      'name': file.name,
      'size': file.size,
      'lastModified': file.lastModified,
      'bytes': bytes,
    });
  }

  input.onChange.listen(changeHandler);
  input.click();

  return completer.future;
}
