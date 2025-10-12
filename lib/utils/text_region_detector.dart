import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class TextDetectionResult {
  final bool hasText;
  final double confidence;
  final Map<String, int>? textRegions;

  TextDetectionResult({required this.hasText, required this.confidence, this.textRegions});

  Map<String, dynamic> toMap() => {
        'hasText': hasText,
        'confidence': confidence,
        'textRegions': textRegions,
      };

  factory TextDetectionResult.fromMap(Map<String, dynamic> m) => TextDetectionResult(
        hasText: m['hasText'] as bool? ?? false,
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
        textRegions: m['textRegions'] != null ? Map<String, int>.from(m['textRegions'] as Map) : null,
      );
}

// Preprocess JPEG bytes: decode, resize to max 800px, apply light contrast.
Uint8List preprocessImageBytes(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    const maxDim = 800;
    int newW = image.width;
    int newH = image.height;
    if (math.max(newW, newH) > maxDim) {
      if (newW > newH) {
        newH = (newH * maxDim / newW).round();
        newW = maxDim;
      } else {
        newW = (newW * maxDim / newH).round();
        newH = maxDim;
      }
    }

    final resized = img.copyResize(image, width: newW, height: newH);
    final enhanced = img.adjustColor(resized, contrast: 1.05, saturation: 1.0);
    final out = img.encodeJpg(enhanced, quality: 75);
    return Uint8List.fromList(out);
  } catch (e) {
    return bytes;
  }
}

// Optimized text detection for small devices: returns simple result and optional regions
TextDetectionResult optimizedTextDetection(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return TextDetectionResult(hasText: false, confidence: 0.0);

    // Downscale for performance - target 300x300 max
    final targetSize = 300;
    final width = image.width;
    final height = image.height;

    int newWidth, newHeight;
    if (width > height) {
      newWidth = targetSize;
      newHeight = (height * targetSize / width).round();
    } else {
      newHeight = targetSize;
      newWidth = (width * targetSize / height).round();
    }

    final resized = img.copyResize(image, width: newWidth, height: newHeight);
    final gray = img.grayscale(resized);
    final threshold = _calculateOptimalThreshold(gray);
    final binary = img.Image(width: gray.width, height: gray.height);

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final pixel = gray.getPixel(x, y);
        final lum = img.getLuminance(pixel);
        if (lum > threshold) {
          binary.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          binary.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }

    final edges = img.sobel(gray);
    int edgeCount = 0;
    const edgeThreshold = 30;
    const minEdgeRatio = 0.02;

    for (int y = 0; y < edges.height; y++) {
      for (int x = 0; x < edges.width; x++) {
        final pixel = edges.getPixel(x, y);
        if (img.getLuminance(pixel) > edgeThreshold) edgeCount++;
      }
    }

    final edgeRatio = edgeCount / (edges.width * edges.height);
    final hasText = edgeRatio > minEdgeRatio;
    final confidence = math.min(edgeRatio * 20, 1.0);

    Map<String, int>? textRegions;
    if (hasText) {
      textRegions = _findTextRegions(edges);
    }

    return TextDetectionResult(hasText: hasText, confidence: confidence, textRegions: textRegions);
  } catch (e) {
    return TextDetectionResult(hasText: false, confidence: 0.0);
  }
}

int _calculateOptimalThreshold(img.Image gray) {
  final histogram = List<int>.filled(256, 0);
  for (int y = 0; y < gray.height; y++) {
    for (int x = 0; x < gray.width; x++) {
      final pixel = gray.getPixel(x, y);
      final luminance = img.getLuminance(pixel).round();
      histogram[luminance]++;
    }
  }

  int total = gray.width * gray.height;
  double sum = 0.0;
  for (int t = 0; t < 256; t++) sum += t * histogram[t];

  double sumB = 0.0;
  int wB = 0;
  int wF = 0;
  double varMax = 0.0;
  int threshold = 0;

  for (int t = 0; t < 256; t++) {
    wB += histogram[t];
    if (wB == 0) continue;

    wF = total - wB;
    if (wF == 0) break;

    sumB += t * histogram[t];
    final mB = sumB / wB;
    final mF = (sum - sumB) / wF;

    final varBetween = wB * wF * (mB - mF) * (mB - mF);

    if (varBetween > varMax) {
      varMax = varBetween;
      threshold = t;
    }
  }

  return threshold;
}

Map<String, int>? _findTextRegions(img.Image edges) {
  final width = edges.width;
  final height = edges.height;

  final regionSize = (math.min(width, height) * 0.3).round().clamp(50, 200);
  final threshold = (regionSize * regionSize * 0.05).round();

  Map<String, int>? bestRegion;
  double maxEdgeDensity = 0.0;

  final step = (regionSize * 0.5).round();

  for (int y = 0; y <= height - regionSize; y += step) {
    for (int x = 0; x <= width - regionSize; x += step) {
      int edgeCount = 0;

      for (int dy = 0; dy < regionSize; dy += 2) {
        for (int dx = 0; dx < regionSize; dx += 2) {
          if (x + dx < width && y + dy < height) {
            final pixel = edges.getPixel(x + dx, y + dy);
            if (img.getLuminance(pixel) > 25) edgeCount++;
          }
        }
      }

      final edgeDensity = edgeCount / ((regionSize * regionSize) / 4);

      if (edgeDensity > maxEdgeDensity && edgeCount > threshold) {
        maxEdgeDensity = edgeDensity;
        bestRegion = {
          'left': x,
          'top': y,
          'right': (x + regionSize).clamp(0, width),
          'bottom': (y + regionSize).clamp(0, height),
        };
      }
    }
  }

  return bestRegion;
}
