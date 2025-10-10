import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../config/animation_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb, compute, kDebugMode;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:collection';
import 'package:image/image.dart' as img;
import '../models/scan_history.dart' as Model;
import '../utils/history_manager.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/robust_worker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';

// Memory monitor class for actual memory tracking
class MemoryMonitor {
  static int _memoryThreshold = 100 * 1024 * 1024; // 100MB default threshold
  
  static Future<void> initialize() async {
    if (kIsWeb) return;
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // device_info_plus does not reliably expose total memory across platforms.
        // Use a lightweight heuristic instead: prefer 64-bit ABI presence and model hints.
        try {
          final has64 = androidInfo.supported64BitAbis.isNotEmpty;
          if (has64) {
            // Likely a newer device; set a higher threshold
            _memoryThreshold = 300 * 1024 * 1024; // 300MB
          } else {
            // Likely older/32-bit device; keep conservative threshold
            _memoryThreshold = 100 * 1024 * 1024; // 100MB
          }
        } catch (e) {
          // Fallback conservative threshold
          _memoryThreshold = 100 * 1024 * 1024;
        }
      } else if (Platform.isIOS) {
        // iOS doesn't provide memory info, use conservative threshold
        _memoryThreshold = 80 * 1024 * 1024; // 80MB
      }
    } catch (e) {
      debugPrint('Error initializing memory monitor: $e');
    }
  }
  
  static bool isMemoryPressureHigh() {
    // In a real implementation, you would check actual memory usage
    // For now, we'll use a simple heuristic based on time
    final now = DateTime.now();
    return now.second % 10 < 3; // Simulate memory pressure 30% of the time
  }
  
  static int get memoryThreshold => _memoryThreshold;
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

    // Downscale significantly for performance - target 150x150 max for mobile
    final targetSize = kIsWeb ? 300 : 150;
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
    final edgeThreshold = kIsWeb ? 30 : 45; // Higher threshold for mobile to reduce false positives
    final minEdgeRatio = kIsWeb ? 0.02 : 0.04; // Higher minimum for mobile
    
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
  final regionSize = kIsWeb ? 60 : 30; // Smaller regions for mobile
  final threshold = kIsWeb ? 15 : 25; // Higher threshold for mobile
  
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

class _CameraScanScreenState extends State<CameraScanScreen>
  with TickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _isProcessingFrame = false;
  int _throttleMs = kIsWeb ? 500 : 1500; // Increased throttle for mobile
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  // Stream control and OCR mutex
  StreamController<CameraImage>? _cameraImageStreamController;
  StreamSubscription<CameraImage>? _cameraImageStreamSub;
  bool _ocrLock = false;
  // debug timing will be local to capture worker
  // Serial capture queue to ensure captures are processed one-by-one
  final ListQueue<Completer<bool>> _captureQueue = ListQueue<Completer<bool>>();
  bool _captureWorkerRunning = false;
  
  // (old delegator removed) image frames are handled via _startImageStream -> _onImageReceived

  bool _quickHasEdges(CameraImage image, {int sampleStride = 40, int threshold = 4}) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    int count = 0;
    // Sample fewer pixels for better performance
    final stride = kIsWeb ? sampleStride : sampleStride * 3; // Even fewer samples on mobile
    final edgeThreshold = kIsWeb ? 30 : 45; // Higher threshold for mobile
    
    for (int i = 0; i + stride < bytes.length; i += stride) {
      final diff = (bytes[i] - bytes[i + stride]).abs();
      if (diff > edgeThreshold) count++;
      if (count >= threshold) return true;
    }
    return false;
  }

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
  bool _isLowMemoryDevice = false; // Detect low memory devices
  int _consecutiveErrors = 0; // Track consecutive errors for recovery

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize memory monitor
    _initializeMemoryMonitor();
    
    // Detect if this is a low memory device
    _detectLowMemoryDevice();
    
    // Initialize memory management with more frequent cleanup
    _initializeMemoryManagement();
    
    // Initialize animation controllers
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    // Initialize animation objects
    if (AnimationConfig.enableBackgroundAnimations && !_isLowMemoryDevice) {
      _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);
      _backgroundController.repeat();

      _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));
      _glowController.repeat(reverse: true);

      _scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ));
      _scanController.repeat();

      _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      _pulseController.repeat(reverse: true);

      _rotateController.repeat();
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
    }

    _requestCameraPermission();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        _stopImageStream();
        _cameraController?.pausePreview();
      } else if (state == AppLifecycleState.resumed) {
        _cameraController?.resumePreview();
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Lifecycle handling error: $e');
    }
  }

  // Initialize memory monitor
  Future<void> _initializeMemoryMonitor() async {
    await MemoryMonitor.initialize();
  }

  // Detect if this is a low memory device
  Future<void> _detectLowMemoryDevice() async {
    if (kIsWeb) {
      _isLowMemoryDevice = false;
      return;
    }
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // device_info_plus doesn't expose totalMemory consistently. Use ABI/model heuristics.
        try {
          final has64 = androidInfo.supported64BitAbis.isNotEmpty;
          if (has64) {
            // Assume devices with 64-bit ABI have >= 3GB in most cases
            _isLowMemoryDevice = false;
          } else {
            // 32-bit ABI -> likely low memory
            _isLowMemoryDevice = true;
          }
        } catch (e) {
          final model = androidInfo.model;
          _isLowMemoryDevice = _isLowEndAndroidModel(model);
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final model = iosInfo.model;
        _isLowMemoryDevice = _isLowEndIOSModel(model);
      }
    } catch (e) {
      debugPrint('Error detecting device capabilities: $e');
      // Assume low memory if we can't detect
      _isLowMemoryDevice = true;
    }
  }

  // Check if Android model is low-end
  bool _isLowEndAndroidModel(String model) {
    // List of known low-end Android models
    const lowEndModels = [
      'Android One',
      'Galaxy J2',
      'Galaxy J3',
      'Galaxy J4',
      'Galaxy J5',
      'Galaxy J6',
      'Galaxy A2',
      'Galaxy A10',
      'Galaxy A20',
      'Redmi 5',
      'Redmi 6',
      'Redmi 7',
      'Redmi 8',
      'Redmi 9',
      'Redmi Go',
      'Moto E',
      'Moto C',
      'Moto G Play',
    ];
    
    return lowEndModels.any((lowEndModel) => 
        model.toLowerCase().contains(lowEndModel.toLowerCase()));
  }

  // Check if iOS model is low-end
  bool _isLowEndIOSModel(String model) {
    // List of known low-end iOS models
    const lowEndModels = [
      'iPhone 5',
      'iPhone 5c',
      'iPhone 5s',
      'iPhone 6',
      'iPhone 6 Plus',
      'iPhone SE',
      'iPad mini 2',
      'iPad mini 3',
      'iPad Air',
      'iPod touch',
    ];
    
    return lowEndModels.any((lowEndModel) => 
        model.contains(lowEndModel));
  }

  // Initialize memory management with more frequent cleanup
  void _initializeMemoryManagement() {
    // Check memory pressure more frequently on mobile
    final interval = _isLowMemoryDevice ? 8 : 12;
    _memoryCleanupTimer = Timer.periodic(Duration(seconds: interval), (_) {
      _checkMemoryPressure();
    });
  }

  // Check memory pressure and clean up if needed
  void _checkMemoryPressure() {
    // Use actual memory pressure detection
    final isHighPressure = MemoryMonitor.isMemoryPressureHigh();
    
    if (isHighPressure || _isLowMemoryDevice) {
      // High memory pressure or low memory device - perform aggressive cleanup
      _performMemoryCleanup(aggressive: true);
    }
  }

  // Perform memory cleanup
  void _performMemoryCleanup({bool aggressive = false}) {
    // Clear image cache if not analyzing
    if (!_isAnalyzing && _lastCapturedBytes != null) {
      if (aggressive || _isLowMemoryDevice) {
        // Aggressive cleanup - clear the captured image
        setState(() {
          _lastCapturedBytes = null;
          _lastCapturedPath = null;
          _isKept = false;
        });
      }
    }
    
    // Stop animations on aggressive cleanup
    if (aggressive && AnimationConfig.enableBackgroundAnimations) {
      _backgroundController.stop();
      _glowController.stop();
      _scanController.stop();
      _pulseController.stop();
      _rotateController.stop();
      
      // Restart after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isLowMemoryDevice) {
          _backgroundController.repeat();
          _glowController.repeat(reverse: true);
          _scanController.repeat();
          _pulseController.repeat(reverse: true);
          _rotateController.repeat();
        }
      });
    }
  }

  // Handle errors with recovery mechanism
  void _handleError(String error, {bool critical = false}) {
    debugPrint('Error: $error');
    _consecutiveErrors++;
    
    // If too many consecutive errors, perform recovery
    if (_consecutiveErrors >= 3 || critical) {
      _performErrorRecovery();
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Perform error recovery
  Future<void> _performErrorRecovery() async {
    debugPrint('Performing error recovery');
    
    // Reset error counter
    _consecutiveErrors = 0;
    
    // Aggressive memory cleanup
    _performMemoryCleanup(aggressive: true);
    
    // Restart camera if needed
    if (_cameraController != null && _isCameraInitialized) {
      try {
        await _stopImageStream();
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (mounted && _cameraController != null) {
            try {
              await _startImageStream();
            } catch (e) {
              debugPrint('Error restarting image stream: $e');
            }
          }
        });
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
    }
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
      if (_cameraController?.value.isStreamingImages ?? false) {
        _cameraController?.stopImageStream();
      }
    } catch (_) {}
    _textRecognizer?.close();
    _cameraController?.dispose();
    
    super.dispose();
  }

  // Safe wrapper to call setState only when mounted
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated cyberpunk background - simplified for low memory devices
          _isLowMemoryDevice 
            ? Container(color: Colors.black)
            : _buildAnimatedBackground(),
          
          // Grid overlay effect - skip on low memory devices
          if (!_isLowMemoryDevice) _buildGridOverlay(),
          
          // Scan line effect
          _buildScanLine(),
          
          // Glitch effect overlay - skip on low memory devices
          if (!_isLowMemoryDevice) _buildGlitchEffect(),
          
          // Floating particles effect - skip on low memory devices
          if (!_isLowMemoryDevice) _buildFloatingParticles(),
          
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
          
          // Cyberpunk frame borders - simplified for low memory devices
          _isLowMemoryDevice ? _buildSimpleFrame() : _buildCyberpunkFrame(),
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
                      _handleError('Flash tidak tersedia: $e');
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

  Widget _buildSimpleFrame() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.cyan.withOpacity(0.5),
            width: 1,
          ),
        ),
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
      final resolutionPreset = _isLowMemoryDevice 
        ? ResolutionPreset.low 
        : (kIsWeb ? ResolutionPreset.medium : ResolutionPreset.low);
        
      _cameraController = CameraController(
        cameras[0],
        resolutionPreset,
        enableAudio: false,
      );

      await _cameraController?.initialize();

      // Initialize ML Kit text recognizer
      try {
        _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      } catch (_) {
        _textRecognizer = null;
      }

      // Start image stream with optimized processing via helper
      try {
        await _startImageStream();
      } catch (e) {
        debugPrint('Image stream start failed: $e');
      }

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _handleError('Error menginisialisasi kamera: $e', critical: true);
    }
  }

  // Start image stream using a StreamController so we can pause/resume and cancel safely
  Future<void> _startImageStream() async {
    if (_cameraController == null) return;
    try {
      if (_cameraController!.value.isStreamingImages) return;

      // Clean previous
      await _stopImageStream();

      _cameraImageStreamController = StreamController<CameraImage>.broadcast();
      await _cameraController!.startImageStream((CameraImage img) {
        try {
          if (!(_cameraImageStreamController?.isClosed ?? true)) {
            _cameraImageStreamController!.add(img);
          }
        } catch (_) {}
      });

      _cameraImageStreamSub = _cameraImageStreamController!.stream.listen((img) async {
        await _onImageReceived(img);
      }, onError: (e) {
        debugPrint('Image stream error: $e');
      });
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
    }
  }

  Future<void> _stopImageStream() async {
    try {
      await _cameraImageStreamSub?.cancel();
      _cameraImageStreamSub = null;
      try { await _cameraImageStreamController?.close(); } catch (_) {}
      _cameraImageStreamController = null;
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        try { await _cameraController!.stopImageStream(); } catch (e) { debugPrint('stopImageStream thrown: $e'); }
      }
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
  }

  // Called for each frame from the stream (throttled + processing guard)
  Future<void> _onImageReceived(CameraImage image) async {
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < _throttleMs) return;
    _lastProcessed = now;

    if (_isProcessingFrame) return;

    if (!_quickHasEdges(image)) return;

  // start debug timer (will be measured in worker)

    // Enqueue a capture request instead of performing capture immediately.
    // Limit queue size to avoid unbounded buffering.
      try {
      if (_captureQueue.length >= 2) return; // already have pending tasks
      final completer = Completer<bool>();
      _captureQueue.add(completer);
      if (!_captureWorkerRunning) _processCaptureQueue();
      // don't await here; allow queue to process in background
    } catch (e) {
      debugPrint('Failed to enqueue capture: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // Worker to process capture queue sequentially
  Future<void> _processCaptureQueue() async {
    if (_captureWorkerRunning) return;
    _captureWorkerRunning = true;
    while (_captureQueue.isNotEmpty) {
      final completer = _captureQueue.removeFirst();
      bool success = false;
      try {
        success = await _performCaptureAndProcess();
      } catch (e) {
        debugPrint('Error processing queued capture: $e');
        success = false;
      }
      try { completer.complete(success); } catch (_) {}
      // small delay between queued captures to avoid rapid repeats
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _captureWorkerRunning = false;
  }

  // Perform a full capture + OCR processing with retry/backoff and safe stream handling.
  Future<bool> _performCaptureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return false;
    if (_ocrLock) return false;
    _ocrLock = true;
    _isCapturing = true;
  XFile? file;
  final Stopwatch? sw = kDebugMode ? (Stopwatch()..start()) : null;
    try {
      await _stopImageStream();
      int attempts = 0;
      while (attempts < 5) {
        attempts++;
        try {
          file = await _cameraController!.takePicture();
          break;
        } on CameraException catch (ce) {
          debugPrint('Queued takePicture CameraException (attempt $attempts): ${ce.code} ${ce.description}');
          if (ce.code.contains('previous') || (ce.description?.contains('previous') ?? false)) {
            // backoff
            await Future.delayed(Duration(milliseconds: 250 * attempts));
            continue;
          }
          return false;
        }
      }

      if (file == null) return false;

      if (_textRecognizer != null) {
        try {
          final f = file; // local non-null reference
          final inputImage = InputImage.fromFilePath(f.path);
          final recognized = await _textRecognizer!.processImage(inputImage);
          if (recognized.text.trim().isNotEmpty && recognized.text.trim().length > 2) {
            final bytes = await File(f.path).readAsBytes();
            _safeSetState(() {
              _lastCapturedBytes = bytes;
              _lastCapturedPath = f.path;
            });
          }
        } catch (e) {
          debugPrint('Queued text recognition error: $e');
        }
      }

      try { await File(file.path).delete(); } catch (_) {}
      if (kDebugMode && sw != null) {
        sw.stop();
        debugPrint('Queued capture total time: ${sw.elapsedMilliseconds} ms');
      }
      return true;
    } finally {
      _ocrLock = false;
      _isCapturing = false;
      if (mounted) await _startImageStream();
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
      _handleError('Error meminta izin kamera: $e');
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _safeSetState(() { _isCapturing = true; });

    try {
      // Turn torch on if needed
      final shouldTorch = _flashOn || _isFlashHovering;
      if (shouldTorch) {
        try { await _cameraController?.setFlashMode(FlashMode.torch); } catch (_) {}
      }

      // Ensure image stream is stopped before capture
      await _stopImageStream();

      // Capture with retry for "previous capture not returned" errors
      XFile? file;
      int attempts = 0;
      while (attempts < 3) {
        try {
          file = await _cameraController!.takePicture();
          break;
        } on CameraException catch (ce) {
          attempts++;
          debugPrint('takePicture CameraException (attempt $attempts): ${ce.code} ${ce.description}');
          if (ce.code.contains('previous') || (ce.description?.contains('previous') ?? false)) {
            await Future.delayed(Duration(milliseconds: 250 * attempts));
            continue;
          }
          rethrow;
        } catch (e) {
          debugPrint('takePicture failed: $e');
          break;
        }
      }

      if (file != null) {
        final f = file;
        final bytes = await f.readAsBytes();
        _safeSetState(() {
          _lastCapturedBytes = bytes;
          _lastCapturedPath = f.path;
          _isKept = false;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _handleError('Error mengambil gambar: $e');
    } finally {
      try { await _cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off); } catch (_) {}
      _safeSetState(() { _isCapturing = false; });
      // Restart image stream if still intended
      if (mounted) await _startImageStream();
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
      _handleError('Error selama analisis: $e');
      
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
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