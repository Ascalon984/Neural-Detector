import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/text_analyzer.dart';
import '../utils/sensitivity.dart';
import '../utils/settings_manager.dart';
import '../widgets/cyber_notification.dart';
import '../utils/app_localizations.dart';

class TextEditorScreen extends StatefulWidget {
  const TextEditorScreen({super.key});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _scanAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _textGlowAnimation;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final GlobalKey _editorKey = GlobalKey();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _outerScrollController = ScrollController();
  bool _isAnalyzing = false;
  double _analysisProgress = 0.0;
  double _aiDetectionPercentage = 0.0;
  double _humanWrittenPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    
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

      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.98,
        end: 1.02,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _textGlowAnimation = Tween<double>(
        begin: 0.1,
        end: 0.3,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.3);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
      _textGlowAnimation = AlwaysStoppedAnimation(0.1);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      body: Stack(
        children: [
          // Background dengan efek cyberpunk
          _buildCyberpunkBackground(),
          
          // Grid pattern overlay
          _buildGridPattern(),
          
          // Scan line effect
          _buildScanLine(),
          
          // Content utama
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                controller: _outerScrollController,
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header dengan animasi
                    _buildHeader(),

                    const SizedBox(height: 18),

                    // Text editor area (not expanded so keyboard won't cover it)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                        minHeight: 200,
                      ),
                      child: _buildTextEditorArea(),
                    ),

                    const SizedBox(height: 20),

                    // Stats bar
                    _buildStatsBar(),

                    const SizedBox(height: 20),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
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
      child: AnimationConfig.enableBackgroundAnimations
          ? CustomPaint(
              painter: _CyberpunkBackgroundPainter(
                animation: _controller ?? AlwaysStoppedAnimation(0.0),
              ),
            )
          : null,
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

  Widget _buildScanLine() {
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Positioned(
          top: _scanAnimation.value * MediaQuery.of(context).size.height,
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: 1,
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
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _controller ?? AlwaysStoppedAnimation(0.0),
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
                    Icons.edit_document,
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppLocalizations.t('neural_editor'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyan.shade300,
                      letterSpacing: 2,
                                  fontFamily: AppTheme.defaultFontFamily,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'REAL-TIME AI ANALYSIS',
                    style: TextStyle(
                      color: Colors.pink.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        const Text(
          'Type or paste text for quantum neural analysis',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildTextEditorArea() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
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
                // Scan line inside editor
                Positioned(
                  top: _scanAnimation.value * 300,
                  child: Container(
                    width: MediaQuery.of(context).size.width - 40,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.cyan.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Editor header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'QUANTUM TEXT INPUT',
                              style: TextStyle(
                                color: Colors.cyan.shade300,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                fontFamily: 'Courier',
                              ),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _controller ?? AlwaysStoppedAnimation(0.0),
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
                                  '${_textController.text.length} CHARS',
                                  style: TextStyle(
                                    color: Colors.cyan.shade300,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Courier',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Text field
                        Expanded(
                          child: Container(
                          key: _editorKey,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
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
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.cyan.withOpacity(_textGlowAnimation.value),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Begin typing or paste text for neural analysis...\n\n• Real-time AI detection\n• Quantum processing\n• Neural network analysis',
                              hintStyle: TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(20),
                            ),
                            focusNode: _textFocusNode,
                            onChanged: (value) {
                              setState(() {});
                              // scroll the outer SingleChildScrollView to keep editor visible
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                try {
                                  _outerScrollController.animateTo(
                                    _outerScrollController.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                  );
                                } catch (_) {
                                  // ignore if position isn't ready
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

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900.withOpacity(0.3),
            Colors.purple.shade900.withOpacity(0.3),
          ],
        ),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('WORDS', _countWords().toString(), Icons.text_fields),
          _buildStatItem('LINES', _countLines().toString(), Icons.format_line_spacing),
          _buildStatItem('DENSITY', '${_calculateDensity()}%', Icons.analytics),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.cyan.shade300, size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildCyberButton(
            text: 'CLEAR ALL',
            icon: Icons.delete_sweep,
            onPressed: _clearText,
            color: Colors.red,
            isDisabled: _textController.text.isEmpty,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 2,
          child: _buildCyberButton(
            text: _isAnalyzing ? 'ANALYZING...' : 'QUANTUM ANALYSIS',
            icon: _isAnalyzing ? Icons.psychology : Icons.auto_awesome,
            onPressed: _textController.text.isEmpty ? null : _analyzeText,
            color: Colors.cyan,
            isAnalyzing: _isAnalyzing,
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
  }) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
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
                color: color.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isAnalyzing)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _analysisProgress,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    else
                      Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: TextStyle(
                        color: isDisabled ? Colors.white30 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

      // Actual text analysis (use centralized TextAnalyzer which routes based on sensitivity)
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
          CyberNotification.show(context, 'Analysis complete', 'Text analysis finished');
        }
      } catch (_) {}

    } catch (e) {
      print('Error analyzing text: $e');
      // Show error dialog if needed
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
      _showAnalysisResult();
    }
  }

  void _showAnalysisResult() {
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
          ),
          child: Padding(
            padding: const EdgeInsets.all(25),
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
                  'NEURAL ANALYSIS COMPLETE',
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
                        'AI Detection: ${_aiDetectionPercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Human Written: ${_humanWrittenPercentage.toStringAsFixed(1)}%',
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
                  text: 'CLOSE',
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                  color: Colors.cyan,
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