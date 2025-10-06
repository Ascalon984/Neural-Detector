import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
// conditional import: use web helper when available
import '../utils/file_picker_stub.dart'
  if (dart.library.html) '../utils/file_picker_web.dart' as webpicker;
import 'dart:io' show File;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import '../utils/text_analyzer.dart';
import '../models/scan_history.dart' as Model;
import '../utils/history_manager.dart';
import '../utils/sensitivity.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/app_localizations.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scanAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  String? _selectedFileName;
  int? _selectedFileSize;
  DateTime? _selectedFileDate;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background dengan efek cyberpunk
          _buildCyberpunkBackground(),
          
          // Grid pattern overlay
          _buildGridPattern(),
          
          // Content utama
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan animasi
                  _buildHeader(),
                  
                  const SizedBox(height: 30),
                  
                  // Upload area utama
                  Expanded(
                    child: _buildUploadArea(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
          
          // Corner borders decorative
          _buildCornerBorders(),
        ],
      ),
    );
  }

  Widget _buildCyberpunkBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [
            Colors.black,
            Colors.purple.shade900.withOpacity(0.3),
            Colors.blue.shade900.withOpacity(0.1),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _CyberpunkBackgroundPainter(animation: _controller),
      ),
    );
  }

  Widget _buildGridPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
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
                        color: Colors.cyan.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              },
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t('file_upload_title'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.cyan.shade300,
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  'QUANTUM FILE PROCESSING',
                  style: TextStyle(
                    color: Colors.pink.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.5),
        
        const SizedBox(height: 10),
        
        const Text(
          'Upload documents for AI analysis and neural processing',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildUploadArea() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.5),
                width: 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.1),
                  Colors.purple.shade900.withOpacity(0.1),
                  Colors.black.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Scan line effect
                Positioned(
                  top: _scanAnimation.value * MediaQuery.of(context).size.height,
                  child: Container(
                    width: MediaQuery.of(context).size.width - 40,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.cyan.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Upload icon dengan animasi
                      _buildUploadIcon(),
                      
                      const SizedBox(height: 30),
                      
                      // File info atau placeholder
                      _buildFileInfo(),
                      
                      const SizedBox(height: 20),
                      
                      // Progress bar jika sedang upload
                      if (_isUploading) _buildProgressBar(),
                      
                      const SizedBox(height: 20),
                      
                      // Status indicator
                      _buildStatusIndicator(),
                    ],
                  ),
                ),
                
                // Corner accents
                ..._buildUploadAreaCorners(),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3);
  }

  Widget _buildUploadIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.cyan.withOpacity(0.3),
                Colors.pink.withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 80,
              height: 80,
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
                    color: Colors.cyan.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _selectedFileName != null ? Icons.description : Icons.cloud_upload,
                color: Colors.white,
                size: 40,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    return Column(
      children: [
        Text(
          _selectedFileName ?? AppLocalizations.t('upload_placeholder'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
            fontFamily: 'Courier',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (_selectedFileName != null) ...[
          Text(
            '${_formatBytes(_selectedFileSize ?? 0)} • ${_formatDate(_selectedFileDate)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            'Supported formats: PDF, DOC, DOCX, TXT',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.black.withOpacity(0.5),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  // Progress track
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.blue.shade900.withOpacity(0.3),
                    ),
                  ),
                  
                  // Progress bar
                  Container(
                    width: (MediaQuery.of(context).size.width - 100) * _uploadProgress,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Colors.cyan,
                          Colors.pink,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'PROCESSING: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    if (_selectedFileName == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            color: Colors.cyan.shade300,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'QUANTUM READY',
            style: TextStyle(
              color: Colors.cyan.shade300,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildUploadAreaCorners() {
    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink, width: 3),
              top: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink, width: 3),
              top: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink, width: 3),
              bottom: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink, width: 3),
              bottom: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildCyberButton(
            text: AppLocalizations.t('browse_files'),
            icon: Icons.folder_open,
            onPressed: _pickFile,
            colors: [Colors.blue.shade700, Colors.purple.shade700],
            fontSize: 12,
          ),
        ),
        if (_selectedFileName != null) ...[
          const SizedBox(width: 15),
          Expanded(
            child: _buildCyberButton(
                  text: _isUploading ? AppLocalizations.t('processing') : AppLocalizations.t('analyze'),
              icon: _isUploading ? Icons.hourglass_top : Icons.psychology,
              onPressed: _isUploading ? null : _analyzeFile,
              fontSize: _isUploading ? 12 : 14,
              colors: [Colors.cyan.shade700, Colors.pink.shade700],
            ),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5);
  }

  Widget _buildCyberButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required List<Color> colors,
    double fontSize = 14,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(_glowAnimation.value * 0.5),
                blurRadius: 10,
                spreadRadius: 2,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                        Text(
                          text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: fontSize,
                        letterSpacing: 1.2,
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

  Widget _buildCornerBorders() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top border
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
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
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
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

  void _pickFile() {
    () async {
      try {
        if (kIsWeb) {
          // Use native web picker helper to avoid double dialogs and get lastModified
          final info = await webpicker.pickFileWeb(accept: ['.pdf', '.doc', '.docx', '.txt']);
          if (info == null) return;

          final lm = info['lastModified'] as int?;
          DateTime? webModified;
          if (lm != null) webModified = DateTime.fromMillisecondsSinceEpoch(lm);

          setState(() {
            _selectedFileName = info['name'] as String?;
            _selectedFileSize = info['size'] as int?;
            _selectedFileDate = webModified;
          });
          // If auto-scan is enabled in settings, start analysis automatically (web)
          try {
            final auto = await SettingsManager.getAutoScan();
            if (auto && mounted) {
              _analyzeFile();
            }
          } catch (_) {}
          return;
        }

        // Non-web platforms: use FilePicker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'docm'],
          allowMultiple: false,
        );

        if (result == null || result.files.isEmpty) return;
        final picked = result.files.first;
        final filePath = picked.path;
        if (filePath == null) return;
        final file = File(filePath);
        final length = await file.length();
        DateTime? modified;
        try {
          modified = await file.lastModified();
        } catch (_) {
          modified = null;
        }

        setState(() {
          _selectedFileName = p.basename(filePath);
          _selectedFileSize = length;
          _selectedFileDate = modified;
        });

        // If auto-scan is enabled in settings, start analysis automatically
        try {
          final auto = await SettingsManager.getAutoScan();
          if (auto && mounted) {
            _analyzeFile();
          }
        } catch (_) {}
      } catch (e) {
        // ignore: avoid_print
        print('Error picking file: $e');
  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t('file_pick_failed').replaceAll('{err}', e.toString()))));
      }
    }();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = (math.log(bytes) / math.log(1024)).floor();
  if (i < 0) i = 0;
  if (i >= suffixes.length) i = suffixes.length - 1;
  final val = bytes / math.pow(1024, i);
    return '${val.toStringAsFixed(val >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _analyzeFile() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    // Simulate upload progress
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _uploadProgress = i / 100;
      });
    }
    
    setState(() {
      _isUploading = false;
    });
    
    // Run analyzer (we pass filename as placeholder text; replace with real text extractor later)
    Map<String, double> result = await TextAnalyzer.analyzeText(_selectedFileName ?? '');
    // apply sensitivity adjustment
    try {
      result = await applySensitivityToResult(result);
    } catch (_) {}

    final aiPct = (result['ai_detection'] ?? 0.0);
    final humanPct = (result['human_written'] ?? 0.0);

    // Save persistent history
    final sized = _selectedFileSize != null ? _formatBytes(_selectedFileSize!) : '-';
    final dateStr = _formatDate(_selectedFileDate);

    // compute sequential scan id (Scan 1, Scan 2, ...)
    final existing = await HistoryManager.loadHistory();
    final scanNumber = existing.length + 1;
    final entry = Model.ScanHistory(
      id: 'Scan $scanNumber',
      fileName: _selectedFileName ?? 'unknown',
      date: dateStr,
      aiDetection: aiPct.round(),
      humanWritten: humanPct.round(),
      status: 'Completed',
      fileSize: sized,
    );

    await HistoryManager.addEntry(entry);

    // show results with real values
    // show temporary notification if enabled
    try {
      final notify = await SettingsManager.getNotifications();
      if (notify && mounted) {
        final msg = AppLocalizations.t('analysis_complete_message').replaceAll('{what}', p.basename(_selectedFileName ?? 'file'));
        CyberNotification.show(context, AppLocalizations.t('analysis_complete_notification'), msg);
      }
    } catch (_) {}
    _showAnalysisResult(aiPct, humanPct);
  }

  void _showAnalysisResult(double aiPct, double humanPct) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900.withOpacity(0.8),
                Colors.purple.shade900.withOpacity(0.8),
              ],
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
                    gradient: LinearGradient(
                      colors: [Colors.cyan, Colors.pink],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.t('neural_analysis_complete'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan.shade300,
                    fontFamily: 'Courier',
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.t('ai_detection_label').replaceAll('{pct}', aiPct.toStringAsFixed(1)),
                        style: TextStyle(
                          color: aiPct > 50 ? Colors.red.shade300 : Colors.green.shade300,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppLocalizations.t('human_written_label').replaceAll('{pct}', humanPct.toStringAsFixed(1)),
                        style: TextStyle(
                          color: Colors.cyan.shade300,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildCyberButton(
                  text: AppLocalizations.t('close'),
                  icon: Icons.visibility,
                  onPressed: () => Navigator.pop(context),
                  colors: [Colors.cyan.shade700, Colors.pink.shade700],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberpunkBackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  _CyberpunkBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.purple.shade900.withOpacity(0.1),
          Colors.blue.shade900.withOpacity(0.1),
          Colors.black,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Animated lines
    final linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.2 * animation.value)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 25) {
      final x = i + animation.value * 25;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 0.5;

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