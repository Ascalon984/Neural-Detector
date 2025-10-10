import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../config/animation_config.dart';
import '../models/scan_history.dart' as Model;
import '../utils/history_manager.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/ocr.dart';
import '../utils/debug_logger.dart';
import '../utils/tflite_helper.dart';

/// Main camera scan screen for text recognition
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  // Camera and OCR
  CameraController? _cameraController;
  TextRecognizer? _textRecognizer;
  List<CameraDescription>? _cameras;
  
  // State management
  bool _isInitialized = false;
  bool _isProcessingFrame = false;
  bool _isLowMemoryDevice = false;
  bool _hasHardwareAcceleration = false;
  
  // Performance tracking
  int _throttleMs = kIsWeb ? 500 : 1000;
  int _lastOcrMs = 800;
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  double _lastOcrConfidence = 0.0;
  int _ocrSuccessCount = 0;
  int _ocrFailureCount = 0;
  
  // Stream management
  StreamController<CameraImage>? _cameraImageStreamController;
  StreamSubscription<CameraImage>? _cameraImageStreamSub;
  bool _ocrLock = false;
  
  // Capture queue
  final ListQueue<Completer<bool>> _captureQueue = ListQueue<Completer<bool>>();
  bool _captureWorkerRunning = false;
  
  // Cleanup timer
  Timer? _tempCleanupTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAnimations();
    _disposeCamera();
    _tempCleanupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.resumed:
        _startCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopCamera();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // Animation initialization
  void _initializeAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _backgroundController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
    _scanController.repeat();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
  }

  void _disposeAnimations() {
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
  }

  // Camera initialization
  Future<void> _initializeCamera() async {
    try {
      await _checkPermissions();
      await _detectDeviceCapabilities();
      await _initializeTextRecognizer();
      await _initializeCameraController();
      await _startCamera();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      _showErrorDialog('Failed to initialize camera: $e');
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) return;
    
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus != PermissionStatus.granted) {
      throw Exception('Camera permission denied');
    }
  }

  Future<void> _detectDeviceCapabilities() async {
    if (kIsWeb) {
      _isLowMemoryDevice = false;
      _hasHardwareAcceleration = false;
      return;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _isLowMemoryDevice = androidInfo.supported64BitAbis.isEmpty;
      } else if (Platform.isIOS) {
        _isLowMemoryDevice = true; // Conservative approach for iOS
      }
    } catch (e) {
      debugPrint('Device capability detection failed: $e');
      _isLowMemoryDevice = true; // Default to low memory
    }
  }

  Future<void> _initializeTextRecognizer() async {
    try {
      // Prefer Latin script for improved accuracy/perf on typical documents
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    } catch (e) {
      debugPrint('Text recognizer initialization failed: $e');
      throw Exception('Failed to initialize text recognizer');
    }
  }

  Future<void> _initializeCameraController() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    final camera = _cameras!.first;
    _cameraController = CameraController(
      camera,
      _getOptimalResolution(),
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
  }

  ResolutionPreset _getOptimalResolution() {
    if (_lastOcrConfidence < 0.7 && !_isLowMemoryDevice) {
      return ResolutionPreset.high;
    } else if (_lastOcrConfidence > 0.9 && _isLowMemoryDevice) {
      return ResolutionPreset.low;
    }
    return ResolutionPreset.medium;
  }

  Future<void> _startCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Ensure optimal AF/AE modes for text
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      await _cameraController!.startImageStream(_onImageReceived);
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to start camera: $e');
    }
  }

  Future<void> _stopCamera() async {
    if (_cameraController == null) return;

    try {
      await _cameraController!.stopImageStream();
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to stop camera: $e');
    }
  }

  void _disposeCamera() {
    _cameraImageStreamSub?.cancel();
    _cameraImageStreamController?.close();
    _textRecognizer?.close();
    _cameraController?.dispose();
  }

  // Image processing
  void _onImageReceived(CameraImage image) {
    if (_isProcessingFrame || _ocrLock) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastProcessed).inMilliseconds;
    if (elapsed < _throttleMs) return;

    _isProcessingFrame = true;
    _lastProcessed = now;

    _processImageAsync(image);
  }

  Future<void> _processImageAsync(CameraImage image) async {
    try {
      if (!_quickHasEdges(image)) {
        _isProcessingFrame = false;
        return;
      }

      final result = await _performOCR(image);
      if (result.success && result.text.isNotEmpty) {
        _updateOcrMetrics(true, result.confidence);
        _handleSuccessfulScan(result.text);
      } else {
        _updateOcrMetrics(false, 0.0);
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
      _updateOcrMetrics(false, 0.0);
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _quickHasEdges(CameraImage image, {int threshold = 3}) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 1;

    int count = 0;
    final edgeThreshold = kIsWeb ? 25 : 30;
    final stepY = math.max(1, image.height ~/ 20);
    final stepX = math.max(1, image.width ~/ 20);

    for (int y = 0; y < image.height; y += stepY) {
      for (int x = 0; x + 1 < image.width; x += stepX) {
        final idx = y * rowStride + x * pixelStride;
        final idx2 = y * rowStride + (x + 1) * pixelStride;
        if (idx >= bytes.length || idx2 >= bytes.length) continue;
        
        final v1 = bytes[idx];
        final v2 = bytes[idx2];
        final diff = (v1 - v2).abs();
        if (diff > edgeThreshold) {
          count++;
          if (count >= threshold) return true;
        }
      }
    }

    return false;
  }

  Future<TextRecognitionResult> _performOCR(CameraImage image) async {
    if (_textRecognizer == null) {
      return TextRecognitionResult(
        text: '',
        success: false,
        error: 'No recognizer available',
      );
    }

    try {
      final startedAt = DateTime.now();
      final inputImage = _convertCameraImageToInputImage(image);
      final recognized = await _textRecognizer!.processImage(inputImage);
      _lastOcrMs = DateTime.now().difference(startedAt).inMilliseconds;
      // Adapt throttle tightly to current device performance
      _throttleMs = (_lastOcrMs * (_isLowMemoryDevice ? 0.9 : 0.7))
          .round()
          .clamp(300, 1400);
      
      return TextRecognitionResult(
        text: recognized.text,
        success: recognized.text.isNotEmpty,
        confidence: _calculateConfidence(recognized),
      );
    } catch (e) {
      return TextRecognitionResult(
        text: '',
        success: false,
        error: e.toString(),
      );
    }
  }

  InputImage _convertCameraImageToInputImage(CameraImage cameraImage) {
    // Provide accurate rotation/format for better ML Kit accuracy
    final rotation = InputImageRotationValue.fromRawValue(
          _cameraController?.description.sensorOrientation ?? 0,
        ) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw) ??
        InputImageFormat.yuv_420;

    // Use Y plane for memory efficiency; ML Kit accepts this with YUV metadata
    final plane = cameraImage.planes[0];
    final bytes = plane.bytes;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(
          cameraImage.width.toDouble(),
          cameraImage.height.toDouble(),
        ),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  double _calculateConfidence(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;
    
    double totalConfidence = 0.0;
    int blockCount = 0;
    
    for (final block in recognizedText.blocks) {
      if (block.text.isNotEmpty) {
        totalConfidence += 0.8; // Default confidence for text blocks
        blockCount++;
      }
    }
    
    return blockCount > 0 ? totalConfidence / blockCount : 0.0;
  }

  void _updateOcrMetrics(bool success, double confidence) {
    if (success) {
      _ocrSuccessCount++;
      _lastOcrConfidence = confidence;
    } else {
      _ocrFailureCount++;
    }

    // Adaptive throttling based on success rate
    final successRate = _ocrSuccessCount / (_ocrSuccessCount + _ocrFailureCount);
    if (successRate < 0.5) {
      _throttleMs = (_throttleMs * 1.2).round().clamp(400, 2000);
    } else if (successRate > 0.8) {
      _throttleMs = (_throttleMs * 0.9).round().clamp(400, 1200);
    }
  }

  void _handleSuccessfulScan(String text) {
    // Save to history
    _saveToHistory(text);
    
    // Show notification
    _showScanNotification(text);
  }

  Future<void> _saveToHistory(String text) async {
    try {
      final historyItem = Model.ScanHistory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        timestamp: DateTime.now(),
        confidence: _lastOcrConfidence,
      );
      
      await HistoryManager.addScan(historyItem);
    } catch (e) {
      debugPrint('Failed to save to history: $e');
    }
  }

  void _showScanNotification(String text) {
    if (mounted) {
      CyberNotification.show(
        context,
        'Text Detected',
        text.length > 50 ? '${text.substring(0, 50)}...' : text,
        type: NotificationType.success,
      );
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // UI Components
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background
          _buildBackground(),
          
          // Grid overlay
          if (!_isLowMemoryDevice) _buildGridOverlay(),
          
          // Scan line
          _buildScanLine(),
          
          // Glitch effect
          if (!_isLowMemoryDevice) _buildGlitchEffect(),
          
          // Floating particles
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
          
          // Frame borders
          _isLowMemoryDevice ? _buildSimpleFrame() : _buildCyberpunkFrame(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
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
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Text Scanner',
                      style: TextStyle(
                        color: Colors.cyan.withOpacity(_glowAnimation.value),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.cyan.withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Point camera at text to scan',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: Colors.white.withOpacity(0.8),
                  size: 28,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerContainer() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _isInitialized && _cameraController != null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handleTapToFocus(details.localPosition,
                    contextSize: (context.findRenderObject() as RenderBox?)?.size),
                child: CameraPreview(_cameraController!),
              )
            : _buildLoadingState(),
      ),
    );
  }

  Future<void> _handleTapToFocus(Offset tapPos, {Size? contextSize}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (contextSize == null || contextSize.width == 0 || contextSize.height == 0) {
      return;
    }

    final normalized = Offset(
      (tapPos.dx / contextSize.width).clamp(0.0, 1.0),
      (tapPos.dy / contextSize.height).clamp(0.0, 1.0),
    );

    try {
      await _cameraController!.setFocusPoint(normalized);
    } catch (_) {}
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.cyan.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator(
                'OCR',
                _isProcessingFrame ? 'Processing' : 'Ready',
                _isProcessingFrame ? Colors.orange : Colors.green,
              ),
              _buildStatusIndicator(
                'Camera',
                _isInitialized ? 'Active' : 'Initializing',
                _isInitialized ? Colors.green : Colors.orange,
              ),
              _buildStatusIndicator(
                'Memory',
                _isLowMemoryDevice ? 'Low' : 'Normal',
                _isLowMemoryDevice ? Colors.orange : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.flash_on,
                label: 'Flash',
                onPressed: _toggleFlash,
              ),
              _buildActionButton(
                icon: Icons.switch_camera,
                label: 'Switch',
                onPressed: _switchCamera,
              ),
              _buildActionButton(
                icon: Icons.settings,
                label: 'Settings',
                onPressed: _openSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, String status, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(0.3),
                    Colors.pink.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleFrame() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildCyberpunkFrame() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _CyberpunkFramePainter(_glowAnimation.value),
          size: Size.infinite,
        );
      },
    );
  }

  // Action methods
  void _toggleFlash() {
    // TODO: Implement flash toggle
  }

  void _switchCamera() {
    // TODO: Implement camera switching
  }

  void _openSettings() {
    // TODO: Implement settings
  }
}

// Custom painters
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 1.0;

    const double spacing = 50.0;
    
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
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
  final double rotation;

  _ParticlesPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.3;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + rotation;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      canvas.drawCircle(
        Offset(x, y),
        3.0,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CyberpunkFramePainter extends CustomPainter {
  final double glowIntensity;

  _CyberpunkFramePainter(this.glowIntensity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3 * glowIntensity)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double cornerSize = 40.0;
    
    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerSize)
        ..lineTo(0, 0)
        ..lineTo(cornerSize, 0),
      paint,
    );
    
    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerSize),
      paint,
    );
    
    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerSize)
        ..lineTo(0, size.height)
        ..lineTo(cornerSize, size.height),
      paint,
    );
    
    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Text recognition result class
class TextRecognitionResult {
  final String text;
  final bool success;
  final String? error;
  final double confidence;

  TextRecognitionResult({
    required this.text,
    required this.success,
    this.error,
    this.confidence = 0.0,
  });
}