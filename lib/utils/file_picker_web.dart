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
    // Try to convert possible result types into a Uint8List. Some runtimes
    // (dart2js / compiled) may surface different JS types, so we add a
    // robust fallback: if ArrayBuffer read produced no bytes, read as DataURL
    // (base64) and decode.
    if (result is ByteBuffer) {
      bytes = Uint8List.view(result);
    }

    // Diagnostic logging: file metadata and bytes length (may be 0 at this point)
    try {
      html.window.console.log('file_picker_web: picked=${file.name}, size=${file.size}, lastModified=${file.lastModified}');
      html.window.console.log('file_picker_web: bytesLength=${bytes?.length ?? 0}');
    } catch (_) {}

    // If we didn't get bytes from readAsArrayBuffer, try DataURL fallback
    if ((bytes == null || bytes.isEmpty) && reader.readyState == html.FileReader.DONE) {
      try {
        final reader2 = html.FileReader();
        reader2.readAsDataUrl(file);
        await reader2.onLoad.first;
        final res2 = reader2.result;
        if (res2 is String) {
          // Data URL format: data:<mime>;base64,<base64data>
          final comma = res2.indexOf(',');
          if (comma != -1 && comma + 1 < res2.length) {
            final b64 = res2.substring(comma + 1);
            try {
              bytes = base64Decode(b64);
              try { html.window.console.log('file_picker_web: dataUrl fallback bytesLength=${bytes.length}'); } catch (_) {}
            } catch (e) {
              try { html.window.console.warn('file_picker_web: dataUrl parse failed: $e'); } catch (_) {}
            }
          }
        }
      } catch (e) {
        try { html.window.console.warn('file_picker_web: dataUrl fallback error: $e'); } catch (_) {}
      }
    }

    // Attempt to extract text content for simple formats on web (txt, docx).
    String? content;
    final nameLower = file.name.toLowerCase();
    try {
      if (bytes != null) {
        if (nameLower.endsWith('.txt')) {
          try {
            content = utf8.decode(bytes);
              try { html.window.console.log('file_picker_web: txt content length=${content.length}'); } catch (_) {}
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

              // DOCX uses namespaced w:t elements for text runs. Search for
              // any element whose localName is 't' to be tolerant to namespaces.
              for (final node in xmlDoc.descendants.whereType<XmlElement>()) {
                if (node.name.local == 't') {
                  // prefer text value; this covers plain text and CDATA
                  final txt = node.text;
                  if (txt.isNotEmpty) {
                    buffer.write(txt);
                    buffer.write(' ');
                  }
                }
              }

              content = buffer.toString().trim();
              try { html.window.console.log('file_picker_web: docx content length=${content.length}'); } catch (_) {}
            } else {
              try { html.window.console.warn('file_picker_web: docx zip did not contain word/document.xml'); } catch (_) {}
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
            try { html.window.console.log('file_picker_web: calling extractPdfText for ${file.name} (base64 length=${base64.length})'); } catch (_) {}
            final jsResult = js_util.getProperty(html.window, 'extractPdfText');
            if (jsResult != null) {
              final promise = js_util.callMethod(html.window, 'extractPdfText', [base64]);
              final text = await js_util.promiseToFuture<String?>(promise);
              content = text;
              try { html.window.console.log('file_picker_web: pdf extract length=${text?.length ?? 0}'); } catch (_) {}
            } else {
              try { html.window.console.warn('file_picker_web: extractPdfText not found on window'); } catch (_) {}
            }
          } catch (e) {
            // log error and leave content null
            try { html.window.console.error('file_picker_web: pdf extraction error for ${file.name}: $e'); } catch (_) {}
            content = null;
          }
        }
      }
    } catch (e) {
      try { html.window.console.error('file_picker_web: unexpected extraction error for ${file.name}: $e'); } catch (_) {}
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
