import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'package:ai_text_checker/utils/robust_worker.dart' as rw;
import 'package:image/image.dart' as img_test;

void main() {
  test('preprocessImageBytesCompute returns bytes for small jpeg', () async {
    // Create a tiny red jpg
  final img = img_test.Image(width: 100, height: 100);
    for (int y = 0; y < 100; y++) {
      for (int x = 0; x < 100; x++) {
        img.setPixelRgba(x, y, 200, 0, 0, 255);
      }
    }
    final bytes = Uint8List.fromList(img_test.encodeJpg(img));

    final out = rw.preprocessImageBytesCompute(bytes);
    expect(out, isNotNull);
    expect(out.length, greaterThan(0));
  });
}
