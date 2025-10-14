import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../widgets/main_shell.dart';
import 'dart:math' as math;

/// Splash screen that shows the cyberpunk background then navigates to MainShell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool _navigated = false;
  double _progress = 0;
  static const int durationMs = 2000;
  static const int updateIntervalMs = 50;
  late final int _steps;
  late final double _progressStep;
  late AnimationController _glowController;
  late AnimationController _hexagonController;
  late Animation<double> _glowAnimation;
  late Animation<double> _hexagonAnimation;

  @override
  void initState() {
    super.initState();
    _steps = (durationMs / updateIntervalMs).ceil();
    _progressStep = 100 / _steps;
    
    // Initialize glow animation for neon effect
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    // Initialize hexagon animation
    _hexagonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _hexagonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_hexagonController);
    
    _startProgress();
  }

  void _startProgress() {
    int tick = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: updateIntervalMs));
      if (!mounted || _navigated) return false;
      setState(() {
        _progress = (tick * _progressStep).clamp(0, 100);
      });
      tick++;
      if (tick > _steps) {
        _navigateToMain();
        return false;
      }
      return true;
    });
  }

  void _navigateToMain() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _hexagonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CyberPunkScreen(
    progress: _progress, 
    glowAnimation: _glowAnimation,
    hexagonAnimation: _hexagonAnimation,
  );
}

class CyberPunkScreen extends StatelessWidget {
  final double progress;
  final Animation<double> glowAnimation;
  final Animation<double> hexagonAnimation;
  
  const CyberPunkScreen({
    super.key, 
    this.progress = 0, 
    required this.glowAnimation,
    required this.hexagonAnimation
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0f0c29),
                  Color(0xFF302b63),
                  Color(0xFF24243e),
                  Color(0xFF1a1a2e),
                  Color(0xFF16213e),
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),
          
          // Animated hexagon grid overlay
          _buildHexagonGridOverlay(),
          
          // Neon effects
          _buildNeonEffects(),
          
          // Main content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo without any border or background
                _buildLogoContainer(),
                
                const SizedBox(height: 40),
                
                // Cyberpunk progress bar
                _buildCyberpunkProgressBar(),
                
                const SizedBox(height: 20),
                
                // Progress text
                Text(
                  'INITIALIZING SYSTEM... ${progress.toInt()}%',
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(glowAnimation.value),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoContainer() {
    return SizedBox(
      width: 160,
      height: 140,
      child: _RobustSplashImage(
        assetPath: 'assets/no_teks_2.png',
        fit: BoxFit.contain,
        fallbackWidget: _buildFallbackLogo(),
      ),
    );
  }

  Widget _buildHexagonGridOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: hexagonAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _HexagonGridPainter(hexagonAnimation.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildCyberpunkProgressBar() {
    return Container(
      width: 280,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Background track
          Container(
            width: double.infinity,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          // Progress fill with gradient
          Container(
            width: 280 * (progress / 100),
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                colors: [
                  Colors.cyan.withOpacity(0.8),
                  Colors.blue.withOpacity(0.8),
                  Colors.purple.withOpacity(0.8),
                ],
              ),
              // Glow effect for the progress bar
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          
          // Animated scan line effect
          Positioned(
            left: 280 * (progress / 100) - 20,
            top: 0,
            child: AnimatedBuilder(
              animation: glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 20,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(glowAnimation.value * 0.8),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return const Icon(
      Icons.security,
      color: Colors.white,
      size: 70,
    );
  }

  Widget _buildNeonEffects() {
    final size = MediaQueryData.fromWindow(WidgetsBinding.instance.window).size;

    return Stack(
      children: [
        // Cyan light
        Positioned(
          left: size.width * 0.2,
          top: size.height * 0.3,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x1A00FFFF).withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5],
              ),
            ),
          ),
        ),

        // Magenta light
        Positioned(
          right: size.width * 0.2,
          bottom: size.height * 0.3,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x1AFF00FF).withOpacity(0.1),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5],
              ),
            ),
          ),
        ),

        // Green light
        Positioned(
          left: size.width * 0.4,
          bottom: size.height * 0.2,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0x0D00FF00).withOpacity(0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget that tries to load an asset image with multiple fallback strategies
class _RobustSplashImage extends StatefulWidget {
  const _RobustSplashImage({
    Key? key,
    required this.assetPath,
    this.fit,
    required this.fallbackWidget,
  }) : super(key: key);

  final String assetPath;
  final BoxFit? fit;
  final Widget fallbackWidget;

  @override
  State<_RobustSplashImage> createState() => _RobustSplashImageState();
}

class _RobustSplashImageState extends State<_RobustSplashImage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // First check if the asset exists
      await rootBundle.load(widget.assetPath);
      
      // If we get here, the asset exists
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading image: $e');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.cyan,
          strokeWidth: 2,
        ),
      );
    }

    if (_hasError) {
      if (kDebugMode) {
        // In debug mode, show the error message
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            widget.fallbackWidget,
            const SizedBox(height: 8),
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      } else {
        // In release mode, just show the fallback
        return widget.fallbackWidget;
      }
    }

    // Try to load the image with multiple fallback strategies
    if (kIsWeb) {
      // For web, try multiple URL patterns
      return _buildWebImageWithFallbacks();
    } else {
      // For mobile/desktop, use standard asset loading
      return Image.asset(
        widget.assetPath,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            print('Error loading asset image: $error');
          }
          return widget.fallbackWidget;
        },
      );
    }
  }

  Widget _buildWebImageWithFallbacks() {
    // Try different URL patterns for web
    final List<String> possibleUrls = [
      widget.assetPath,
      '/${widget.assetPath}',
      '/assets/${widget.assetPath.split('/').last}',
      'assets/${widget.assetPath.split('/').last}',
    ];

    // Try the first URL
    return Image.network(
      possibleUrls.first,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          print('Error loading ${possibleUrls.first}: $error');
        }
        
        // Try the second URL
        if (possibleUrls.length > 1) {
          return Image.network(
            possibleUrls[1],
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) {
                print('Error loading ${possibleUrls[1]}: $error');
              }
              
              // Try the third URL
              if (possibleUrls.length > 2) {
                return Image.network(
                  possibleUrls[2],
                  fit: widget.fit,
                  errorBuilder: (context, error, stackTrace) {
                    if (kDebugMode) {
                      print('Error loading ${possibleUrls[2]}: $error');
                    }
                    
                    // Try the fourth URL
                    if (possibleUrls.length > 3) {
                      return Image.network(
                        possibleUrls[3],
                        fit: widget.fit,
                        errorBuilder: (context, error, stackTrace) {
                          if (kDebugMode) {
                            print('Error loading ${possibleUrls[3]}: $error');
                          }
                          // All URLs failed, show fallback
                          return widget.fallbackWidget;
                        },
                      );
                    } else {
                      // All URLs failed, show fallback
                      return widget.fallbackWidget;
                    }
                  },
                );
              } else {
                // All URLs failed, show fallback
                return widget.fallbackWidget;
              }
            },
          );
        } else {
          // All URLs failed, show fallback
          return widget.fallbackWidget;
        }
      },
    );
  }
}

// Custom painter for hexagon grid pattern
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
        
        // Add some animation by shifting hexagons
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