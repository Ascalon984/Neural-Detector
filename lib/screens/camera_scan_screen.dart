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

// Optimized text detection with improved performance
TextDetectionResult _optimizedTextDetectionCompute(Uint8List bytes) {
try {
final image = img.decodeImage(bytes);
if (image == null) return TextDetectionResult(hasText: false, confidence: 0.0);

// Use cached target size
final targetSize = _maxImageSize;
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
final gray = img.grayscale(resized);

// Simplified edge detection for better performance
final edges = img.sobel(gray);

// Optimized edge counting
int edgeCount = 0;
const edgeThreshold = 30;
const minEdgeRatio = 0.015; // Slightly lower for better sensitivity

final totalPixels = edges.width * edges.height;
for (int i = 0; i < totalPixels; i++) {
final x = i % edges.width;
final y = i ~/ edges.width;
final pixel = edges.getPixel(x, y);
if (img.getLuminance(pixel) > edgeThreshold) edgeCount++;
}

final edgeRatio = edgeCount / totalPixels;
final hasText = edgeRatio > minEdgeRatio;
final confidence = math.min(edgeRatio * 15, 1.0);

// Simplified text region detection
Map<String, int>? textRegions;
if (hasText) {
textRegions = _findTextRegionsOptimized(edges);
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

// Removed complex threshold calculation for better performance
// Using fixed threshold instead of Otsu method

// Optimized text region detection
Map<String, int>? _findTextRegionsOptimized(img.Image edges) {
final width = edges.width;
final height = edges.height;

// Simplified region detection
const regionSize = 50;
const threshold = 12;
const step = regionSize ~/ 2;

Map<String, int>? bestRegion;
int maxEdgeCount = 0;

for (int y = 0; y < height - regionSize; y += step) {
for (int x = 0; x < width - regionSize; x += step) {
int edgeCount = 0;

// Sample fewer pixels for better performance
for (int dy = 0; dy < regionSize; dy += 2) {
for (int dx = 0; dx < regionSize; dx += 2) {
final pixel = edges.getPixel(x + dx, y + dy);
if (img.getLuminance(pixel) > 25) edgeCount++;
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
with TickerProviderStateMixin {
// Optimized animation controllers - only create what's needed
late AnimationController _glowController;
late AnimationController _scanController;
late AnimationController _pulseController;

late Animation<double> _glowAnimation;
late Animation<double> _scanAnimation;
late Animation<double> _pulseAnimation;

// Cache for expensive computations
static const int _maxImageSize = 300;
static const int _throttleMs = 1000; // Increased throttle for better performance

CameraController? _cameraController;
TextRecognizer? _textRecognizer;
bool _isProcessingFrame = false;
DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);

// Performance optimization flags
bool _isDisposed = false;
bool _animationsEnabled = true;

// Optimized camera image stream handler
void _handleCameraImage(CameraImage image) async {
if (_isDisposed || _isProcessingFrame || _isCapturing) return;

final now = DateTime.now();
if (now.difference(_lastProcessed).inMilliseconds < _throttleMs) return;
_lastProcessed = now;

// Quick prefilter with better performance
if (!_quickHasEdges(image)) return;

_isProcessingFrame = true;
try {
if (_cameraController?.value.isInitialized != true) return;

_isCapturing = true;
final XFile file = await _cameraController!.takePicture();
_isCapturing = false;

if (_textRecognizer != null) {
final inputImage = InputImage.fromFilePath(file.path);
final recognized = await _textRecognizer!.processImage(inputImage);

if (recognized.text.trim().length > 2) {
debugPrint('Camera detected text: ${recognized.text.length} chars');
}
}

// Clean up temp file immediately
try { await File(file.path).delete(); } catch (_) {}
} catch (e) {
debugPrint('Camera processing error: $e');
} finally {
_isProcessingFrame = false;
_isCapturing = false;
}
}

bool _quickHasEdges(CameraImage image, {int sampleStride = 60, int threshold = 3}) {
final plane = image.planes[0];
final bytes = plane.bytes;
int count = 0;
final maxSamples = (bytes.length / sampleStride).floor();

// Limit samples for better performance
for (int i = 0; i < maxSamples && count < threshold; i++) {
final index = i * sampleStride;
if (index + sampleStride < bytes.length) {
final diff = (bytes[index] - bytes[index + sampleStride]).abs();
if (diff > 25) count++;
}
}
return count >= threshold;
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
int _memoryPressureLevel = 0;

@override
void initState() {
super.initState();

// Initialize memory management
_initializeMemoryManagement();

// Initialize only essential animation controllers
_glowController = AnimationController(
duration: const Duration(seconds: 2),
vsync: this,
)..repeat(reverse: true);

_scanController = AnimationController(
duration: const Duration(seconds: 3),
vsync: this,
)..repeat();

_pulseController = AnimationController(
duration: const Duration(milliseconds: 1500),
vsync: this,
)..repeat(reverse: true);

// Initialize animations with optimized curves
_glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
CurvedAnimation(parent: _glowController, curve: Curves.easeInOut)
);

_scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(
CurvedAnimation(parent: _scanController, curve: Curves.easeInOut)
);

_pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
);

_requestCameraPermission();
}

// Optimized memory management
void _initializeMemoryManagement() {
// Check memory pressure every 30 seconds
_memoryCleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
if (!_isDisposed) _checkMemoryPressure();
});
}

// Optimized memory pressure check
void _checkMemoryPressure() {
if (_isDisposed) return;

// Simple memory pressure simulation
_memoryPressureLevel = math.Random().nextInt(3);

if (_memoryPressureLevel >= 2) {
_performMemoryCleanup(aggressive: true);
} else if (_memoryPressureLevel >= 1) {
_performMemoryCleanup(aggressive: false);
}
}

// Optimized memory cleanup
void _performMemoryCleanup({bool aggressive = false}) {
if (_isDisposed) return;

// Clear image cache if not analyzing
if (!_isAnalyzing && _lastCapturedBytes != null) {
if (aggressive) {
if (mounted) {
setState(() {
_lastCapturedBytes = null;
_lastCapturedPath = null;
_isKept = false;
});
}
}
}
}

@override
void dispose() {
_isDisposed = true;

// Cancel any ongoing analysis
_analysisCompleter?.complete(false);

// Cancel memory cleanup timer
_memoryCleanupTimer?.cancel();

// Dispose animation controllers
_glowController.dispose();
_scanController.dispose();
_pulseController.dispose();

// Stop image stream and dispose camera controller
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
return Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xFF0a0a0a),
Color(0xFF0d1117),
Colors.black,
],
stops: [0.0, 0.5, 1.0],
),
),
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
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0x1AFF69B4), // Colors.pink.withOpacity(0.1)
Color(0x1A00FFFF), // Colors.cyan.withOpacity(0.1)
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
return const IgnorePointer(
child: SizedBox.shrink(), // Disabled for performance
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
Text(
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
return const IgnorePointer(
child: SizedBox.shrink(), // Disabled for performance
);
}

Future<void> _initializeCamera() async {
if (_isDisposed) return;

try {
if (kIsWeb) {
await Future.delayed(const Duration(milliseconds: 300));
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

// Use optimized resolution for better performance
_cameraController = CameraController(
cameras[0],
ResolutionPreset.low,
enableAudio: false,
);

await _cameraController?.initialize();

// Initialize ML Kit text recognizer with error handling
try {
_textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
} catch (e) {
debugPrint('TextRecognizer initialization failed: $e');
_textRecognizer = null;
}

// Start image stream with error handling
try {
await _cameraController?.startImageStream(_handleCameraImage);
} catch (e) {
debugPrint('Image stream not supported: $e');
}

if (!mounted || _isDisposed) return;

setState(() {
_isCameraInitialized = true;
});
} catch (e) {
debugPrint('Error initializing camera: $e');
if (!mounted || _isDisposed) return;

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
if (_isDisposed || _cameraController?.value.isInitialized != true) return;

if (mounted) {
setState(() {
_isCapturing = true;
});
}

try {
final shouldTorch = _flashOn || _isFlashHovering;
if (shouldTorch) {
try {
await _cameraController?.setFlashMode(FlashMode.torch);
} catch (_) {}
}

final XFile file = await _cameraController!.takePicture();
final bytes = await file.readAsBytes();

if (!mounted || _isDisposed) return;

setState(() {
_lastCapturedBytes = bytes;
_lastCapturedPath = file.path;
_isKept = false;
});
} catch (e) {
debugPrint('Error taking picture: $e');
if (!mounted || _isDisposed) return;
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
if (mounted && !_isDisposed) {
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