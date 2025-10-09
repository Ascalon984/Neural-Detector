import 'package:flutter/material.dart';
import '../config/animation_config.dart';
import 'dart:math' as math;
import '../utils/text_analyzer.dart';
import '../utils/sensitivity.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
// removed unused import '../utils/app_localizations.dart'

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _typingController;
  late AnimationController _rotateController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _textGlowAnimation;
  // removed unused animations: _textColorAnimation and _rotateAnimation

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _outerScrollController = ScrollController();
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  double _aiDetectionPercentage = 0.0;
  double _humanWrittenPercentage = 0.0;

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

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_backgroundController);

      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(
        begin: -0.2,
        end: 1.2,
      ).animate(CurvedAnimation(
        parent: _scanController,
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
        begin: 0.1,
        end: 0.3,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      // _textColorAnimation and _rotateAnimation removed; using glow controller only
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
      _textGlowAnimation = AlwaysStoppedAnimation(0.2);
  // _textColorAnimation and _rotateAnimation removed; using AlwaysStoppedAnimation where needed
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _typingController.dispose();
  _rotateController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    _editorScrollController.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
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
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
              child: ScrollConfiguration(
                behavior: const MaterialScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                child: SingleChildScrollView(
                  controller: _outerScrollController,
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: isSmallScreen ? 15 : 25),
                      _buildTextEditorArea(),
                      SizedBox(height: isSmallScreen ? 15 : 25),
                      _buildStatsBar(),
                      SizedBox(height: isSmallScreen ? 15 : 25),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
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
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
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
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
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

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.edit_document,
                color: Colors.white,
                size: 35,
              ),
            ),
            const SizedBox(width: 20),
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
                    child: const Text(
                      'EDITOR TEKS',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'MULAI DENGAN TEKS',
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextEditorArea() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
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
              borderRadius: BorderRadius.circular(25),
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
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Scan line inside editor
                if (AnimationConfig.enableBackgroundAnimations)
                  Positioned(
                    top: _scanAnimation.value * 300,
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
                
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Editor header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'INPUT TEKS',
                              style: TextStyle(
                                color: Colors.cyan.shade300,
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontFamily: 'Orbitron',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedBuilder(
                            animation: _glowAnimation,
                            builder: (context, child) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.cyan.withOpacity(_glowAnimation.value),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${_textController.text.length} Karakter',
                                  style: TextStyle(
                                    color: Colors.cyan.shade300,
                                    fontSize: isSmallScreen ? 10 : 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      
                      SizedBox(height: isSmallScreen ? 10 : 15),
                      
                      // Text field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: null,
                            expands: true,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 14 : 16,
                              fontFamily: 'Times New Roman',
                              shadows: [
                                Shadow(
                                  color: Colors.cyan.withOpacity(_textGlowAnimation.value),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            decoration: InputDecoration(
                              hintText: 'Mulai input teks...',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: isSmallScreen ? 12 : 14,
                                fontFamily: 'Times New Roman',
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(isSmallScreen ? 15 : 20),
                            ),
                            focusNode: _textFocusNode,
                            onChanged: (value) {
                              setState(() {});
                              _typingController.forward().then((_) {
                                _typingController.reset();
                              });
                              
                              // Scroll to keep editor visible
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                try {
                                  _outerScrollController.animateTo(
                                    _outerScrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                  );
                                } catch (_) {
                                  // Ignore if position isn't ready
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Corner accents
                ..._buildEditorCorners(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEditorCorners() {
    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
              top: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
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
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
              top: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
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
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
              bottom: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
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
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
              bottom: BorderSide(color: Colors.pink.withOpacity(_glowAnimation.value), width: 3),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildStatsBar() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900.withOpacity(0.3),
                Colors.purple.shade900.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: Colors.cyan.withOpacity(_glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('KATA', _countWords().toString(), Icons.text_fields, Colors.cyan, isSmallScreen),
              _buildStatItem('BARIS', _countLines().toString(), Icons.format_line_spacing, Colors.pink, isSmallScreen),
              _buildStatItem('KEPADATAN', '${_calculateDensity()}%', Icons.analytics, Colors.purple, isSmallScreen),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isSmallScreen) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: isSmallScreen ? 20 : 22),
        ),
        SizedBox(height: isSmallScreen ? 6 : 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            letterSpacing: 1,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 10 : 11,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Row(
      children: [
        Expanded(
          child: _buildCyberButton(
            text: 'HAPUS',
            icon: Icons.delete_sweep,
            onPressed: _clearText,
            color: Colors.red,
            isDisabled: _textController.text.isEmpty,
            isSmallScreen: isSmallScreen,
          ),
        ),
        SizedBox(width: isSmallScreen ? 10 : 15),
        Expanded(
          flex: 2,
          child: _buildCyberButton(
            text: _isAnalyzing ? 'MENGANALISIS...' : 'ANALISIS TEKS',
            icon: _isAnalyzing ? Icons.psychology : Icons.auto_awesome,
            onPressed: _textController.text.isEmpty ? null : _analyzeText,
            color: Colors.cyan,
            isAnalyzing: _isAnalyzing,
            isSmallScreen: isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildCyberButton({
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(isDisabled ? 0.1 : 0.3),
                color.withOpacity(isDisabled ? 0.05 : 0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(isDisabled ? 0.1 : _glowAnimation.value),
              width: 2,
            ),
            boxShadow: isDisabled ? [] : [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAnalyzing)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _analysisProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    else
                      Icon(icon, color: color, size: isSmallScreen ? 20 : 22),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isDisabled ? Colors.white30 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 12 : 14,
                          letterSpacing: 1.2,
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
      // Start progress animation
      for (int i = 0; i <= 90; i += 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _analysisProgress = i / 100;
        });
      }

      // Actual text analysis
      var result = await TextAnalyzer.analyzeText(_textController.text);
      try {
        result = await applySensitivityToResult(result);
      } catch (_) {}

      setState(() {
        _analysisProgress = 1.0;
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

  void _showAnalysisResult() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: isSmallScreen ? screenSize.width * 0.9 : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _aiDetectionPercentage > 50 
                  ? Colors.red.shade900.withOpacity(0.9)
                  : Colors.blue.shade900.withOpacity(0.9),
                _aiDetectionPercentage > 50
                  ? Colors.deepOrange.shade900.withOpacity(0.9)
                  : Colors.purple.shade900.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: _aiDetectionPercentage > 50 ? Colors.red : Colors.cyan,
              width: 2
            ),
            boxShadow: [
              BoxShadow(
                color: (_aiDetectionPercentage > 50 ? Colors.red : Colors.cyan).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSmallScreen ? 70 : 90,
                  height: isSmallScreen ? 70 : 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan,
                        Colors.pink,
                      ],
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
                  child: Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: isSmallScreen ? 35 : 45,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 15 : 25),
                Text(
                  'ANALISIS NEURAL SELESAI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan.shade300,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 15 : 20),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 15 : 20),
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
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_aiDetectionPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _aiDetectionPercentage > 50 ? Colors.red.shade300 : Colors.green.shade300,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ditulis Manusia:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${_humanWrittenPercentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: Colors.cyan.shade300,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 15 : 25),
                _buildCyberButton(
                  text: 'TUTUP',
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                  color: Colors.cyan,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _rotateController,
        builder: (context, child) {
          return CustomPaint(
            painter: _EditorParticlesPainter(_rotateController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

}

class _EditorParticlesPainter extends CustomPainter {
  final double animationValue;
  _EditorParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final random = math.Random(99);
    for (int i = 0; i < 18; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 2 + 0.8;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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