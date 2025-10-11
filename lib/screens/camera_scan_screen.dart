import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import '../config/animation_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute, kDebugMode;
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

// Preprocess JPEG bytes in an isolate: decode, resize to max 800px, apply light contrast.
Uint8List _preprocessImageBytesCompute(Uint8List bytes) {
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

    // Light contrast enhancement
    final enhanced = img.adjustColor(resized, contrast: 1.05, saturation: 1.0);

    final out = img.encodeJpg(enhanced, quality: 75);
    return Uint8List.fromList(out);
  } catch (e) {
    return bytes;
  }
}

// Simplified text detection result for memory efficiency
class TextDetectionResult {
  final bool hasText;
  final double confidence;
  final Map<String, int>? textRegions;

  TextDetectionResult({
    required this.hasText,
    required this.confidence,
    this.textRegions,
  });

  factory TextDetectionResult.fromMap(Map<String, dynamic> m) {
    return TextDetectionResult(
      hasText: m['hasText'] as bool? ?? false,
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
      textRegions: m['textRegions'] != null ? Map<String, int>.from(m['textRegions'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'hasText': hasText,
    'confidence': confidence,
    'textRegions': textRegions,
  };
}

// Optimized compute function for text detection with memory constraints
TextDetectionResult _optimizedTextDetectionCompute(Uint8List bytes) {
  try {
    // Use smaller image for processing to reduce memory usage
    final image = img.decodeImage(bytes);
    if (image == null) return TextDetectionResult(hasText: false, confidence: 0.0);

    // Downscale significantly for performance - target 300x300 max
    final targetSize = 300;
    final width = image.width;
    final height = image.height;

    // Calculate aspect ratio preserving dimensions
    int newWidth, newHeight;
    if (width > height) {
      newWidth = targetSize;
      newHeight = (height * targetSize / width).round();
    } else {
      newHeight = targetSize;
      newWidth = (width * targetSize / height).round();
    }

    final resized = img.copyResize(image, width: newWidth, height: newHeight);

    // Convert to grayscale for edge detection
    final gray = img.grayscale(resized);

    // Apply adaptive threshold for better text detection
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

    // Edge detection with Sobel operator
    final edges = img.sobel(gray);

    // Count edges to determine text presence
    int edgeCount = 0;
    const edgeThreshold = 30; // Lower threshold for better sensitivity
    const minEdgeRatio = 0.02; // Minimum edge ratio for text detection

    for (int y = 0; y < edges.height; y++) {
      for (int x = 0; x < edges.width; x++) {
        final pixel = edges.getPixel(x, y);
        if (img.getLuminance(pixel) > edgeThreshold) edgeCount++;
      }
    }

    final edgeRatio = edgeCount / (edges.width * edges.height);
    final hasText = edgeRatio > minEdgeRatio;

    // Calculate confidence based on edge density
    final confidence = math.min(edgeRatio * 20, 1.0);

    // Find text regions if text is detected
    Map<String, int>? textRegions;
    if (hasText) {
      textRegions = _findTextRegions(edges);
    }

    return TextDetectionResult(
      hasText: hasText,
      confidence: confidence,
      textRegions: textRegions,
    );
  } catch (e) {
    debugPrint('Error in text detection: $e');
    return TextDetectionResult(hasText: false, confidence: 0.0);
  }
}

// Calculate optimal threshold for binarization
int _calculateOptimalThreshold(img.Image gray) {
  // Calculate histogram
  final histogram = List<int>.filled(256, 0);
  for (int y = 0; y < gray.height; y++) {
    for (int x = 0; x < gray.width; x++) {
      final pixel = gray.getPixel(x, y);
      final luminance = img.getLuminance(pixel).round();
      histogram[luminance]++;
    }
  }

  // Otsu's method for automatic thresholding
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

// Find text regions in the image
Map<String, int>? _findTextRegions(img.Image edges) {
  final width = edges.width;
  final height = edges.height;

  // Simple region detection using sliding window
  const regionSize = 60;
  const threshold = 15;

  Map<String, int>? bestRegion;
  int maxEdgeCount = 0;

  for (int y = 0; y < height - regionSize; y += regionSize ~/ 2) {
    for (int x = 0; x < width - regionSize; x += regionSize ~/ 2) {
      int edgeCount = 0;

      for (int dy = 0; dy < regionSize; dy++) {
        for (int dx = 0; dx < regionSize; dx++) {
          final pixel = edges.getPixel(x + dx, y + dy);
          if (img.getLuminance(pixel) > 30) edgeCount++;
        }
      }

      if (edgeCount > threshold && edgeCount > maxEdgeCount) {
        maxEdgeCount = edgeCount;
        bestRegion = {
          'left': x,
          'top': y,
          'right': x + regionSize,
          'bottom': y + regionSize,
        };
      }
    }
  }

  return bestRegion;
}

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> with TickerProviderStateMixin {
  // ML Kit model warm-up helper
  Future<void> _warmUpMlKitModels() async {
    try {
      // Text Recognition warm-up
      final textRecognizer = TextRecognizer();
      // Gunakan gambar kosong/minimal untuk trigger download model
      final blankImage = InputImage.fromFilePath('assets/blank.jpg');
      await textRecognizer.processImage(blankImage);
      textRecognizer.close();

      // Object Detection warm-up
      final objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: false,
          multipleObjects: false,
        ),
      );
      await objectDetector.processImage(blankImage);
      objectDetector.close();
    } catch (e) {
      debugPrint('ML Kit warm-up error: $e');
    }
  }
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
  TextRecognizer? _textRecognizer;
  ObjectDetector? _objectDetector;
  bool _isProcessingFrame = false;
  int _throttleMs = 500; // Increased throttle for better performance
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isCameraInitialized = false;

  bool _quickHasEdges(CameraImage image, {int sampleStride = 40, int threshold = 4}) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    int count = 0;
    // Sample fewer pixels for better performance
    for (int i = 0; i + sampleStride < bytes.length; i += sampleStride) {
      final diff = (bytes[i] - bytes[i + sampleStride]).abs();
      if (diff > 30) count++; // Increased threshold for better filtering
      if (count >= threshold) return true;
    }
    return false;
  }

  // Camera image stream handler with optimized processing
  void _handleCameraImage(CameraImage image) async {
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < _throttleMs) return;
    _lastProcessed = now;

    if (_isProcessingFrame) return;

    // Quick prefilter on Y plane with optimized sampling
    if (!_quickHasEdges(image)) return;

    _isProcessingFrame = true;
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      if (_isCapturing) return;
      if (_textRecognizer == null) return;

      // Convert CameraImage to a temporary JPEG file and preprocess
      String tmpPath;
      try {
        tmpPath = await _cameraImageToJpegFile(image);
      } catch (e) {
        debugPrint('Failed to convert camera image to jpg: $e');
        return;
      }

      try {
        final bytes = await File(tmpPath).readAsBytes();
        final preprocessed = await compute<Uint8List, Uint8List>(_preprocessImageBytesCompute, bytes);
        final detection = await compute<Uint8List, TextDetectionResult>(_optimizedTextDetectionCompute, preprocessed);

        const minConfidenceForOcr = 0.25;
        if (!detection.hasText || detection.confidence < minConfidenceForOcr) {
          _telemetry_detectionsSkipped++;
          debugPrint('Stream detection skipped (confidence=${detection.confidence})');
          try { await File(tmpPath).delete(); } catch (_) {}
        } else {
          _telemetry_detectionsPassed++;
          debugPrint('Stream detection passed (confidence=${detection.confidence})');

          var handled = false;

          if (_objectDetector != null) {
            try {
              final dir = await getTemporaryDirectory();
              final tmpDetect = File('${dir.path}/detect_${DateTime.now().microsecondsSinceEpoch}.jpg');
              await tmpDetect.writeAsBytes(preprocessed);
              final inputImg = InputImage.fromFilePath(tmpDetect.path);
              final objects = await _objectDetector!.processImage(inputImg);

              if (objects.isNotEmpty) {
                DetectedObject? best;
                double bestArea = 0.0;
                for (final o in objects) {
                  final rect = o.boundingBox;
                  final area = rect.width * rect.height;
                  if (area > bestArea) {
                    bestArea = area;
                    best = o;
                  }
                }

                if (best != null) {
                  try {
                    final full = img.decodeImage(preprocessed);
                    if (full != null) {
                      final r = best.boundingBox;
                      final left = r.left.clamp(0, full.width - 1).toInt();
                      final top = r.top.clamp(0, full.height - 1).toInt();
                      final right = r.right.clamp(1, full.width).toInt();
                      final bottom = r.bottom.clamp(1, full.height).toInt();
                      final w = (right - left).clamp(1, full.width);
                      final h = (bottom - top).clamp(1, full.height);
                      final crop = img.copyCrop(full, x: left, y: top, width: w, height: h);
                      final cropBytes = img.encodeJpg(crop, quality: 85);
                      final tmpCrop = File('${dir.path}/crop_${DateTime.now().microsecondsSinceEpoch}.jpg');
                      await tmpCrop.writeAsBytes(cropBytes);

                      final inputImage = InputImage.fromFilePath(tmpCrop.path);
                      _telemetry_ocrRuns++;
                      final recognized = await _textRecognizer!.processImage(inputImage);
                      try { await tmpDetect.delete(); } catch (_) {}
                      try { await tmpCrop.delete(); } catch (_) {}

                      if (recognized.text.trim().isNotEmpty && recognized.text.trim().length > 8) {
                        debugPrint('ROI OCR detected text len=${recognized.text.length}');
                        try { await _takePicture(); } catch (_) {}
                      }

                      try { await File(tmpPath).delete(); } catch (_) {}
                      handled = true;
                    }
                  } catch (e) {
                    debugPrint('ROI crop/ocr error: $e');
                  }
                }
              }

              try { await tmpDetect.delete(); } catch (_) {}
            } catch (e) {
              debugPrint('Object detection error: $e');
            }
          }

          if (!handled) {
            try {
              final dir = await getTemporaryDirectory();
              final tmp2 = File('${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
              await tmp2.writeAsBytes(preprocessed);
              final inputImage = InputImage.fromFilePath(tmp2.path);
              _telemetry_ocrRuns++;
              final recognized = await _textRecognizer!.processImage(inputImage);
              try { await tmp2.delete(); } catch (_) {}
              try { await File(tmpPath).delete(); } catch (_) {}

              if (recognized.text.trim().isNotEmpty && recognized.text.trim().length > 8) {
                debugPrint('Stream OCR detected significant text length=${recognized.text.length}');
                try { await _takePicture(); } catch (_) {}
              }
            } catch (e) {
              debugPrint('Stream OCR error after detection: $e');
              try { await File(tmpPath).delete(); } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('Stream OCR detection error: $e');
        try { await File(tmpPath).delete(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('Camera stream processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
    }
  bool _hasCameraPermission = false;
  Uint8List? _lastCapturedBytes;
  String? _lastCapturedPath;
  bool _isKept = false;
  bool _flashOn = false;
  bool _torchAvailable = false;
  bool _isFlashHovering = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  double _aiPct = 0.0;
  double _humanPct = 0.0;

  // Telemetry counters
  int _telemetry_capturesAttempted = 0;
  int _telemetry_capturesFailed = 0;
  int _telemetry_ocrRuns = 0;
  int _telemetry_detectionsPassed = 0;
  int _telemetry_detectionsSkipped = 0;

  // Cancel token for analysis
  Completer<bool>? _analysisCompleter;

  // Memory management
  Timer? _memoryCleanupTimer;
  int _memoryPressureLevel = 0;

  @override
  void initState() {
    super.initState();

    // Initialize memory management with more frequent cleanup
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
    // Initialize object detector
    try {
      final options = ObjectDetectorOptions(mode: DetectionMode.single, classifyObjects: false, multipleObjects: false);
      _objectDetector = ObjectDetector(options: options);
    } catch (_) {
      _objectDetector = null;
    }
  }

  // Initialize memory management with more frequent cleanup
  void _initializeMemoryManagement() {
    // Check memory pressure every 15 seconds (more frequent)
    _memoryCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkMemoryPressure();
    });
  }

  // Check memory pressure and clean up if needed
  void _checkMemoryPressure() {
    // Simulate memory pressure check
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
        // Warm-up ML Kit models di awal agar siap digunakan
        _warmUpMlKitModels();
        setState(() {
          _lastCapturedBytes = null;
          _lastCapturedPath = null;
          _isKept = false;
        });
      }
    }

    // Force garbage collection
    // Note: This is not recommended in production code
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
    _objectDetector?.close();
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
                    if (!_torchAvailable) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Flash tidak tersedia pada kamera ini')),
                      );
                      return;
                    }

                    // Toggle flash state
                    setState(() {
                      _flashOn = !_flashOn;
                    });

                    // Apply flash state
                    await _setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
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
                // Telemetry dump (debug-only)
                if (kDebugMode)
                  GestureDetector(
                    onTap: () {
                      final msg = 'caps:$_telemetry_capturesAttempted fails:$_telemetry_capturesFailed ocr:$_telemetry_ocrRuns det_pass:$_telemetry_detectionsPassed det_skip:$_telemetry_detectionsSkipped';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
                      );
                    },
                    child: _buildControlButton(Icons.bug_report, 'METRIK', Colors.purple),
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

      // Use lower resolution for better performance on low-memory devices
      // Prefer a back-facing camera if available
      CameraDescription selected = cameras[0];
      try {
        selected = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras[0]);
      } catch (_) {
        selected = cameras[0];
      }

      _cameraController = CameraController(
        selected,
        ResolutionPreset.low, // Changed from medium to low
        enableAudio: false,
      );

      await _cameraController?.initialize();

      // Initialize ML Kit text recognizer
      try {
        _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      } catch (_) {
        _textRecognizer = null;
      }

      // Start image stream with optimized processing
      try {
        await _cameraController?.startImageStream(_handleCameraImage);
      } catch (_) {
        // Some platforms may not support streams
      }

      // Check torch availability by trying to set FlashMode.torch briefly
      _checkTorchAvailability();

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

  // Check torch availability in a more robust way
  Future<void> _checkTorchAvailability() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _torchAvailable = false;
      return;
    }

    try {
      // Try to get flash mode first
      final currentFlashMode = _cameraController!.value.flashMode;
      
      // Try to set torch mode briefly
      await _cameraController!.setFlashMode(FlashMode.torch);
      
      // Small delay to let platform apply
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Reset to previous mode
      await _cameraController!.setFlashMode(currentFlashMode);
      
      // If we got here without errors, torch is available
      _torchAvailable = true;
    } catch (e) {
      debugPrint('Torch not available: $e');
      _torchAvailable = false;
    }
  }

  // Set flash mode with better error handling
  Future<void> _setFlashMode(FlashMode mode) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _cameraController!.setFlashMode(mode);
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
      
      // If setting torch fails, update availability
      if (mode == FlashMode.torch) {
        setState(() {
          _torchAvailable = false;
          _flashOn = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Flash tidak tersedia pada perangkat ini')),
          );
        }
      }
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
    await _captureWithRetries(highRes: false);
  }

  Future<void> _captureWithRetries({required bool highRes, int retries = 2, Duration timeout = const Duration(seconds: 5)}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isCapturing) return;
    setState(() { _isCapturing = true; });

  CameraController? originalController = _cameraController;
    try {
      // Stop stream before capture
      try { await _cameraController?.stopImageStream(); } catch (_) {}

      // Optionally upgrade resolution by recreating controller (best-effort)
      if (highRes) {
        try {
          final desc = _cameraController!.description;
          await _cameraController?.dispose();
          _cameraController = CameraController(desc, ResolutionPreset.high, enableAudio: false);
          await _cameraController?.initialize();
        } catch (e) {
          debugPrint('Failed to switch to high resolution: $e');
          _cameraController = originalController;
        }
      }

      int attempt = 0;
      while (attempt <= retries) {
        attempt++;
        _telemetry_capturesAttempted++;
        try {
          final fileFuture = _cameraController!.takePicture();
          final file = await fileFuture.timeout(timeout);
          final bytes = await file.readAsBytes();
          setState(() {
            _lastCapturedBytes = bytes;
            _lastCapturedPath = file.path;
            _isKept = false;
          });
          break; // success
        } catch (e) {
          _telemetry_capturesFailed++;
          debugPrint('Capture attempt $attempt failed: $e');
          if (attempt > retries) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error mengambil gambar: $e'), backgroundColor: Colors.red),
              );
            }
          } else {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }
    } finally {
      // Restore original controller if we recreated
      try {
        if (highRes && originalController != null && _cameraController != originalController) {
          try { await _cameraController?.dispose(); } catch (_) {}
          _cameraController = originalController;
          try { await _cameraController?.initialize(); } catch (_) {}
        }
      } catch (_) {}

      // Restart image stream (best-effort)
      try { await _cameraController?.startImageStream(_handleCameraImage); } catch (_) {}

      if (_torchAvailable) {
        await _setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
      }

      if (mounted) setState(() { _isCapturing = false; });
    }
  }

  // Convert a CameraImage (YUV420) to a temporary JPEG file.
  // This is a best-effort converter for common Android/iOS YUV420 formats.
  Future<String> _cameraImageToJpegFile(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      final planeY = image.planes[0];
      final planeU = image.planes.length > 1 ? image.planes[1] : null;
      final planeV = image.planes.length > 2 ? image.planes[2] : null;

  final img.Image imgImage = img.Image(width: width, height: height);

      // Fallback simple conversion using YUV -> RGB
      final yBytes = planeY.bytes;
      final uBytes = planeU?.bytes;
      final vBytes = planeV?.bytes;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yp = yBytes[y * planeY.bytesPerRow + x] & 0xFF;

          // UV are usually subsampled by 2
          final int uvRow = (y / 2).floor();
          final int uvCol = (x / 2).floor();

          int u = 128;
          int v = 128;

          if (uBytes != null && vBytes != null) {
            final int uIndex = uvRow * (planeU?.bytesPerRow ?? 0) + uvCol;
            final int vIndex = uvRow * (planeV?.bytesPerRow ?? 0) + uvCol;
            if (uIndex >= 0 && uIndex < uBytes.length) u = uBytes[uIndex] & 0xFF;
            if (vIndex >= 0 && vIndex < vBytes.length) v = vBytes[vIndex] & 0xFF;
          }

          final int yVal = yp;
          final int uVal = u - 128;
          final int vVal = v - 128;

          int r = (yVal + (1.370705 * vVal)).round();
          int g = (yVal - (0.337633 * vVal) - (0.698001 * uVal)).round();
          int b = (yVal + (1.732446 * uVal)).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          imgImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      final jpg = img.encodeJpg(imgImage, quality: 75);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/frame_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpg);
      return file.path;
    } catch (e) {
      rethrow;
    }
  }
  

  void _handleFlashHover(bool hovering) {
    if (_isFlashHovering == hovering) return;
    
    setState(() {
      _isFlashHovering = hovering;
    });
    
    // Only apply flash if torch is available
    if (_torchAvailable) {
      _setFlashMode(hovering || _flashOn ? FlashMode.torch : FlashMode.off);
    }
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
      // Stage 1: Optimized text detection (20% of progress)
      TextDetectionResult textDetection;
      try {
        textDetection = await compute(_optimizedTextDetectionCompute, _lastCapturedBytes!);

        // Update progress
        if (_analysisCompleter?.isCompleted == false) {
          setState(() {
            _analysisProgress = 0.2;
          });
        }
      } catch (e) {
        textDetection = TextDetectionResult(hasText: false, confidence: 0.0);
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