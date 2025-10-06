import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
// file picker removed for camera UI per request
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/ocr.dart';
import '../models/scan_history.dart' as Model;
import '../utils/history_manager.dart';
import '../utils/text_analyzer.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/app_localizations.dart';
import '../utils/sensitivity.dart';

class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scanAnimation;
  Animation<double>? _pulseAnimation;
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  Uint8List? _lastCapturedBytes;
  String? _lastCapturedPath;
  bool _isKept = false;
  bool _flashOn = false;
  bool _isFlashHovering = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0; // 0.0 - 1.0
  double _aiPct = 0.0;
  double _humanPct = 0.0;
  // file picker removed

  Future<void> _initializeCamera() async {
    try {
      if (kIsWeb) {
        // For web, small delay so browser gets ready
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.t('no_cameras_available')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController?.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (!mounted) return;

      final errorMessage = kIsWeb
          ? AppLocalizations.t('please_allow_camera_browser')
          : AppLocalizations.t('error_initializing_camera');

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
              ? 'Please allow camera access in your browser settings'
              : 'Error requesting camera permission: $e'),
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
      // ensure flash is active during capture if either persistent or hovering
      final shouldTorch = _flashOn || _isFlashHovering;
      if (shouldTorch) {
        try {
          await _cameraController?.setFlashMode(FlashMode.torch);
        } catch (_) {}
      }

      final XFile file = await _cameraController!.takePicture();
      // load bytes for preview (works on mobile & web)
      final bytes = await file.readAsBytes();
      setState(() {
        _lastCapturedBytes = bytes;
        _lastCapturedPath = file.path;
        _isKept = false; // new capture resets kept state
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e'), backgroundColor: Colors.red),
      );
    } finally {
      // After capture, restore flash according to persistent toggle only.
      // If user only hovered (temporary), we don't keep torch on.
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

  Widget _buildFlashControlButton() {
    final active = _flashOn || _isFlashHovering;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: active ? Colors.yellow.shade700 : Colors.cyan.shade400, width: 1),
            gradient: LinearGradient(
              colors: [
                (active ? Colors.yellow.shade700 : Colors.cyan.shade800).withAlpha((0.3 * 255).round()),
                (active ? Colors.yellow.shade700 : Colors.blue.shade800).withAlpha((0.3 * 255).round()),
              ],
            ),
          ),
          child: Icon(Icons.flash_on, color: active ? Colors.yellow : Colors.cyan.shade300, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          'FLASH',
          style: TextStyle(
            color: active ? Colors.yellow.shade200 : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _cancelPicture() async {
    // simply clear captured bytes/state (don't assume deletion method available)
    setState(() {
      _lastCapturedBytes = null;
      _isKept = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      _scanAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.8,
        end: 1.2,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _scanAnimation = const AlwaysStoppedAnimation(0.0);
      _pulseAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      body: Stack(
        children: [
          // Background dengan efek cyberpunk (tanpa animasi)
          _buildCyberpunkBackground(),
          
          // Grid pattern overlay
          _buildGridPattern(),
          
          // Scanner container utama
          _buildScannerContainer(),
          
          // Header dengan kontrol
          _buildHeader(),
          
          // Footer dengan informasi
          _buildFooter(),
          
          // Efek corner borders
          _buildCornerBorders(),
        ],
      ),
    );
  }

  Widget _buildCyberpunkBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Colors.black.withAlpha((0.9 * 255).round()),
            Colors.purple.shade900.withAlpha((0.3 * 255).round()),
            Colors.blue.shade900.withAlpha((0.1 * 255).round()),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _CyberpunkBackgroundPainter(),
      ),
    );
  }

  Widget _buildGridPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.1,
        child: CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildScannerContainer() {
    return Center(
      child: AnimatedBuilder(
        animation: _controller ?? const AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          final screen = MediaQuery.of(context).size;
          final boxWidth = screen.width * 0.95; // 95% of screen width
          final boxHeight = (boxWidth * 1.15).clamp(200.0, screen.height * 0.9);

          return Transform.scale(
            scale: _pulseAnimation?.value ?? 1.0,
            child: SizedBox(
              width: boxWidth,
              height: boxHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.cyan.withAlpha((0.8 * 255).round()),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withAlpha((0.3 * 255).round()),
                      blurRadius: 20,
                      spreadRadius: 5,
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
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                              Text(
                              _hasCameraPermission 
                                ? AppLocalizations.t('initializing_camera')
                                : AppLocalizations.t('camera_permission_required'),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Scanner line
                    Positioned(
                      top: (_scanAnimation?.value ?? 0.0) * boxHeight,
                      child: Container(
                        width: boxWidth,
                        height: 3,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.cyan,
                              Colors.cyan,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Corner accents
                    ..._buildScannerCorners(),

                    // Preview overlay when an image has been captured
                    if (_lastCapturedBytes != null)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withAlpha((180).round()),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _lastCapturedBytes!,
                                  width: boxWidth * 0.85,
                                  height: boxHeight * 0.75,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // (file picker support removed) 
                              const SizedBox(height: 12),
                              // If not yet kept: show Keep and Cancel buttons
                              if (!_isKept)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        // Keep: mark image as kept (do not clear)
                                        if (!mounted) return;
                                        setState(() {
                                          _isKept = true;
                                        });
                                        try {
                                          final auto = await SettingsManager.getAutoScan();
                                          if (auto && mounted) await _analyzeKeptImage();
                                        } catch (_) {}
                                      },
                                      icon: const Icon(Icons.check),
                                      label: Text(AppLocalizations.t('keep')),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: _cancelPicture,
                                      icon: const Icon(Icons.delete),
                                      label: Text(AppLocalizations.t('cancel')),
                                    ),
                                  ],
                                )
                              else
                                // If already kept: hide Keep/Cancel and show only a small trash icon
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () {
                                        if (!mounted) return;
                                        setState(() {
                                          _lastCapturedBytes = null;
                                          _isKept = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(AppLocalizations.t('kept_image_deleted'))),
                                        );
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.delete, color: Colors.black, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
        top: 0,
        left: 0,
        child: _buildCornerWidget(true, true),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: _buildCornerWidget(false, true),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: _buildCornerWidget(true, false),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: _buildCornerWidget(false, false),
      ),
    ];
  }

  Widget _buildCornerWidget(bool isLeft, bool isTop) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          left: isLeft
              ? const BorderSide(color: Colors.pink, width: 3)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.pink, width: 3)
              : BorderSide.none,
          top: isTop
              ? const BorderSide(color: Colors.pink, width: 3)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.pink, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppLocalizations.t('file_upload_title'),
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontSize: 16,
                fontWeight: FontWeight.w300,
                letterSpacing: 3,
                fontFamily: 'Courier',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'BIOMETRIC ANALYSIS ACTIVE',
            style: TextStyle(
              color: Colors.pink.shade300,
              fontSize: 12,
              fontWeight: FontWeight.w200,
              letterSpacing: 2,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha((0.5 * 255).round()),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade700, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTapDown: (_) async => _handleFlashHover(true),
                      onTapUp: (_) async => _handleFlashHover(false),
                      onTapCancel: () async => _handleFlashHover(false),
                      onTap: () async {
                        _flashOn = !_flashOn;
                        try {
                          await _cameraController?.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
                          if (!mounted) return;
                          setState(() {});
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t('flash_not_available').replaceAll('{err}', e.toString()))));
                        }
                      },
                      child: _buildFlashControlButton(),
                    ),
                  ),

                  Flexible(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isCapturing ? null : _takePicture,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCapturing ? Colors.grey.shade600 : Colors.cyan.shade400,
                              boxShadow: [BoxShadow(color: Colors.cyan.withAlpha((0.4 * 255).round()), blurRadius: 8)],
                            ),
                            child: _isCapturing
                                ? SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 26),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(AppLocalizations.t('capture_label'), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),

                  Flexible(
                    child: GestureDetector(
                      onTap: _isKept && !_isAnalyzing ? _analyzeKeptImage : null,
                      child: _buildControlButton(Icons.analytics, 'ANALYZE'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isAnalyzing)
              Text(
                'SCANNING... ${(_analysisProgress * 100).toStringAsFixed(0)}% COMPLETE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                  fontFamily: 'Courier',
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeKeptImage() async {
    if (_lastCapturedBytes == null) return;
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
    });

    // Stage 1: OCR (simulate with short steps, weight 40%)
    for (int i = 0; i <= 40; i += 4) {
      await Future.delayed(const Duration(milliseconds: 60));
      setState(() {
        _analysisProgress = i / 100;
      });
    }

    // Real OCR: use platform OCR implementation
    String extracted = '';
    try {
      if (!kIsWeb && _lastCapturedPath != null) {
        extracted = await OCR.extractText(filePath: _lastCapturedPath);
      } else {
        extracted = await OCR.extractText(bytes: _lastCapturedBytes);
      }
    } catch (e) {
      extracted = '';
    }

    // Stage 2: Preprocessing (weight 20%)
    for (int i = 41; i <= 60; i += 3) {
      await Future.delayed(const Duration(milliseconds: 70));
      setState(() {
        _analysisProgress = i / 100;
      });
    }

    // Stage 3: Analysis (weight 40%) - call TextAnalyzer
    final toAnalyze = extracted.isNotEmpty ? extracted : 'image_capture_${DateTime.now().millisecondsSinceEpoch}';
    try {
      var result = await TextAnalyzer.analyzeText(toAnalyze);
      try {
        result = await applySensitivityToResult(result);
      } catch (_) {}
      _aiPct = result['ai_detection'] ?? 0.0;
      _humanPct = result['human_written'] ?? 0.0;
    } catch (e) {
      _aiPct = 0.0;
      _humanPct = 100.0;
    }

    // Simulate final progress ramp
    for (int i = 61; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() {
        _analysisProgress = i / 100;
      });
    }

    setState(() {
      _isAnalyzing = false;
      _analysisProgress = 1.0;
    });

    // show dialog with results
    if (!mounted) return;
    try {
      final notify = await SettingsManager.getNotifications();
      if (notify && mounted) {
        final msg = AppLocalizations.t('analysis_complete_message').replaceAll('{what}', 'camera capture');
        CyberNotification.show(context, AppLocalizations.t('analysis_complete_notification'), msg);
      }
    } catch (_) {}
    // save to history (Scan N)
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

    _showAnalysisDialog(_aiPct, _humanPct);
  }

  void _showAnalysisDialog(double aiPct, double humanPct) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade900.withOpacity(0.8), Colors.purple.shade900.withOpacity(0.8)],
            ),
            border: Border.all(color: Colors.cyan, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.cyan, Colors.pink]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.t('neural_analysis_complete'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyan.shade300),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    Text(AppLocalizations.t('ai_detection_label').replaceAll('{pct}', aiPct.toStringAsFixed(1)), style: TextStyle(color: aiPct > 50 ? Colors.red.shade300 : Colors.green.shade300, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.t('human_written_label').replaceAll('{pct}', humanPct.toStringAsFixed(1)), style: TextStyle(color: Colors.cyan.shade300)),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, side: const BorderSide(color: Colors.white24)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppLocalizations.t('close')),
                  ),
                ),
              ],
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

  Widget _buildControlButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.cyan.shade400, width: 1),
            gradient: LinearGradient(
              colors: [
                Colors.cyan.shade800.withAlpha((0.3 * 255).round()),
                Colors.blue.shade800.withAlpha((0.3 * 255).round()),
              ],
            ),
          ),
          child: Icon(icon, color: Colors.cyan.shade300, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBorders() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top border
          Positioned(
            top: 50,
            left: 50,
            right: 50,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom border
          Positioned(
            bottom: 50,
            left: 50,
            right: 50,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink,
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
}

class _CyberpunkBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.purple.shade900.withAlpha((0.06 * 255).round()),
          Colors.blue.shade900.withAlpha((0.04 * 255).round()),
          Colors.black,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Subtle grid lines
    final linePaint = Paint()
      ..color = Colors.cyan.withAlpha((0.04 * 255).round())
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Large faint circle for effect
    final circlePaint = Paint()
      ..color = Colors.pink.withAlpha((0.03 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), math.min(size.width, size.height) * 0.6, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha((0.02 * 255).round())
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}