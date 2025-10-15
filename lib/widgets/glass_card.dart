import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class GlassCard extends StatelessWidget {
  final Widget? child;
  final double? height;
  final VoidCallback? onTap;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool enableGlowEffect;
  final bool enableParticles;
  final bool enableHexagonPattern;

  const GlassCard({
    Key? key,
    this.child,
    this.height,
    this.onTap,
    this.primaryColor,
    this.secondaryColor,
    this.enableGlowEffect = true,
    this.enableParticles = true,
    this.enableHexagonPattern = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20.0);
    
    return Container(
      height: height ?? 120,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 25,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: (primaryColor ?? Colors.cyan).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: (secondaryColor ?? Colors.pink).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Background Pattern
                if (enableHexagonPattern) _buildHexagonPattern(),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: child ?? const SizedBox.shrink(),
                ),
                
                // Floating Particles
                if (enableParticles) _buildFloatingParticles(),
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
        Colors.cyan.withOpacity(0.3),
        Colors.pink.withOpacity(0.2),
        t * 2,
      )!;
    } else {
      return Color.lerp(
        Colors.pink.withOpacity(0.2),
        Colors.cyan.withOpacity(0.3),
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

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GlassParticlesPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

  const hexSize = 40.0;
  const hexHeight = hexSize * 2;
  final hexWidth = math.sqrt(3) * hexSize;
    const vertDist = hexHeight * 3 / 4;

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

class _GlassParticlesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent particles

    // Create a limited number of particles for performance
    for (int i = 0; i < 20; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height) % size.height;
      final radius = random.nextDouble() * 3 + 1;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}