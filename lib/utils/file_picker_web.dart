import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:js_util' as js_util;

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

    // Attempt to extract text content for simple formats on web (txt, docx).
    String? content;
    final nameLower = file.name.toLowerCase();
    try {
      if (bytes != null) {
        if (nameLower.endsWith('.txt')) {
          try {
            content = utf8.decode(bytes);
          } catch (_) {
            content = null;
          }
        } else if (nameLower.endsWith('.docx')) {
          try {
            final archive = ZipDecoder().decodeBytes(bytes);
            ArchiveFile? docEntry;
            for (final f in archive) {
              if (f.name.toLowerCase().endsWith('word/document.xml')) {
                docEntry = f;
                break;
              }
            }
            if (docEntry != null) {
              final xmlStr = utf8.decode(docEntry.content as List<int>);
              final xmlDoc = XmlDocument.parse(xmlStr);
              final buffer = StringBuffer();
              final texts = xmlDoc.findAllElements('t');
              for (final node in texts) {
                buffer.write(node.text);
                buffer.write(' ');
              }
              content = buffer.toString().trim();
            }
          } catch (_) {
            content = null;
          }
        }
        // PDF text extraction on web: use the JS helper (pdf.js) if available.
        if (nameLower.endsWith('.pdf')) {
          try {
            // convert bytes to base64
            final base64 = base64Encode(bytes);
            final jsResult = js_util.getProperty(html.window, 'extractPdfText');
            if (jsResult != null) {
              // retry up to 2 times with small backoff
              String? lastText;
              for (int attempt = 1; attempt <= 2; attempt++) {
                try {
                  final promise = js_util.callMethod(html.window, 'extractPdfText', [base64]);
                  final text = await js_util.promiseToFuture<String?>(promise);
                  lastText = text;
                  if (text != null && text.trim().isNotEmpty) break;
                } catch (err) {
                  try { html.window.console.error('pdf.js extraction attempt $attempt failed: $err'); } catch (_) {}
                }
                // small backoff
                await Future.delayed(Duration(milliseconds: 250 * attempt));
              }
              content = lastText;
              try { html.window.console.log('file_picker_web: pdf extraction length=${content?.length ?? 0} for ${file.name}'); } catch (_) {}
            } else {
              try { html.window.console.warn('file_picker_web: extractPdfText not found on window'); } catch (_) {}
            }
          } catch (e) {
            try { html.window.console.error('file_picker_web: pdf extraction unexpected error: $e'); } catch (_) {}
            content = null;
          }
        }
      }
    } catch (_) {
      content = null;
    }

    completer.complete({
      'name': file.name,
      'size': file.size,
      'lastModified': file.lastModified,
      'bytes': bytes,
      'content': content,
    });
  }

  input.onChange.listen(changeHandler);
  input.click();

  return completer.future;
}
