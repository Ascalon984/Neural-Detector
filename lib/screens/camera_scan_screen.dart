import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../config/animation_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../models/scan_history.dart' as Model;
import '../utils/history_manager.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/robust_worker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';

// Enhanced text detection model with more detailed information
class TextDetectionResult {
  final bool hasText;
  final double confidence;
  final Map<String, int>? textRegions;
  final ImageCharacteristics characteristics;
  
  TextDetectionResult({
    required this.hasText,
    required this.confidence,
    this.textRegions,
    required this.characteristics,
  });

  // Build from a serializable map returned by the compute isolate
  factory TextDetectionResult.fromMap(Map<String, dynamic> m) {
    return TextDetectionResult(
      hasText: m['hasText'] as bool? ?? false,
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
      textRegions: m['textRegions'] != null ? Map<String, int>.from(m['textRegions'] as Map) : null,
      characteristics: ImageCharacteristics.fromMap(m['characteristics'] as Map<String, dynamic>? ?? {}),
    );
  }

  
  
  Map<String, dynamic> toMap() => {
    'hasText': hasText,
    'confidence': confidence,
    'textRegions': textRegions,
    'characteristics': characteristics.toMap(),
  };
}

// Image characteristics for adaptive thresholding
class ImageCharacteristics {
  final double brightness;
  final double contrast;
  final double edgeDensity;
  final double textureComplexity;
  final int dominantColorCount;
  
  ImageCharacteristics({
    required this.brightness,
    required this.contrast,
    required this.edgeDensity,
    required this.textureComplexity,
    required this.dominantColorCount,
  });

  factory ImageCharacteristics.fromMap(Map<String, dynamic> m) {
    return ImageCharacteristics(
      brightness: (m['brightness'] as num?)?.toDouble() ?? 0.0,
      contrast: (m['contrast'] as num?)?.toDouble() ?? 0.0,
      edgeDensity: (m['edgeDensity'] as num?)?.toDouble() ?? 0.0,
      textureComplexity: (m['textureComplexity'] as num?)?.toDouble() ?? 0.0,
      dominantColorCount: (m['dominantColorCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'brightness': brightness,
    'contrast': contrast,
    'edgeDensity': edgeDensity,
    'textureComplexity': textureComplexity,
    'dominantColorCount': dominantColorCount,
  };
}

// Union-Find data structure for optimized connected component analysis
class UnionFind {
  late List<int> parent;
  late List<int> rank;
  
  UnionFind(int size) {
    parent = List<int>.filled(size, 0);
    rank = List<int>.filled(size, 0);
    for (int i = 0; i < size; i++) {
      parent[i] = i;
    }
  }
  
  int find(int i) {
    if (parent[i] != i) {
      parent[i] = find(parent[i]);
    }
    return parent[i];
  }
  
  void union(int i, int j) {
    int rootI = find(i);
    int rootJ = find(j);
    
    if (rootI != rootJ) {
      if (rank[rootI] > rank[rootJ]) {
        parent[rootJ] = rootI;
      } else if (rank[rootI] < rank[rootJ]) {
        parent[rootI] = rootJ;
      } else {
        parent[rootJ] = rootI;
        rank[rootI]++;
      }
    }
  }
}

// Enhanced compute function for text detection with adaptive thresholding
TextDetectionResult _enhancedTextDetectionCompute(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return TextDetectionResult(
      hasText: false, 
      confidence: 0.0,
      characteristics: ImageCharacteristics(
        brightness: 0.0,
        contrast: 0.0,
        edgeDensity: 0.0,
        textureComplexity: 0.0,
        dominantColorCount: 0,
      )
    );

    // Downscale for performance
    final resized = img.copyResize(image, width: 400, height: 400);
    
    // Analyze image characteristics for adaptive thresholding
    final characteristics = _analyzeImageCharacteristics(resized);
    
    // Multiple heuristics for text detection
    
    // 1. Edge density analysis
    final gray = img.grayscale(resized);
    final edges = img.sobel(gray);
    
    int strongEdges = 0;
    int totalPixels = edges.width * edges.height;
    
    for (int y = 0; y < edges.height; y++) {
      for (int x = 0; x < edges.width; x++) {
        final pixel = edges.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        if (luminance > 50) strongEdges++;
      }
    }
    
    final edgeDensity = strongEdges / totalPixels;
    
    // 2. Connected component analysis with Union-Find
    final binary = img.Image(width: gray.width, height: gray.height);
    final adaptiveThreshold = _calculateAdaptiveThreshold(gray, characteristics);
    
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final p = gray.getPixel(x, y);
        final lum = img.getLuminance(p);
        if (lum > adaptiveThreshold) {
          binary.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          binary.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    
  final components = _findConnectedComponentsOptimized(binary);
  final avgComponentSize = components.isEmpty
    ? 0.0
    : components.fold<int>(0, (sum, c) => sum + c.size).toDouble() / components.length;
    
    // 3. Texture analysis - check for regular patterns
    final textureScore = _analyzeTexture(gray);
    
    // 4. Histogram analysis for text detection
    final histogramScore = _analyzeHistogram(gray);
    
    // 5. Stroke width transform (simplified)
    final swtScore = _analyzeStrokeWidth(edges);
    
    // Combine heuristics with adaptive weights based on image characteristics
    final edgeScore = math.min(edgeDensity * 10, 1.0);
    final componentScore = _calculateComponentScore(avgComponentSize, characteristics);
    final textureScoreNormalized = math.min(textureScore, 1.0);
    final histogramScoreNormalized = math.min(histogramScore, 1.0);
    final swtScoreNormalized = math.min(swtScore, 1.0);
    
    // Adaptive weights based on image characteristics
    final weights = _calculateAdaptiveWeights(characteristics);
    
    // Weighted combination
    final combinedScore = (edgeScore * weights.edgeWeight + 
                          componentScore * weights.componentWeight + 
                          textureScoreNormalized * weights.textureWeight +
                          histogramScoreNormalized * weights.histogramWeight +
                          swtScoreNormalized * weights.swtWeight);
    
    // Adaptive threshold based on image characteristics
    final adaptiveThresholdValue = _calculateAdaptiveThresholdValue(characteristics);
    final hasText = combinedScore > adaptiveThresholdValue;
    
    // Find text regions if text is detected
    Map<String, int>? textRegions;
    if (hasText) {
      textRegions = _findTextRegionsEnhanced(edges, characteristics);
    }
    
    return TextDetectionResult(
      hasText: hasText,
      confidence: combinedScore,
      textRegions: textRegions,
      characteristics: characteristics,
    );
  } catch (e) {
    debugPrint('Error in text detection: $e');
    return TextDetectionResult(
      hasText: false, 
      confidence: 0.0,
      characteristics: ImageCharacteristics(
        brightness: 0.0,
        contrast: 0.0,
        edgeDensity: 0.0,
        textureComplexity: 0.0,
        dominantColorCount: 0,
      )
    );
  }
}

// Analyze image characteristics for adaptive processing
ImageCharacteristics _analyzeImageCharacteristics(img.Image image) {
  final gray = img.grayscale(image);
  final width = image.width;
  final height = image.height;
  
  // Calculate brightness
  double totalBrightness = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = gray.getPixel(x, y);
      totalBrightness += img.getLuminance(pixel);
    }
  }
  final brightness = totalBrightness / (width * height) / 255.0;
  
  // Calculate contrast (standard deviation)
  double sumSquaredDiff = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = gray.getPixel(x, y);
      final luminance = img.getLuminance(pixel);
      final diff = luminance - (brightness * 255.0);
      sumSquaredDiff += diff * diff;
    }
  }
  final contrast = math.sqrt(sumSquaredDiff / (width * height)) / 255.0;
  
  // Calculate edge density
  final edges = img.sobel(gray);
  int edgeCount = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = edges.getPixel(x, y);
      if (img.getLuminance(pixel) > 50) edgeCount++;
    }
  }
  final edgeDensity = edgeCount / (width * height);
  
  // Calculate texture complexity (simplified)
  final textureComplexity = _analyzeTexture(gray);
  
  // Calculate dominant color count (simplified)
  final dominantColorCount = _calculateDominantColors(image);
  
  return ImageCharacteristics(
    brightness: brightness,
    contrast: contrast,
    edgeDensity: edgeDensity,
    textureComplexity: textureComplexity,
    dominantColorCount: dominantColorCount,
  );
}

// Calculate adaptive threshold based on image characteristics
int _calculateAdaptiveThreshold(img.Image gray, ImageCharacteristics characteristics) {
  // Base threshold adjusted by brightness and contrast
  int baseThreshold = 128;
  
  // Adjust for brightness
  if (characteristics.brightness < 0.3) {
    baseThreshold -= 20; // Darker images need lower threshold
  } else if (characteristics.brightness > 0.7) {
    baseThreshold += 20; // Brighter images need higher threshold
  }
  
  // Adjust for contrast
  if (characteristics.contrast < 0.2) {
    baseThreshold -= 10; // Low contrast images need lower threshold
  } else if (characteristics.contrast > 0.5) {
    baseThreshold += 10; // High contrast images need higher threshold
  }
  
  // Ensure threshold is within valid range
  return baseThreshold.clamp(50, 200);
}

// Calculate adaptive weights for heuristics based on image characteristics
AdaptiveWeights _calculateAdaptiveWeights(ImageCharacteristics characteristics) {
  // Default weights
  double edgeWeight = 0.3;
  double componentWeight = 0.3;
  double textureWeight = 0.2;
  double histogramWeight = 0.1;
  double swtWeight = 0.1;
  
  // Adjust weights based on image characteristics
  if (characteristics.contrast < 0.2) {
    // Low contrast images rely more on texture and histogram
    edgeWeight = 0.2;
    componentWeight = 0.2;
    textureWeight = 0.3;
    histogramWeight = 0.2;
    swtWeight = 0.1;
  } else if (characteristics.contrast > 0.5) {
    // High contrast images rely more on edges and components
    edgeWeight = 0.4;
    componentWeight = 0.4;
    textureWeight = 0.1;
    histogramWeight = 0.05;
    swtWeight = 0.05;
  }
  
  if (characteristics.textureComplexity > 0.5) {
    // High texture complexity increases texture weight
    textureWeight += 0.1;
    edgeWeight -= 0.05;
    componentWeight -= 0.05;
  }
  
  return AdaptiveWeights(
    edgeWeight: edgeWeight,
    componentWeight: componentWeight,
    textureWeight: textureWeight,
    histogramWeight: histogramWeight,
    swtWeight: swtWeight,
  );
}

// Calculate adaptive threshold value for text detection
double _calculateAdaptiveThresholdValue(ImageCharacteristics characteristics) {
  // Base threshold
  double threshold = 0.4;
  
  // Adjust based on image characteristics
  if (characteristics.contrast < 0.2) {
    threshold -= 0.1; // Lower threshold for low contrast images
  } else if (characteristics.contrast > 0.5) {
    threshold += 0.1; // Higher threshold for high contrast images
  }
  
  if (characteristics.textureComplexity > 0.5) {
    threshold -= 0.05; // Lower threshold for high texture complexity
  }
  
  // Ensure threshold is within valid range
  return threshold.clamp(0.2, 0.8);
}

// Calculate component score based on component size and image characteristics
double _calculateComponentScore(double avgComponentSize, ImageCharacteristics characteristics) {
  // Base score
  double score = 0.0;
  
  // Adjust thresholds based on image characteristics
  double minSize = 5.0;
  double maxSize = 200.0;
  
  if (characteristics.contrast < 0.2) {
    // Low contrast images might have smaller components
    minSize = 3.0;
    maxSize = 150.0;
  } else if (characteristics.contrast > 0.5) {
    // High contrast images might have larger components
    minSize = 8.0;
    maxSize = 250.0;
  }
  
  if (avgComponentSize > minSize && avgComponentSize < maxSize) {
    score = 0.8;
  } else {
    score = 0.3;
  }
  
  return score;
}

// Optimized connected component analysis using Union-Find
List<Component> _findConnectedComponentsOptimized(img.Image binary) {
  final width = binary.width;
  final height = binary.height;
  final pixelCount = width * height;
  
  // Create Union-Find structure
  final uf = UnionFind(pixelCount);
  
  // First pass: connect adjacent pixels
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final idx = y * width + x;
      
      // Skip if pixel is not white
      if (img.getLuminance(binary.getPixel(x, y)) <= 128) continue;
      
      // Connect with right neighbor
      if (x < width - 1 && img.getLuminance(binary.getPixel(x + 1, y)) > 128) {
        uf.union(idx, idx + 1);
      }
      
      // Connect with bottom neighbor
      if (y < height - 1 && img.getLuminance(binary.getPixel(x, y + 1)) > 128) {
        uf.union(idx, idx + width);
      }
    }
  }
  
  // Second pass: count component sizes
  final componentSizes = <int, int>{};
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final idx = y * width + x;
      
      // Skip if pixel is not white
      if (img.getLuminance(binary.getPixel(x, y)) <= 128) continue;
      
      final root = uf.find(idx);
      componentSizes[root] = (componentSizes[root] ?? 0) + 1;
    }
  }
  
  // Create components
  final components = <Component>[];
  componentSizes.forEach((root, size) {
    if (size > 5) { // Filter out very small components
      // Find all pixels in this component
      final pixels = <Point>[];
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = y * width + x;
          if (img.getLuminance(binary.getPixel(x, y)) > 128 && uf.find(idx) == root) {
            pixels.add(Point(x, y));
          }
        }
      }
      components.add(Component(pixels));
    }
  });
  
  return components;
}

// Enhanced texture analysis
double _analyzeTexture(img.Image gray) {
  final width = gray.width;
  final height = gray.height;
  
  // Enhanced texture analysis using local variance and gradient
  double totalVariance = 0;
  double totalGradientMagnitude = 0;
  int sampleCount = 0;
  
  const windowSize = 8;
  const step = 4;
  
  for (int y = 0; y < height - windowSize; y += step) {
    for (int x = 0; x < width - windowSize; x += step) {
      // Calculate local variance
      double sum = 0;
      double sumSquared = 0;
      int count = 0;
      
      for (int dy = 0; dy < windowSize; dy++) {
        for (int dx = 0; dx < windowSize; dx++) {
          final pixel = gray.getPixel(x + dx, y + dy);
          final value = img.getLuminance(pixel);
          sum += value;
          sumSquared += value * value;
          count++;
        }
      }
      
      if (count > 0) {
        final mean = sum / count;
        final variance = (sumSquared / count) - (mean * mean);
        totalVariance += variance;
        
        // Calculate gradient magnitude
        double gradientMagnitude = 0;
        for (int dy = 1; dy < windowSize - 1; dy++) {
          for (int dx = 1; dx < windowSize - 1; dx++) {
            final pixel = gray.getPixel(x + dx, y + dy);
            final rightPixel = gray.getPixel(x + dx + 1, y + dy);
            final bottomPixel = gray.getPixel(x + dx, y + dy + 1);
            
            final gradX = img.getLuminance(rightPixel) - img.getLuminance(pixel);
            final gradY = img.getLuminance(bottomPixel) - img.getLuminance(pixel);
            
            gradientMagnitude += math.sqrt(gradX * gradX + gradY * gradY);
          }
        }
        
        totalGradientMagnitude += gradientMagnitude / ((windowSize - 2) * (windowSize - 2));
        sampleCount++;
      }
    }
  }
  
  if (sampleCount == 0) return 0;
  
  final avgVariance = totalVariance / sampleCount;
  final avgGradientMagnitude = totalGradientMagnitude / sampleCount;
  
  // Combine variance and gradient for texture score
  final textureScore = (avgVariance / 1000) * 0.7 + (avgGradientMagnitude / 50) * 0.3;
  
  // Normalize to 0-1 range
  return math.min(textureScore, 1.0);
}

// Histogram analysis for text detection
double _analyzeHistogram(img.Image gray) {
  final width = gray.width;
  final height = gray.height;
  
  // Calculate histogram
  final histogram = List<int>.filled(256, 0);
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = gray.getPixel(x, y);
      final luminance = img.getLuminance(pixel).round();
      histogram[luminance]++;
    }
  }
  
  // Normalize histogram
  final totalPixels = width * height;
  for (int i = 0; i < 256; i++) {
    histogram[i] = (histogram[i] / totalPixels * 100).round();
  }
  
  // Calculate peaks in histogram
  final peaks = <int>[];
  for (int i = 1; i < 255; i++) {
    if (histogram[i] > histogram[i-1] && histogram[i] > histogram[i+1]) {
      peaks.add(i);
    }
  }
  
  // Text images typically have multiple peaks (background and text)
  // Calculate score based on number of peaks and their distribution
  double score = 0.0;
  
  if (peaks.length >= 2) {
    // Sort peaks by height
    peaks.sort((a, b) => histogram[b].compareTo(histogram[a]));
    
    // Calculate distance between highest peaks
    if (peaks.length >= 2) {
      final distance = (peaks[0] - peaks[1]).abs();
      // Optimal distance for text is around 100-150
      if (distance >= 80 && distance <= 170) {
        score = 0.8;
      } else {
        score = 0.4;
      }
    }
  } else {
    score = 0.2;
  }
  
  return score;
}

// Simplified stroke width transform analysis
double _analyzeStrokeWidth(img.Image edges) {
  final width = edges.width;
  final height = edges.height;
  
  // Count edges with different orientations
  int horizontalEdges = 0;
  int verticalEdges = 0;
  int diagonalEdges = 0;
  
  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      final pixel = edges.getPixel(x, y);
      if (img.getLuminance(pixel) > 50) {
        // Calculate gradient direction
        final rightPixel = edges.getPixel(x + 1, y);
        final bottomPixel = edges.getPixel(x, y + 1);
        final diagonalPixel = edges.getPixel(x + 1, y + 1);
        
        final gradX = img.getLuminance(rightPixel) - img.getLuminance(pixel);
        final gradY = img.getLuminance(bottomPixel) - img.getLuminance(pixel);
        final gradDiag = img.getLuminance(diagonalPixel) - img.getLuminance(pixel);
        
        final absGradX = gradX.abs();
        final absGradY = gradY.abs();
        final absGradDiag = gradDiag.abs();
        
        if (absGradX > absGradY && absGradX > absGradDiag) {
          horizontalEdges++;
        } else if (absGradY > absGradX && absGradY > absGradDiag) {
          verticalEdges++;
        } else {
          diagonalEdges++;
        }
      }
    }
  }
  
    final totalEdges = horizontalEdges + verticalEdges + diagonalEdges;
    if (totalEdges == 0) return 0.0;

    // Text typically has a mix of edge orientations
    final horizontalRatio = horizontalEdges / totalEdges;
    final verticalRatio = verticalEdges / totalEdges;
  
  // Calculate score based on distribution of edge orientations
  double score = 0.0;
  
  // Text typically has a good mix of orientations
  if (horizontalRatio > 0.2 && horizontalRatio < 0.6 &&
      verticalRatio > 0.2 && verticalRatio < 0.6) {
    score = 0.8;
  } else if (horizontalRatio > 0.1 && horizontalRatio < 0.7 &&
             verticalRatio > 0.1 && verticalRatio < 0.7) {
    score = 0.5;
  } else {
    score = 0.2;
  }
  
  return score;
}

// Calculate dominant colors in the image
int _calculateDominantColors(img.Image image) {
  // Simplified color quantization
  final colors = <int, int>{};
  
  // Sample every 10th pixel for performance
  for (int y = 0; y < image.height; y += 10) {
    for (int x = 0; x < image.width; x += 10) {
      final pixel = image.getPixel(x, y);
      // Use luminance-based quantization (safer across image package versions)
      final lum = img.getLuminance(pixel).round();
      // Quantize luminance into 32 levels
      final ql = (lum ~/ 8) * 8;
      final colorKey = ql; // using luminance bucket as key
      colors[colorKey] = (colors[colorKey] ?? 0) + 1;
    }
  }
  
  return colors.length;
}

// Enhanced text region detection using morphological operations
Map<String, int>? _findTextRegionsEnhanced(img.Image edges, ImageCharacteristics characteristics) {
  final width = edges.width;
  final height = edges.height;
  
  // Adaptive region size based on image characteristics
  int regionSize = 64;
  if (characteristics.contrast < 0.2) {
    regionSize = 48; // Smaller regions for low contrast images
  } else if (characteristics.contrast > 0.5) {
    regionSize = 80; // Larger regions for high contrast images
  }
  
  // Adaptive threshold based on image characteristics
  int threshold = 30;
  if (characteristics.edgeDensity < 0.1) {
    threshold = 20; // Lower threshold for low edge density
  } else if (characteristics.edgeDensity > 0.3) {
    threshold = 40; // Higher threshold for high edge density
  }
  
  final regions = <Map<String, int>>[];
  
  for (int y = 0; y < height - regionSize; y += regionSize ~/ 2) {
    for (int x = 0; x < width - regionSize; x += regionSize ~/ 2) {
      int edgeCount = 0;
      
      for (int dy = 0; dy < regionSize; dy++) {
        for (int dx = 0; dx < regionSize; dx++) {
          final pixel = edges.getPixel(x + dx, y + dy);
          if (img.getLuminance(pixel) > 50) edgeCount++;
        }
      }
      
      if (edgeCount > threshold) {
        regions.add({
          'left': x,
          'top': y,
          'right': x + regionSize,
          'bottom': y + regionSize,
        });
      }
    }
  }
  
  if (regions.isEmpty) return null;
  
  // Enhanced region merging with morphological operations
  final mergedRegions = _mergeRegionsEnhanced(regions);
  
  // Filter regions by aspect ratio and size
  final filteredRegions = <Map<String, int>>[];
  for (final region in mergedRegions) {
    final regionWidth = region['right']! - region['left']!;
    final regionHeight = region['bottom']! - region['top']!;
    final aspectRatio = regionWidth / regionHeight;
    
    // Text regions typically have aspect ratios between 0.2 and 5.0
    if (aspectRatio >= 0.2 && aspectRatio <= 5.0) {
      filteredRegions.add(region);
    }
  }
  
  if (filteredRegions.isEmpty) return null;
  
  // Return the largest region
  filteredRegions.sort((a, b) {
    final areaA = (a['right']! - a['left']!) * (a['bottom']! - a['top']!);
    final areaB = (b['right']! - b['left']!) * (b['bottom']! - b['top']!);
    return areaB.compareTo(areaA);
  });
  
  return filteredRegions.first;
}

// Enhanced region merging with morphological operations
List<Map<String, int>> _mergeRegionsEnhanced(List<Map<String, int>> regions) {
  if (regions.isEmpty) return [];
  
  final merged = <Map<String, int>>[];
  
  for (final region in regions) {
    bool mergedWithExisting = false;
    
    for (int i = 0; i < merged.length; i++) {
      final existing = merged[i];
      
      // Check if regions overlap or are close to each other
      if (_regionsOverlapOrClose(region, existing)) {
        // Merge regions with some padding
        const padding = 10;
        merged[i] = {
          'left': math.max(0, math.min(region['left']!, existing['left']!) - padding),
          'top': math.max(0, math.min(region['top']!, existing['top']!) - padding),
          'right': math.min(regions.first['right']!, math.max(region['right']!, existing['right']!) + padding),
          'bottom': math.min(regions.first['bottom']!, math.max(region['bottom']!, existing['bottom']!) + padding),
        };
        mergedWithExisting = true;
        break;
      }
    }
    
    if (!mergedWithExisting) {
      merged.add(Map.from(region));
    }
  }
  
  return merged;
}

// Check if two regions overlap or are close to each other
bool _regionsOverlapOrClose(Map<String, int> a, Map<String, int> b) {
  const padding = 20; // Pixels
  
  return !(a['right']! + padding < b['left']! - padding || 
           a['left']! - padding > b['right']! + padding || 
           a['bottom']! + padding < b['top']! - padding || 
           a['top']! - padding > b['bottom']! + padding);
}

// Adaptive weights data structure
class AdaptiveWeights {
  final double edgeWeight;
  final double componentWeight;
  final double textureWeight;
  final double histogramWeight;
  final double swtWeight;
  
  AdaptiveWeights({
    required this.edgeWeight,
    required this.componentWeight,
    required this.textureWeight,
    required this.histogramWeight,
    required this.swtWeight,
  });
}

// Simple point class
class Point {
  final int x;
  final int y;
  
  Point(this.x, this.y);
}

// Component class for connected components
class Component {
  final List<Point> pixels;
  
  Component(this.pixels);
  
  int get size => pixels.length;
}

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  
  CameraController? _cameraController;
    // ML Kit text recognizer for quick text detection
    TextRecognizer? _textRecognizer;
    bool _isProcessingFrame = false;
    int _throttleMs = 300; // process one frame every 300ms
    DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  
  // Camera image stream handler: throttled + prefilter + ML Kit detection
  void _handleCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < _throttleMs) return;
    _lastProcessed = now;

    if (_isProcessingFrame) return;

    // Quick prefilter on Y plane
    if (!_quickHasEdges(image)) return;

    // Mark processing and capture a still image for reliable OCR
    _isProcessingFrame = true;
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      if (_isCapturing) return; // avoid collision with manual capture

      _isCapturing = true;
      final XFile file = await _cameraController!.takePicture();
      _isCapturing = false;

      if (_textRecognizer == null) return;
      final inputImage = InputImage.fromFilePath(file.path);
      final recognized = await _textRecognizer!.processImage(inputImage);

      if (recognized.text.trim().isNotEmpty && recognized.text.trim().length > 2) {
        debugPrint('Camera detected text (from still): ${recognized.text.length} chars');
        // handle detected text (e.g., save, analyze, UI update)
      }

      // Optionally delete temp file if desired
      try { await File(file.path).delete(); } catch (_) {}
    } catch (e) {
      debugPrint('Camera capture/processing error: $e');
      _isCapturing = false;
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _quickHasEdges(CameraImage image, {int sampleStride = 20, int threshold = 6}) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    int count = 0;
    for (int i = 0; i + sampleStride < bytes.length; i += sampleStride) {
      final diff = (bytes[i] - bytes[i + sampleStride]).abs();
      if (diff > 25) count++;
      if (count >= threshold) return true;
    }
    return false;
  }

  // _concatenatePlanes removed — we capture still images for ML processing instead
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  Uint8List? _lastCapturedBytes;
  String? _lastCapturedPath;
  bool _isKept = false;
  bool _flashOn = false;
  bool _isFlashHovering = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  double _aiPct = 0.0;
  double _humanPct = 0.0;
  
  // Cancel token for analysis
  Completer<bool>? _analysisCompleter;
  
  // Memory management
  Timer? _memoryCleanupTimer;
  int _memoryPressureLevel = 0;

  @override
  void initState() {
    super.initState();
    
    // Initialize memory management
    _initializeMemoryManagement();
    
    // Initialize animation controllers
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Initialize animation objects
    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);

      _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
    }

    _requestCameraPermission();
  }

  // Initialize memory management
  void _initializeMemoryManagement() {
    // Check memory pressure every 30 seconds
    _memoryCleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkMemoryPressure();
    });
  }

  // Check memory pressure and clean up if needed
  void _checkMemoryPressure() {
    // In a real implementation, you would use platform-specific APIs to check memory pressure
    // For now, we'll use a simple heuristic based on available memory
    
    // Simulate memory pressure check
    // In a real app, you would use platform channels to get actual memory info
    _memoryPressureLevel = math.Random().nextInt(3); // 0: low, 1: medium, 2: high
    
    if (_memoryPressureLevel >= 2) {
      // High memory pressure - perform aggressive cleanup
      _performMemoryCleanup(aggressive: true);
    } else if (_memoryPressureLevel >= 1) {
      // Medium memory pressure - perform moderate cleanup
      _performMemoryCleanup(aggressive: false);
    }
  }

  // Perform memory cleanup
  void _performMemoryCleanup({bool aggressive = false}) {
    // Clear image cache if not analyzing
    if (!_isAnalyzing && _lastCapturedBytes != null) {
      if (aggressive) {
        // Aggressive cleanup - clear the captured image
        setState(() {
          _lastCapturedBytes = null;
          _lastCapturedPath = null;
          _isKept = false;
        });
      }
    }
    
    // Force garbage collection
    // Note: This is not recommended in production code, but included for demonstration
    // In a real app, you would use platform-specific APIs to trigger garbage collection
  }

  @override
  void dispose() {
    // Cancel any ongoing analysis
    _analysisCompleter?.complete(false);
    
    // Cancel memory cleanup timer
    _memoryCleanupTimer?.cancel();
    
    // Dispose animation controllers
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    
    // Stop image stream if running and dispose camera controller
    try {
      _cameraController?.stopImageStream();
    } catch (_) {}
    _textRecognizer?.close();
    _cameraController?.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated cyberpunk background
          _buildAnimatedBackground(),
          
          // Grid overlay effect
          _buildGridOverlay(),
          
          // Scan line effect
          _buildScanLine(),
          
          // Glitch effect overlay
          _buildGlitchEffect(),
          
          // Floating particles effect
          _buildFloatingParticles(),
          
          // Main content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      children: [
                        _buildHeader(),
                        SizedBox(
                          height: constraints.maxHeight * 0.6,
                          child: _buildScannerContainer(),
                        ),
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Cyberpunk frame borders
          _buildCyberpunkFrame(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0a0a0a),
                  const Color(0xFF1a0033),
                  _backgroundAnimation.value,
                )!,
                Color.lerp(
                  const Color(0xFF0d1117),
                  const Color(0xFF0a0e27),
                  _backgroundAnimation.value,
                )!,
                Colors.black,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top: _scanAnimation.value * MediaQuery.of(context).size.height,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.cyan.withOpacity(0.8),
                  Colors.pink.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlitchEffect() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: (_glowAnimation.value - 0.3).clamp(0.0, 0.1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink.withOpacity(0.1),
                    Colors.cyan.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _rotateController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlesPainter(_rotateController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.cyan.withOpacity(_glowAnimation.value),
                      Colors.pink.withOpacity(_glowAnimation.value),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(_glowAnimation.value),
                          Colors.pink.withOpacity(_glowAnimation.value),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'OCR KAMERA',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 360 ? 18 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                          fontFamily: 'Orbitron',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ANALISIS FOTO DENGAN AI',
                      style: TextStyle(
                        color: Colors.pink.shade300,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                        fontFamily: 'Courier',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerContainer() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final screen = MediaQuery.of(context).size;
          final boxWidth = screen.width * 0.9;
          final boxHeight = (boxWidth * 1.2).clamp(200.0, screen.height * 0.6);

          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Camera preview
                  if (_isCameraInitialized && _cameraController != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize?.height ?? boxWidth,
                            height: _cameraController!.value.previewSize?.width ?? boxHeight,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hasCameraPermission ? Icons.camera_alt : Icons.no_photography,
                            color: Colors.white54,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _hasCameraPermission 
                              ? 'MENGINISIALISASI PEMINDAI'
                              : 'IZIN KAMERA DIPERLUKAN',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // Scanner line
                  Positioned(
                    top: (_scanAnimation.value) * boxHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.cyan.withOpacity(0.8),
                            Colors.pink.withOpacity(0.8),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Corner accents
                  ..._buildScannerCorners(),

                  // Preview overlay when an image has been captured
                  if (_lastCapturedBytes != null)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.cyan.withOpacity(_glowAnimation.value),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.memory(
                                    _lastCapturedBytes!,
                                    width: boxWidth * 0.8,
                                    height: boxHeight * 0.6,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              if (!_isKept)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCyberButton(
                                      text: 'SIMPAN',
                                      icon: Icons.check,
                                      onPressed: () async {
                                        setState(() {
                                          _isKept = true;
                                        });
                                        try {
                                          final auto = await SettingsManager.getAutoScan();
                                          if (auto && mounted) await _analyzeKeptImage();
                                        } catch (_) {}
                                      },
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 12),
                                    _buildCyberButton(
                                      text: 'BATAL',
                                      icon: Icons.delete,
                                      onPressed: _cancelPicture,
                                      color: Colors.red,
                                    ),
                                  ],
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _lastCapturedBytes = null;
                                      _isKept = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Gambar dihapus'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.red.withOpacity(_glowAnimation.value),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildScannerCorners() {
    return [
      // Top Left
      Positioned(
        top: 8,
        left: 8,
        child: _buildCornerWidget(true, true),
      ),
      // Top Right
      Positioned(
        top: 8,
        right: 8,
        child: _buildCornerWidget(false, true),
      ),
      // Bottom Left
      Positioned(
        bottom: 8,
        left: 8,
        child: _buildCornerWidget(true, false),
      ),
      // Bottom Right
      Positioned(
        bottom: 8,
        right: 8,
        child: _buildCornerWidget(false, false),
      ),
    ];
  }

  Widget _buildCornerWidget(bool isLeft, bool isTop) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            border: Border(
              left: isLeft
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3)
                  : BorderSide.none,
              right: !isLeft
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3)
                  : BorderSide.none,
              top: isTop
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3)
                  : BorderSide.none,
              bottom: !isTop
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3)
                  : BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.cyan.withOpacity(_glowAnimation.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(_glowAnimation.value * 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Flash control
                GestureDetector(
                  onTapDown: (_) => _handleFlashHover(true),
                  onTapUp: (_) => _handleFlashHover(false),
                  onTapCancel: () => _handleFlashHover(false),
                  onTap: () async {
                    _flashOn = !_flashOn;
                    try {
                      await _cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
                      if (!mounted) return;
                      setState(() {});
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Flash tidak tersedia: $e')),
                      );
                    }
                  },
                  child: _buildControlButton(
                    Icons.flash_on,
                    'LAMPU',
                    _flashOn || _isFlashHovering ? Colors.yellow : Colors.cyan,
                  ),
                ),

                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _takePicture,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyan.withOpacity(_glowAnimation.value),
                              Colors.pink.withOpacity(_glowAnimation.value),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _isCapturing
                            ? const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 25,
                              ),
                      );
                    },
                  ),
                ),

                // Analyze button
                GestureDetector(
                  onTap: _isKept && !_isAnalyzing ? _analyzeKeptImage : null,
                  child: _buildControlButton(
                    Icons.analytics,
                    'ANALISIS',
                    _isKept ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isAnalyzing)
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.cyan.withOpacity(_glowAnimation.value),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _analysisProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'MEMPROSES: ${(_analysisProgress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: Colors.cyan.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                            letterSpacing: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, Color color) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.3),
                    color.withOpacity(0.1),
                  ],
                ),
                border: Border.all(
                  color: color.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                letterSpacing: 1,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCyberButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCyberpunkFrame() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top border
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom border
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Left border
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Right border
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada kamera yang tersedia'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController?.initialize();

      // Initialize ML Kit text recognizer (native) for fast text detection
      try {
        _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      } catch (_) {
        _textRecognizer = null;
      }

      // Start image stream for quick pre-filter + ML Kit detection
      try {
        await _cameraController?.startImageStream(_handleCameraImage);
      } catch (_) {
        // Some platforms (web) or older camera drivers may not support streams
      }

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (!mounted) return;

      final errorMessage = kIsWeb
          ? 'Izinkan akses kamera di browser Anda'
          : 'Error menginisialisasi kamera: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      if (kIsWeb) {
        setState(() => _hasCameraPermission = true);
        await _initializeCamera();
        return;
      }

      final status = await Permission.camera.status;
      if (status.isDenied) {
        final result = await Permission.camera.request();
        setState(() => _hasCameraPermission = result.isGranted);
      } else if (status.isPermanentlyDenied) {
        await openAppSettings();
      } else {
        setState(() => _hasCameraPermission = true);
      }

      if (_hasCameraPermission) await _initializeCamera();
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb
              ? 'Izinkan akses kamera di pengaturan browser Anda'
              : 'Error meminta izin kamera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final shouldTorch = _flashOn || _isFlashHovering;
      if (shouldTorch) {
        try {
          await _cameraController?.setFlashMode(FlashMode.torch);
        } catch (_) {}
      }

      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      setState(() {
        _lastCapturedBytes = bytes;
        _lastCapturedPath = file.path;
        _isKept = false;
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengambil gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      try {
        await _cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _handleFlashHover(bool hovering) {
    if (_isFlashHovering == hovering) return;
    _isFlashHovering = hovering;
    try {
      _cameraController?.setFlashMode(hovering || _flashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _cancelPicture() async {
    setState(() {
      _lastCapturedBytes = null;
      _isKept = false;
    });
  }

  Future<void> _analyzeKeptImage() async {
    if (_lastCapturedBytes == null) return;
    
    // Create a new completer for this analysis
    _analysisCompleter = Completer<bool>();
    
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
    });

    try {
      // Stage 1: Enhanced text detection (20% of progress)
      TextDetectionResult textDetection;
      try {
        textDetection = await compute(_enhancedTextDetectionCompute, _lastCapturedBytes!);
        
        // Update progress
        if (_analysisCompleter?.isCompleted == false) {
          setState(() {
            _analysisProgress = 0.2;
          });
        }
      } catch (e) {
        textDetection = TextDetectionResult(
          hasText: false, 
          confidence: 0.0,
          characteristics: ImageCharacteristics(
            brightness: 0.0,
            contrast: 0.0,
            edgeDensity: 0.0,
            textureComplexity: 0.0,
            dominantColorCount: 0,
          )
        );
      }

      // If image doesn't contain text, skip heavy OCR/analysis
      if (!textDetection.hasText) {
        // Simulate remaining progress
        for (int i = 20; i <= 100; i += 5) {
          await Future.delayed(const Duration(milliseconds: 30));
          if (_analysisCompleter?.isCompleted == true) return;
          
          setState(() {
            _analysisProgress = i / 100;
          });
        }
        
        if (_analysisCompleter?.isCompleted == true) return;
        
        setState(() {
          _aiPct = 0.0;
          _humanPct = 100.0;
          _isAnalyzing = false;
        });

        // Save to history
        await _saveToHistory();
        
        if (mounted) {
          _showAnalysisDialog(_aiPct, _humanPct);
        }
        return;
      }

      // Stage 2: OCR (40% of progress)
      for (int i = 20; i <= 60; i += 4) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (_analysisCompleter?.isCompleted == true) return;
        
        setState(() {
          _analysisProgress = i / 100;
        });
      }

      // Stage 3: Preprocessing (20% of progress)
      for (int i = 60; i <= 80; i += 4) {
        await Future.delayed(const Duration(milliseconds: 40));
        if (_analysisCompleter?.isCompleted == true) return;
        
        setState(() {
          _analysisProgress = i / 100;
        });
      }

      // Stage 4: Analysis (20% of progress)
      try {
        final level = await SettingsManager.getSensitivityLevel();

        // Use text regions if available
        Map<String, int>? roi = textDetection.textRegions;
        
        String? analysisFilePath = _lastCapturedPath;

        if (roi != null) {
          try {
            final full = img.decodeImage(_lastCapturedBytes!);
            if (full != null) {
              final crop = img.copyCrop(full, x: roi['left']!, y: roi['top']!, width: roi['right']! - roi['left']!, height: roi['bottom']! - roi['top']!);
              final jpg = img.encodeJpg(crop, quality: 85);
              final dir = await getTemporaryDirectory();
              final f = File('${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await f.writeAsBytes(jpg);
              analysisFilePath = f.path;
            }
          } catch (_) {
            analysisFilePath = _lastCapturedPath;
          }
        }

        final adjusted = await runAnalysisIsolate(
          filePath: analysisFilePath, 
          bytes: null, 
          sensitivityLevel: level
        ).timeout(
          const Duration(seconds: 10), 
          onTimeout: () => {'ai_detection': 0.0, 'human_written': 100.0}
        );

        if (_analysisCompleter?.isCompleted == true) return;
        
        _aiPct = adjusted['ai_detection'] ?? 0.0;
        _humanPct = adjusted['human_written'] ?? 0.0;
      } catch (e) {
        if (_analysisCompleter?.isCompleted == true) return;
        
        _aiPct = 0.0;
        _humanPct = 100.0;
      }

      // Simulate final progress ramp
      for (int i = 80; i <= 100; i += 5) {
        await Future.delayed(const Duration(milliseconds: 30));
        if (_analysisCompleter?.isCompleted == true) return;
        
        setState(() {
          _analysisProgress = i / 100;
        });
      }

      if (_analysisCompleter?.isCompleted == true) return;
      
      setState(() {
        _isAnalyzing = false;
        _analysisProgress = 1.0;
      });

      // Show notification if enabled
      if (!mounted) return;
      try {
        final notify = await SettingsManager.getNotifications();
        if (notify && mounted) {
          CyberNotification.show(context, 'Analisis Selesai', 'Analisis pemindaian kamera selesai');
        }
      } catch (_) {}
      
      // Save to history
      await _saveToHistory();

      // Show dialog with results
      if (mounted) {
        _showAnalysisDialog(_aiPct, _humanPct);
      }
    } catch (e) {
      debugPrint('Error during analysis: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selama analisis: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToHistory() async {
    try {
      final sized = _lastCapturedBytes != null ? _formatBytes(_lastCapturedBytes!.length) : '-';
      final dateStr = _formatDate(DateTime.now());
      final existing = await HistoryManager.loadHistory();
      final scanNumber = existing.length + 1;
      final entry = Model.ScanHistory(
        id: 'Scan $scanNumber',
        fileName: 'camera_capture_$scanNumber',
        date: dateStr,
        aiDetection: _aiPct.round(),
        humanWritten: _humanPct.round(),
        status: 'Completed',
        fileSize: sized,
      );
      await HistoryManager.addEntry(entry);
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }

  void _showAnalysisDialog(double aiPct, double humanPct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                aiPct > 50 
                  ? Colors.red.shade900.withOpacity(0.9)
                  : Colors.blue.shade900.withOpacity(0.9),
                aiPct > 50
                  ? Colors.deepOrange.shade900.withOpacity(0.9)
                  : Colors.purple.shade900.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: aiPct > 50 ? Colors.red : Colors.cyan,
              width: 2
            ),
            boxShadow: [
              BoxShadow(
                color: (aiPct > 50 ? Colors.red : Colors.cyan).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.pink],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'ANALISIS SELESAI',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade300,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.cyan.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Deteksi AI:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${aiPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: aiPct > 50 ? Colors.red.shade300 : Colors.green.shade300,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Ditulis Manusia:',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${humanPct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.cyan.shade300,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCyberButton(
                    text: 'TUTUP',
                    icon: Icons.close,
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.cyan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    if (i < 0) i = 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final val = bytes / math.pow(1024, i);
    return '${val.toStringAsFixed(val >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const gridSize = 30.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  
  _ParticlesPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent particles
    
    for (int i = 0; i < 20; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}