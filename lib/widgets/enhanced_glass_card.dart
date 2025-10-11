import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class EnhancedGlassCard extends StatelessWidget {
  final Widget? child;
  final double? height;
  final VoidCallback? onTap;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool enableGlowEffect;
  final bool enableParticles;
  final bool enableHexagonPattern;
  final bool enableDataStream;
  final bool enableCornerGlow;
  final bool enableCornerAccents;

  const EnhancedGlassCard({
    Key? key,
    this.child,
    this.height,
    this.onTap,
    this.primaryColor = const Color(0xFF00F5FF),
    this.secondaryColor = const Color(0xFFFF00AA),
    this.enableGlowEffect = true,
    this.enableParticles = true,
    this.enableHexagonPattern = true,
    this.enableDataStream = true,
    this.enableCornerGlow = true,
    this.enableCornerAccents = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(25.0);
    
    return Container(
      height: height ?? 120,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: (primaryColor ?? Colors.cyan).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: (secondaryColor ?? Colors.pink).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.4),
                  _getAnimatedColor(0.0),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                // Background Pattern
                if (enableHexagonPattern) _buildHexagonPattern(),
                
                // Data Stream Effect
                if (enableDataStream) _buildDataStreamEffect(),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: child ?? const SizedBox.shrink(),
                ),
                
                // Floating Particles
                if (enableParticles) _buildFloatingParticles(),
                
                // Corner Accents
                if (enableCornerAccents) _buildCornerAccents(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAnimatedColor(double value) {
    // Create an animated color that shifts between cyan and pink
    final t = (value * 2) % 1.0;
    if (t < 0.5) {
      return Color.lerp(
        Colors.cyan.withOpacity(0.4),
        Colors.pink.withOpacity(0.3),
        t * 2,
      )!;
    } else {
      return Color.lerp(
        Colors.pink.withOpacity(0.3),
        Colors.cyan.withOpacity(0.4),
        (t - 0.5) * 2,
      )!;
    }
  }

  Widget _buildHexagonPattern() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          return CustomPaint(
            painter: _HexagonPatternPainter(),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildDataStreamEffect() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          return CustomPaint(
            painter: _DataStreamPainter(),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlassParticlesPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildCornerAccents() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Top Left
          Positioned(
            top: 0,
            left: 0,
            child: AnimatedBuilder(
              animation: const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                      top: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                    ),
                  ),
                );
              },
            ),
          ),
          // Top Right
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                      top: BorderSide(color: Colors.transparent, width: 3),
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom Left
          Positioned(
            bottom: 0,
            left: 0,
            child: AnimatedBuilder(
              animation: const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                      bottom: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom Right
          Positioned(
            bottom: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                      bottom: BorderSide(color: Colors.pink.withOpacity(0.6), width: 3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

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
        
        _drawHexagon(canvas, Offset(x, y), hexSize, paint);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DataStreamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pink.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final random = math.Random(123);
    
    for (int i = 0; i < 5; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = -50.0;
      final endY = size.height + 50;
      
      path.moveTo(startX, startY);
      
      // Use a fixed phase for static decoration; remove dependency on animation state
      const phase = 0.0;
      for (double y = startY; y < endY; y += 20) {
        final x = startX + math.sin((y / 50 + phase + i) * 0.5) * 30;
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, paint);
      path.reset();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlassParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent particles
    
    // Create a limited number of particles for performance
    for (int i = 0; i < 25; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height) % size.height;
      final radius = random.nextDouble() * 3 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}