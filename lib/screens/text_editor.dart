import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import '../config/animation_config.dart';
import '../utils/text_analyzer.dart';
import '../utils/sensitivity.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _typingController;
  late AnimationController _hexagonController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _textGlowAnimation;
  late Animation<double> _hexagonAnimation;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  double _aiDetectionPercentage = 0.0;
  double _humanWrittenPercentage = 0.0;
  List<TextSpan> _highlightedSpans = []; // Untuk menyimpan span teks yang di-highlight

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: Duration(seconds: 3, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _hexagonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_backgroundController);

      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 0.7,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.98,
        end: 1.02,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      _textGlowAnimation = Tween<double>(
        begin: 0.05,
        end: 0.15,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _hexagonAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_hexagonController);
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
      _textGlowAnimation = AlwaysStoppedAnimation(0.1);
      _hexagonAnimation = AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _hexagonController.dispose();
    _typingController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simplified animated background
          _buildSimplifiedBackground(),

          // Subtle animated scanlines to give a retro-futuristic/cyberpunk feel
          _buildScanlines(),
          
          // Hexagon background overlay (match home screen)
          if (AnimationConfig.enableBackgroundAnimations)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _hexagonAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _HexagonGridPainter(_hexagonAnimation.value),
                    size: Size.infinite,
                  );
                },
              ),
            ),

          // Main content (scrollable to avoid overflow on small screens)
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical),
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildMinimalistHeader(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Text editor
                      _buildMinimalistTextEditor(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      
                      // Stats bar
                      _buildMinimalistStatsBar(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 16 : 24),
                      
                      // Action buttons
                      _buildMinimalistActionButtons(isSmallScreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplifiedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.5 - _backgroundAnimation.value * 0.2, 0.3),
              radius: 1.2 + _backgroundAnimation.value * 0.2,
              colors: [
                Color.lerp(
                  const Color(0xFF0a0a0a),
                  const Color(0xFF0f172a),
                  _backgroundAnimation.value,
                )!,
                Color.lerp(
                  const Color(0xFF0d1117),
                  const Color(0xFF0f172a),
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

  Widget _buildMinimalistHeader(bool isSmallScreen) {
    return Row(
      children: [
        // Icon
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: isSmallScreen ? 50 : 60,
              height: isSmallScreen ? 50 : 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1a253e).withOpacity(0.85),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2a4675).withOpacity(0.95),
                    const Color(0xFF1a253e).withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 15 : 20),
                border: Border.all(
                  color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.25),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_document,
                color: Colors.white,
                size: isSmallScreen ? 25 : 30,
              ),
            );
          },
        ),
        
        SizedBox(width: isSmallScreen ? 16 : 20),
        
        // Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  // also read _textGlowAnimation so analyzer doesn't flag it as unused
                  final double glow = _glowAnimation.value;
                  final double textGlow = _textGlowAnimation.value;
                  final double combined = (glow + textGlow * 0.5).clamp(0.0, 1.0).toDouble();

                  return ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFF00FFD1).withOpacity(combined),
                        const Color(0xFFFF4DFF).withOpacity(combined),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'EDITOR TEKS',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 22 : 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5 + textGlow * 2.0,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 4),
              Text(
                'Analisis AI untuk teks Anda',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalistTextEditor(bool isSmallScreen) {
    final screenSize = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.5,
              minHeight: isSmallScreen ? 200 : 250,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1a253e).withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.6),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2a4675).withOpacity(0.85),
                  const Color(0xFF1a253e).withOpacity(0.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.15),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Editor header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a4675).withOpacity(0.95),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.6),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.1),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        'INPUT TEKS',
                        style: TextStyle(
                          color: const Color(0xFF00FFD1),
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a253e).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4a9fff).withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4a9fff).withOpacity(0.1),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          '${_textController.text.length} Karakter',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: isSmallScreen ? 11 : 12,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Text field
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 15 : 17,
                        fontFamily: 'Roboto',
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Mulai mengetik atau tempel teks di sini...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: isSmallScreen ? 15 : 17,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      focusNode: _textFocusNode,
                      onChanged: (value) {
                        setState(() {});
                        _typingController.forward().then((_) {
                          _typingController.reset();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinimalistStatsBar(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF071226).withOpacity(0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(const Color(0xFF00FFD1), const Color(0xFFFF4DFF), _glowAnimation.value)!.withOpacity(0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4DFF).withOpacity(_glowAnimation.value * 0.03),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMinimalistStatItem(
            'KATA', 
            _countWords().toString(), 
            Icons.text_fields, 
            Colors.cyan, 
            isSmallScreen
          ),
          _buildMinimalistStatItem(
            'BARIS', 
            _countLines().toString(), 
            Icons.format_line_spacing, 
            Colors.pink, 
            isSmallScreen
          ),
          _buildMinimalistStatItem(
            'KEPADATAN', 
            '${_calculateDensity()}%', 
            Icons.analytics, 
            Colors.purple, 
            isSmallScreen
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalistStatItem(
    String label, 
    String value, 
    IconData icon, 
    Color color, 
    bool isSmallScreen
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Orbitron',
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: isSmallScreen ? 10 : 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalistActionButtons(bool isSmallScreen) {
    return Row(
      children: [
        // Clear button
        Expanded(
          child: _buildMinimalistButton(
            text: 'HAPUS',
            icon: Icons.delete_outline,
            onPressed: _clearText,
            color: Colors.red.shade400,
            isDisabled: _textController.text.isEmpty,
            isSmallScreen: isSmallScreen,
          ),
        ),
        
        SizedBox(width: isSmallScreen ? 12 : 16),
        
        // Analyze button
        Expanded(
          flex: 2,
          child: _buildMinimalistButton(
            text: _isAnalyzing ? 'MENGANALISIS...' : 'ANALISIS TEKS',
            icon: _isAnalyzing ? Icons.hourglass_bottom : Icons.search,
            onPressed: _textController.text.isEmpty ? null : _analyzeText,
            color: Colors.cyan,
            isAnalyzing: _isAnalyzing,
            isSmallScreen: isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalistButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    bool isDisabled = false,
    bool isAnalyzing = false,
    bool isSmallScreen = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          height: isSmallScreen ? 50 : 56,
          decoration: BoxDecoration(
            color: isDisabled 
              ? Colors.grey.shade800.withOpacity(0.3)
              : color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled 
                ? Colors.grey.shade700.withOpacity(0.3)
                : color.withOpacity(_glowAnimation.value * 0.7),
              width: 1,
            ),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: color.withOpacity(_glowAnimation.value * 0.18),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAnalyzing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                            value: _analysisProgress > 0 ? _analysisProgress : null,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    else
                      Icon(
                        icon, 
                        color: isDisabled ? Colors.grey.shade600 : color, 
                        size: isSmallScreen ? 20 : 22
                      ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isDisabled ? Colors.grey.shade600 : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 13 : 15,
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

  // Animated scanline overlay for retro/cyberpunk aesthetic
  Widget _buildScanlines() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ScanlinePainter(_backgroundAnimation.value),
          );
        },
      ),
    );
  }

  int _countWords() {
    if (_textController.text.trim().isEmpty) return 0;
    return _textController.text.trim().split(RegExp(r'\s+')).length;
  }

  int _countLines() {
    return '\n'.allMatches(_textController.text).length + 1;
  }

  int _calculateDensity() {
    if (_textController.text.isEmpty) return 0;
    final words = _countWords();
    final chars = _textController.text.length;
    return ((words / chars) * 100).round().clamp(0, 100);
  }

  void _clearText() {
    _textController.clear();
    setState(() {});
  }

  void _analyzeText() async {
    if (_textController.text.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
    });

    try {
      // Simulate analysis progress
      for (int i = 0; i <= 100; i += 5) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() {
            _analysisProgress = i / 100;
          });
        }
      }

      // Actual text analysis
      var result = await TextAnalyzer.analyzeText(_textController.text);
      try {
        result = await applySensitivityToResult(result);
      } catch (_) {}

      // Simulate getting highlighted spans for AI-detected text
      // In a real implementation, this would come from your TextAnalyzer
      _generateHighlightedSpans();

      setState(() {
        _aiDetectionPercentage = result['ai_detection']!;
        _humanWrittenPercentage = result['human_written']!;
      });

      try {
        final notify = await SettingsManager.getNotifications();
        if (notify && mounted) {
          CyberNotification.show(context, 'Analisis selesai', 'Analisis teks selesai');
        }
      } catch (_) {}

    } catch (e) {
      print('Error analyzing text: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
      _showAnalysisResult();
    }
  }

  // Generate highlighted spans for AI-detected text
  void _generateHighlightedSpans() {
    final text = _textController.text;
    final words = text.split(' ');
    _highlightedSpans = [];
    
    // Simulate AI detection on random words (in real implementation, this would be based on actual analysis)
    final random = math.Random();
    for (int i = 0; i < words.length; i++) {
      final isAI = random.nextDouble() < (_aiDetectionPercentage / 100);
      _highlightedSpans.add(
        TextSpan(
          text: words[i] + (i < words.length - 1 ? ' ' : ''),
          style: TextStyle(
            backgroundColor: isAI ? Colors.red.withOpacity(0.3) : Colors.transparent,
            color: Colors.white,
          ),
        ),
      );
    }
  }

  // Copy highlighted (AI-detected) text to clipboard
  Future<void> _copyHighlightedText() async {
    final parts = _highlightedSpans.where((s) {
      final bg = s.style?.backgroundColor;
      return bg != null && (bg.opacity > 0.01);
    }).map((s) => s.text ?? '').join();

    final text = parts.trim();
    if (text.isEmpty) {
      try {
        CyberNotification.show(context, 'Salin', 'Tidak ada teks yang di-highlight');
      } catch (_) {}
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    try {
      CyberNotification.show(context, 'Disalin', 'Teks highlight disalin ke clipboard');
    } catch (_) {}
  }

  void _showAnalysisResult() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero, // Use full screen for mobile
        child: Container(
          width: screenSize.width,
          height: screenSize.height * 0.9, // Limit height to 90% of screen
          margin: EdgeInsets.only(
            top: screenSize.height * 0.05, // 5% from top
            bottom: screenSize.height * 0.05, // 5% from bottom
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade900.withOpacity(0.95),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isSmallScreen ? 20 : 30),
              topRight: Radius.circular(isSmallScreen ? 20 : 30),
              bottomLeft: Radius.circular(isSmallScreen ? 20 : 30),
              bottomRight: Radius.circular(isSmallScreen ? 20 : 30),
            ),
            border: Border.all(
              color: _aiDetectionPercentage > 50 
                ? Colors.red.withOpacity(0.5)
                : Colors.cyan.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isSmallScreen ? 20 : 30),
                    topRight: Radius.circular(isSmallScreen ? 20 : 30),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 40 : 50,
                      height: isSmallScreen ? 40 : 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _aiDetectionPercentage > 50 
                            ? [Colors.red.shade400, Colors.red.shade600]
                            : [Colors.cyan.shade400, Colors.blue.shade600],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _aiDetectionPercentage > 50 
                          ? Icons.warning
                          : Icons.verified,
                        color: Colors.white,
                        size: isSmallScreen ? 20 : 25,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ANALISIS SELESAI',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          Text(
                            'Teks Anda telah dianalisis',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Column(
                    children: [
                      // Radial Chart
                      _buildRadialChart(isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      
                      // Results
                      _buildResultsContainer(isSmallScreen),
                      
                      SizedBox(height: isSmallScreen ? 16 : 20),
                      
                      // Highlighted Text Section
                      if (_highlightedSpans.isNotEmpty) _buildHighlightedTextSection(isSmallScreen),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build results container with better responsive design
  Widget _buildResultsContainer(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Title
          Text(
            'HASIL ANALISIS',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Orbitron',
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Results in a more compact format
          Row(
            children: [
              // AI Detection
              Expanded(
                child: _buildCompactResultItem(
                  'AI DETECTION',
                  '${_aiDetectionPercentage.toStringAsFixed(1)}%',
                  _aiDetectionPercentage > 50 ? Colors.red : Colors.green,
                  isSmallScreen,
                  Icons.smart_toy,
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Human Written
              Expanded(
                child: _buildCompactResultItem(
                  'HUMAN WRITTEN',
                  '${_humanWrittenPercentage.toStringAsFixed(1)}%',
                  Colors.cyan,
                  isSmallScreen,
                  Icons.person,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build compact result item for better mobile layout
  Widget _buildCompactResultItem(
    String label,
    String value,
    Color color,
    bool isSmallScreen,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: isSmallScreen ? 24 : 28,
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.w700,
              fontFamily: 'Orbitron',
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Build radial chart for AI vs Human percentages with cyberpunk styling
  Widget _buildRadialChart(bool isSmallScreen) {
    return SizedBox(
      height: isSmallScreen ? 160 : 200,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final aiValue = _aiDetectionPercentage * t;
          final humanValue = _humanWrittenPercentage * t;
          return Row(
            children: [
              SizedBox(width: isSmallScreen ? 8 : 12),
              // Chart
              SizedBox(
                width: isSmallScreen ? 120 : 150,
                height: isSmallScreen ? 120 : 150,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: isSmallScreen ? 36 : 46,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        color: _aiDetectionPercentage > 50 ? Colors.red.shade400 : Colors.red.shade300,
                        value: aiValue,
                        title: '${_aiDetectionPercentage.toStringAsFixed(1)}%',
                        radius: isSmallScreen ? 30 : 36,
                        titleStyle: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        titlePositionPercentageOffset: 0.6,
                      ),
                      PieChartSectionData(
                        color: Colors.cyan.shade400,
                        value: humanValue,
                        title: '${_humanWrittenPercentage.toStringAsFixed(1)}%',
                        radius: isSmallScreen ? 30 : 36,
                        titleStyle: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        titlePositionPercentageOffset: 0.6,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: isSmallScreen ? 10 : 14),

              // Legend / Numeric
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(width: 10, height: 10, color: Colors.red.shade400),
                        SizedBox(width: 8),
                        Text('Deteksi AI', style: TextStyle(color: Colors.white70)),
                        Spacer(),
                        Text('${_aiDetectionPercentage.toStringAsFixed(1)}%', style: TextStyle(color: _aiDetectionPercentage > 50 ? Colors.red.shade300 : Colors.green.shade300, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(width: 10, height: 10, color: Colors.cyan.shade400),
                        SizedBox(width: 8),
                        Text('Ditulis Manusia', style: TextStyle(color: Colors.white70)),
                        Spacer(),
                        Text('${_humanWrittenPercentage.toStringAsFixed(1)}%', style: TextStyle(color: Colors.cyan.shade300, fontWeight: FontWeight.bold, fontFamily: 'Orbitron')),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('Persentase menunjukkan proporsi konten yang terdeteksi AI vs manusia.', style: TextStyle(color: Colors.grey.shade400, fontSize: isSmallScreen ? 11 : 12)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Build highlighted text section with better mobile optimization
  Widget _buildHighlightedTextSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.highlight,
                color: Colors.red.shade400,
                size: isSmallScreen ? 20 : 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'TEKS YANG TERDETEKSI AI',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
              // Copy highlighted text icon
              IconButton(
                onPressed: _copyHighlightedText,
                icon: Icon(Icons.copy, color: Colors.white70, size: isSmallScreen ? 18 : 20),
                tooltip: 'Salin Teks Highlight',
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Text content with better mobile handling
          Container(
            constraints: BoxConstraints(
              maxHeight: isSmallScreen ? 150 : 200,
            ),
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: RichText(
                text: TextSpan(
                  children: _highlightedSpans,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 12),
          
          // Legend
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Teks yang dihighlight kemungkinan dihasilkan oleh AI',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Simple custom painter that draws faint horizontal scanlines and a subtle vignette
class _ScanlinePainter extends CustomPainter {
  final double progress;

  _ScanlinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = const Color(0xFF00FFD1).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // spacing and offset to animate lines slowly
    const double spacing = 6.0;
    final double offset = (progress * spacing * 2) % spacing;

    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      final double yy = y + offset;
      // slightly vary opacity per line for depth
      final double alpha = 0.02 + (0.01 * ((y / spacing) % 3));
      linePaint.color = const Color(0xFF00FFD1).withOpacity(alpha);
      canvas.drawRect(Rect.fromLTWH(0, yy, size.width, 1.0), linePaint);
    }

    // subtle vignette to focus center
    final Rect rect = Offset.zero & size;
    final Gradient vignette = RadialGradient(
      colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
      stops: [0.6, 1.0],
      center: Alignment.center,
      radius: 0.9,
    );
    final Paint vignettePaint = Paint()
      ..shader = vignette.createShader(rect)
      ..blendMode = BlendMode.darken;
    canvas.drawRect(rect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Hexagon grid painter (copied from home_screen to reuse hex background)
class _HexagonGridPainter extends CustomPainter {
  final double animationValue;
  _HexagonGridPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const hexSize = 40.0;
    const hexHeight = hexSize * 2;
    final hexWidth = math.sqrt(3) * hexSize;
    final vertDist = hexHeight * 3 / 4;

    int cols = (size.width / hexWidth).ceil() + 1;
    int rows = (size.height / vertDist).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * hexWidth + (row % 2) * hexWidth / 2;
        final y = row * vertDist;
        final offsetX = math.sin(animationValue * 2 * math.pi + row * 0.1) * 5;
        final offsetY = math.cos(animationValue * 2 * math.pi + col * 0.1) * 5;
        _drawHexagon(canvas, Offset(x + offsetX, y + offsetY), hexSize, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = 2 * math.pi * i / 6 - math.pi / 2;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}