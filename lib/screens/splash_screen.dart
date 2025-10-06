import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../widgets/main_shell.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;
  late Animation<double> _particles;
  late Animation<double> _glow;
  late Animation<double> _scan;

  @override
  void initState() {
    super.initState();
    
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(milliseconds: 3500),
        vsync: this,
      );

      _logoScale = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ));

      _logoRotation = Tween<double>(
        begin: -0.2,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutBack),
      ));

      _textOpacity = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ));

      _textSlide = Tween<double>(
        begin: 100.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ));

      _particles = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ));

      _glow = Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _scan = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.linear,
      ));
    } else {
      _logoScale = AlwaysStoppedAnimation(1.0);
      _logoRotation = AlwaysStoppedAnimation(0.0);
      _textOpacity = AlwaysStoppedAnimation(1.0);
      _textSlide = AlwaysStoppedAnimation(0.0);
      _particles = AlwaysStoppedAnimation(1.0);
      _glow = AlwaysStoppedAnimation(0.3);
      _scan = AlwaysStoppedAnimation(0.0);
    }

    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller?.forward();
      await Future.delayed(const Duration(milliseconds: 4000));
    } else {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const MainShell(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = Curves.easeInOutQuart;
          var tween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
          
          return FadeTransition(
            opacity: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      body: Stack(
        children: [
          // Cyberpunk Background
          _buildCyberpunkBackground(),
          
          // Grid Pattern
          _buildGridPattern(),
          
          // Animated Particles
          _buildParticles(),
          
          // Scan Line
          _buildScanLine(),
          
          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                _buildAnimatedLogo(),
                
                const SizedBox(height: 40),
                
                // Animated Text Content
                _buildTextContent(),
                
                const SizedBox(height: 60),
                
                // Loading Progress
                _buildLoadingIndicator(),
                
                const SizedBox(height: 20),
                
                // Version Info
                _buildVersionInfo(),
              ],
            ),
          ),
          
          // Corner Borders
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
            Colors.black,
            Colors.purple.shade900.withOpacity(0.4),
            Colors.blue.shade900.withOpacity(0.2),
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
        opacity: 0.06,
        child: CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildParticles() {
    return AnimatedBuilder(
      animation: _particles,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlesPainter(animation: _particles),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scan,
      builder: (context, child) {
        return Positioned(
          top: _scan.value * MediaQuery.of(context).size.height,
          child: Container(
            width: MediaQuery.of(context).size.width,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(_logoScale.value)
            ..rotateZ(_logoRotation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withOpacity(_glow.value * 0.3),
                      Colors.pink.withOpacity(_glow.value * 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Main Logo Container
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.cyan.withOpacity(0.8),
                      Colors.purple.withOpacity(0.8),
                      Colors.pink.withOpacity(0.8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(_glow.value * 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: Colors.pink.withOpacity(_glow.value * 0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Inner Glow
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    
                    // Logo Icon
                    const Center(
                      child: Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                    
                    // Animated Rings
                    if (AnimationConfig.enableBackgroundAnimations)
                      CustomPaint(
                        painter: _LogoRingsPainter(
                          animation: _controller ?? AlwaysStoppedAnimation(0.0),
                        ),
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

  Widget _buildTextContent() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: Transform.translate(
            offset: Offset(0, _textSlide.value),
            child: Column(
              children: [
                // Main Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Colors.cyan,
                      Colors.pink,
                      Colors.purple,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'NEURAL',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        fontFamily: 'Courier',
                        shadows: [
                          Shadow(
                            color: Colors.cyan.withOpacity(0.5),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Colors.pink,
                      Colors.purple,
                      Colors.cyan,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    'DETECTOR',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      fontFamily: 'Courier',
                      shadows: [
                        Shadow(
                          color: Colors.pink.withOpacity(0.5),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'PROFESSIONAL EDITION',
                  style: TextStyle(
                    color: Colors.cyan.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    fontFamily: 'Courier',
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'QUANTUM AI TEXT ANALYSIS SYSTEM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                
                const SizedBox(height: 5),
                
                const Text(
                  'Advanced Neural Network Technology',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final progress = (_controller?.value ?? 1.0).clamp(0.0, 1.0);
        
        return Column(
          children: [
            // Progress Bar Container
            Container(
              width: 250,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Colors.cyan.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Progress Track
                  Container(
                    width: 250 * progress,
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
                  
                  // Animated Glow
                  Container(
                    width: 250 * progress,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(_glow.value),
                          Colors.pink.withOpacity(_glow.value),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Loading Text
            Text(
              'INITIALIZING NEURAL NETWORK...',
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontSize: 10,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                fontFamily: 'Courier',
              ),
            ),
            
            Text(
              '${(progress * 100).toInt()}% COMPLETE',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'Courier',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVersionInfo() {
    return AnimatedBuilder(
      animation: _textOpacity,
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: const Column(
            children: [
              Text(
                'v3.2.1 • QUANTUM EDITION',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '© 2024 NEURAL SYSTEMS',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCornerBorders() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top Border
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
          // Bottom Border
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

    // Animated Lines
    final linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.15 * animation.value)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 25) {
      final x = i + animation.value * 25;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Pulse Circles
    final circlePaint = Paint()
      ..color = Colors.pink.withOpacity(0.05 * (1 - animation.value))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.2),
      50 + animation.value * 100,
      circlePaint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.8),
      30 + animation.value * 80,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Simple placeholder HomeScreen so the splash screen can navigate to a valid widget.
// Replace or move this into its own file as needed for your app structure.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: const Center(
        child: Text(
          'Welcome to the Home Screen',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.08)
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

class _ParticlesPainter extends CustomPainter {
  final Animation<double> animation;

  _ParticlesPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    const particleCount = 50;

    for (int i = 0; i < particleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;
      final opacity = random.nextDouble() * 0.5 * animation.value;

      final paint = Paint()
        ..color = Colors.cyan.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LogoRingsPainter extends CustomPainter {
  final Animation<double> animation;

  _LogoRingsPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Outer Ring
    final outerPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, 70, outerPaint);

    // Middle Ring
    final middlePaint = Paint()
      ..color = Colors.pink.withOpacity(0.3 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 60, middlePaint);

    // Inner Ring
    final innerPaint = Paint()
      ..color = Colors.purple.withOpacity(0.3 * animation.value)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, 50, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}