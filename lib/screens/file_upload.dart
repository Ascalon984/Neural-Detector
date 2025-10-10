import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../config/animation_config.dart';
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

  String? _selectedFileName;
  int? _selectedFileSize;
  DateTime? _selectedFileDate;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Initialize multiple animation controllers for different effects
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
    
    // Initialize animation objects (use AlwaysStoppedAnimation when animations are disabled)
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
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isVerySmallScreen = screenSize.width < 360;
    
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
                final screenHeight = constraints.maxHeight;
                
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Padding(
                      padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isVerySmallScreen, isSmallScreen),
                          SizedBox(height: isVerySmallScreen ? 15 : 20),
                          SizedBox(
                            height: screenHeight * 0.5,
                            child: _buildUploadArea(isVerySmallScreen, isSmallScreen),
                          ),
                          SizedBox(height: isVerySmallScreen ? 15 : 20),
                          _buildActionButtons(isVerySmallScreen, isSmallScreen),
                        ],
                      ),
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

  Widget _buildHeader(bool isVerySmallScreen, bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: isVerySmallScreen ? 40 : isSmallScreen ? 50 : 60,
              height: isVerySmallScreen ? 40 : isSmallScreen ? 50 : 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.cloud_upload,
                color: Colors.white,
                size: isVerySmallScreen ? 20 : isSmallScreen ? 25 : 30,
              ),
            ),
            SizedBox(width: isVerySmallScreen ? 12 : 15),
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
                      'UNGGAH FILE',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 16 : isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: isVerySmallScreen ? 1 : 2,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 2 : 3),
                  Text(
                    'PEMROSESAN FILE',
                    style: TextStyle(
                      color: Colors.pink.shade300,
                      fontSize: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: isVerySmallScreen ? 1 : 2,
                      fontFamily: 'Courier',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.5);
      },
    );
  }

  Widget _buildUploadArea(bool isVerySmallScreen, bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isVerySmallScreen ? 15 : isSmallScreen ? 20 : 25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.2),
                  Colors.purple.shade900.withOpacity(0.2),
                  Colors.black.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: Colors.cyan.withOpacity(_glowAnimation.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                  blurRadius: isVerySmallScreen ? 15 : isSmallScreen ? 20 : 25,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Scan line inside upload area
                Positioned(
                  top: _scanAnimation.value * 400,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.cyan.withOpacity(0.6),
                          Colors.pink.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: EdgeInsets.all(isVerySmallScreen ? 15 : isSmallScreen ? 20 : 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Upload icon with animation
                      _buildUploadIcon(isVerySmallScreen, isSmallScreen),
                      
                      SizedBox(height: isVerySmallScreen ? 15 : 20),
                      
                      // File info or placeholder
                      _buildFileInfo(isVerySmallScreen, isSmallScreen),
                      
                      SizedBox(height: isVerySmallScreen ? 12 : 15),
                      
                      // Progress bar if uploading
                      if (_isUploading) _buildProgressBar(isVerySmallScreen, isSmallScreen),
                      
                      SizedBox(height: isVerySmallScreen ? 12 : 15),
                      
                      // Status indicator
                      _buildStatusIndicator(isVerySmallScreen, isSmallScreen),
                    ],
                  ),
                ),
                
                // Corner accents
                ..._buildUploadAreaCorners(isVerySmallScreen, isSmallScreen),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3);
  }

  Widget _buildUploadIcon(bool isVerySmallScreen, bool isSmallScreen) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: isVerySmallScreen ? 80 : isSmallScreen ? 100 : 120,
              height: isVerySmallScreen ? 80 : isSmallScreen ? 100 : 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    Colors.pink.withOpacity(_glowAnimation.value * 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            );
          },
        ),
        
        // Rotating ring
        AnimatedBuilder(
          animation: _rotateController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotateController.value * 2 * math.pi,
              child: Container(
                width: isVerySmallScreen ? 70 : isSmallScreen ? 85 : 100,
                height: isVerySmallScreen ? 70 : isSmallScreen ? 85 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
            );
          },
        ),
        
        // Main icon container
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: isVerySmallScreen ? 50 : isSmallScreen ? 65 : 80,
              height: isVerySmallScreen ? 50 : isSmallScreen ? 65 : 80,
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
                    blurRadius: isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                _selectedFileName != null ? Icons.description : Icons.cloud_upload,
                color: Colors.white,
                size: isVerySmallScreen ? 25 : isSmallScreen ? 32 : 40,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFileInfo(bool isVerySmallScreen, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          _selectedFileName ?? 'KLIK UNTUK MENGUNGGAH',
          style: TextStyle(
            fontSize: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: isVerySmallScreen ? 0.8 : 1,
            fontFamily: 'Orbitron',
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        if (_selectedFileName != null) ...[
          Text(
            '${_formatBytes(_selectedFileSize ?? 0)} • ${_formatDate(_selectedFileDate)}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          Text(
            'MENDUKUNG: PDF, DOC, DOCX, TXT',
            style: TextStyle(
              color: Colors.cyan.shade300,
              fontSize: isVerySmallScreen ? 10 : isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w300,
              letterSpacing: isVerySmallScreen ? 0.8 : 1,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(bool isVerySmallScreen, bool isSmallScreen) {
    return Column(
      children: [
        Container(
          height: isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 2 : isSmallScreen ? 3 : 4),
            color: Colors.black.withOpacity(0.5),
          ),
          child: Stack(
            children: [
              // Progress track
              Container(
                width: double.infinity,
                height: isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 2 : isSmallScreen ? 3 : 4),
                  color: Colors.blue.shade900.withOpacity(0.3),
                ),
              ),
              
              // Progress bar
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: (MediaQuery.of(context).size.width - (isVerySmallScreen ? 60 : isSmallScreen ? 80 : 100)) * _uploadProgress,
                    height: isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isVerySmallScreen ? 2 : isSmallScreen ? 3 : 4),
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(_glowAnimation.value),
                          Colors.pink.withOpacity(_glowAnimation.value),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                          blurRadius: isVerySmallScreen ? 4 : isSmallScreen ? 6 : 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        SizedBox(height: isVerySmallScreen ? 6 : 8),
        Text(
          'SEDANG MEMPROSES: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: isVerySmallScreen ? 9 : isSmallScreen ? 11 : 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            letterSpacing: isVerySmallScreen ? 0.8 : 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(bool isVerySmallScreen, bool isSmallScreen) {
    if (_selectedFileName == null) return const SizedBox();
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVerySmallScreen ? 12 : isSmallScreen ? 15 : 18, 
            vertical: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
            border: Border.all(
              color: Colors.cyan.withOpacity(_glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: isVerySmallScreen ? 6 : isSmallScreen ? 8 : 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified,
                color: Colors.cyan.shade300,
                size: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
              ),
              SizedBox(width: isVerySmallScreen ? 4 : 6),
              Text(
                'Berhasil Di unggah',
                style: TextStyle(
                  color: Colors.cyan.shade300,
                  fontSize: isVerySmallScreen ? 9 : isSmallScreen ? 11 : 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Orbitron',
                  letterSpacing: isVerySmallScreen ? 0.8 : 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildUploadAreaCorners(bool isVerySmallScreen, bool isSmallScreen) {
    final cornerSize = isVerySmallScreen ? 20.0 : isSmallScreen ? 25.0 : 30.0;
    final borderWidth = isVerySmallScreen ? 2.0 : isSmallScreen ? 2.5 : 3.0;
    
    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: _buildCornerWidget(true, true, cornerSize, borderWidth),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: _buildCornerWidget(false, true, cornerSize, borderWidth),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: _buildCornerWidget(true, false, cornerSize, borderWidth),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: _buildCornerWidget(false, false, cornerSize, borderWidth),
      ),
    ];
  }

  Widget _buildCornerWidget(bool isLeft, bool isTop, double size, double borderWidth) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              left: isLeft
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: borderWidth)
                  : BorderSide.none,
              right: !isLeft
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: borderWidth)
                  : BorderSide.none,
              top: isTop
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: borderWidth)
                  : BorderSide.none,
              bottom: !isTop
                  ? BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: borderWidth)
                  : BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(bool isVerySmallScreen, bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: _buildCyberButton(
            text: 'BUKA',
            icon: Icons.folder_open,
            onPressed: _pickFile,
            color: Colors.blue,
            isVerySmallScreen: isVerySmallScreen,
            isSmallScreen: isSmallScreen,
          ),
        ),
        if (_selectedFileName != null) ...[
          SizedBox(width: isVerySmallScreen ? 8 : 10),
          Expanded(
            child: _buildCyberButton(
              text: _isUploading ? 'MEMPROSES' : 'ANALISIS',
              icon: _isUploading ? Icons.hourglass_top : Icons.psychology,
              onPressed: _isUploading ? null : _analyzeFile,
              color: Colors.cyan,
              isAnalyzing: _isUploading,
              isVerySmallScreen: isVerySmallScreen,
              isSmallScreen: isSmallScreen,
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
    required Color color,
    bool isAnalyzing = false,
    bool isVerySmallScreen = false,
    bool isSmallScreen = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
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
                blurRadius: isVerySmallScreen ? 8 : isSmallScreen ? 10 : 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 12 : isSmallScreen ? 15 : 18, 
                  vertical: isVerySmallScreen ? 12 : isSmallScreen ? 14 : 16
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAnalyzing)
                      SizedBox(
                        width: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                        height: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _uploadProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    else
                      Icon(icon, color: color, size: isVerySmallScreen ? 16 : isSmallScreen ? 18 : 20),
                    SizedBox(width: isVerySmallScreen ? 6 : 8),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmallScreen ? 11 : isSmallScreen ? 13 : 15,
                          letterSpacing: isVerySmallScreen ? 0.8 : 1,
                          fontFamily: 'Orbitron',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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

          if (mounted) {
            setState(() {
              _selectedFileName = info['name'] as String?;
              _selectedFileSize = info['size'] as int?;
              _selectedFileDate = webModified;
            });
          }
          
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

        if (mounted) {
          setState(() {
            _selectedFileName = p.basename(filePath);
            _selectedFileSize = length;
            _selectedFileDate = modified;
          });
        }

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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.t('file_pick_failed').replaceAll('{err}', e.toString())))
          );
        }
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
    if (!mounted) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    // Simulate upload progress
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _uploadProgress = i / 100;
      });
    }
    
    if (!mounted) return;
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
    
    if (mounted) {
      _showAnalysisResult(aiPct, humanPct);
    }
  }

  void _showAnalysisResult(double aiPct, double humanPct) {
    if (!mounted) return;
    
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isVerySmallScreen = screenSize.width < 360;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 16 : 20),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.9,
            maxHeight: screenSize.height * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isVerySmallScreen ? 15 : isSmallScreen ? 20 : 25),
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
              padding: EdgeInsets.all(isVerySmallScreen ? 15 : isSmallScreen ? 20 : 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isVerySmallScreen ? 60 : isSmallScreen ? 70 : 80,
                    height: isVerySmallScreen ? 60 : isSmallScreen ? 70 : 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.pink],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: isVerySmallScreen ? 30 : isSmallScreen ? 35 : 40,
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 15 : 20),
                  Text(
                    'ANALISIS SELESAI',
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade300,
                      fontFamily: 'Orbitron',
                      letterSpacing: isVerySmallScreen ? 0.8 : 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isVerySmallScreen ? 12 : 15),
                  Container(
                    padding: EdgeInsets.all(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : isSmallScreen ? 15 : 20),
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
                                fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isVerySmallScreen ? 10 : 12),
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
                                fontSize: isVerySmallScreen ? 14 : isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 15 : 20),
                  _buildCyberButton(
                    text: 'TUTUP',
                    icon: Icons.close,
                    onPressed: () => Navigator.pop(context),
                    color: Colors.cyan,
                    isVerySmallScreen: isVerySmallScreen,
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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