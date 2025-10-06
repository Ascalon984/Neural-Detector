import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedBackground extends StatefulWidget {
  final bool enableParticles;
  final bool enableGrid;
  final bool enableScanLines;
  final Color primaryColor;
  final Color secondaryColor;

  const AnimatedBackground({
    super.key,
    this.enableParticles = true,
    this.enableGrid = true,
    this.enableScanLines = true,
    this.primaryColor = const Color(0xFF00F5FF),
    this.secondaryColor = const Color(0xFFFF00AA),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  final List<Particle> _particles = [];
  final Random _random = Random();
  final int _particleCount = 25;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
  }

  void _initializeParticles() {
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 3 + 1,
        speed: _random.nextDouble() * 0.5 + 0.1,
        color: _random.nextBool() ? widget.primaryColor : widget.secondaryColor,
        angle: _random.nextDouble() * 2 * pi,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: _buildBackgroundChildren(size),
      ),
    );
  }

  List<Widget> _buildBackgroundChildren(Size size) {
    return [
      // Base Gradient Background (static)
      Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.8,
            colors: [
              Colors.black,
              const Color(0xFF0A0A12).withOpacity(0.5),
              const Color(0xFF1A0B2E).withOpacity(0.4),
              const Color(0xFF0F1A2C).withOpacity(0.3),
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
      ),

      // Nebula Effect (static)
      CustomPaint(
        size: size,
        painter: NebulaPainter(
          primaryColor: widget.primaryColor,
          secondaryColor: widget.secondaryColor,
        ),
      ),

      // Cyber Grid (static)
      if (widget.enableGrid)
        CustomPaint(
          size: size,
          painter: CyberGridPainter(
            color: widget.primaryColor,
          ),
        ),

      // Particles (static dots)
      if (widget.enableParticles)
        CustomPaint(
          size: size,
          painter: ParticlePainter(
            particles: _particles,
            primaryColor: widget.primaryColor,
            secondaryColor: widget.secondaryColor,
          ),
        ),

      // Scan Lines (static position)
      if (widget.enableScanLines)
        CustomPaint(
          size: size,
          painter: ScanLinePainter(
            color: widget.primaryColor,
          ),
        ),

      // Digital Noise Overlay (static)
      CustomPaint(
        size: size,
        painter: NoisePainter(
          intensity: 0.02,
        ),
      ),

      // Corner Glow Effects (static)
      _buildCornerGlows(size),
    ];
  }
 

  Widget _buildCornerGlows(Size size) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top Left Glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top Right Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.secondaryColor.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom Left Glow
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.025),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom Right Glow
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.secondaryColor.withOpacity(0.025),
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

class Particle {
  double x;
  double y;
  double size;
  double speed;
  Color color;
  double angle;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.angle,
  });
}

class NebulaPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  NebulaPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          primaryColor.withOpacity(0.05),
          secondaryColor.withOpacity(0.025),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.6,
      ));

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.6,
      paint,
    );

    // Additional nebula clouds
    final cloudPaint = Paint()
      ..color = primaryColor.withOpacity(0.015)
      ..style = PaintingStyle.fill;

    // Cloud 1
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.3),
      size.width * 0.2,
      cloudPaint,
    );

    // Cloud 2
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.2),
      size.width * 0.15,
      cloudPaint,
    );

    // Cloud 3
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.7),
      size.width * 0.18,
      cloudPaint,
    );

    // Cloud 4
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.6),
      size.width * 0.12,
      cloudPaint,
    );
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) => false;
}

class CyberGridPainter extends CustomPainter {
  final Color color;

  CyberGridPainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 0.8;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.01)
      ..strokeWidth = 1;

    // Main grid lines (static)
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Glow effect on intersecting points (static)
    for (double x = 0; x < size.width; x += 60) {
      for (double y = 0; y < size.height; y += 60) {
        canvas.drawCircle(
          Offset(x, y),
          1.0, // Fixed size
          glowPaint,
        );
      }
    }

    // Perspective grid lines (static)
    final perspectivePaint = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final progress = i / 4;
      final startX = size.width * progress;
      final startY = size.height * progress;

      // Diagonal lines
      canvas.drawLine(
        Offset(startX, 0),
        Offset(size.width, startY),
        perspectivePaint,
      );

      canvas.drawLine(
        Offset(0, startY),
        Offset(startX, size.height),
        perspectivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CyberGridPainter oldDelegate) => false;
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color primaryColor;
  final Color secondaryColor;

  ParticlePainter({
    required this.particles,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final x = particle.x * size.width;
      final y = particle.y * size.height;
      final radius = particle.size;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Glow effect (static)
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(0.05)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius * 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => false;
}

class ScanLinePainter extends CustomPainter {
  final Color color;

  ScanLinePainter({
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Static scan line at middle position
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withOpacity(0.6),
          color.withOpacity(0.8),
          color.withOpacity(0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTRB(0, 0, size.width, 3));

    final scanY = size.height * 0.5;

    // Main scan line
    canvas.drawRect(Rect.fromLTRB(0, scanY, size.width, scanY + 3), scanPaint);

    // Secondary scan lines (static positions)
    for (int i = 1; i <= 3; i++) {
      final secondaryY = (scanY + i * 100) % size.height;
      final secondaryPaint = Paint()
        ..color = color.withOpacity(0.2 / i)
        ..strokeWidth = 1;

      canvas.drawLine(
        Offset(0, secondaryY),
        Offset(size.width, secondaryY),
        secondaryPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter oldDelegate) => false;
}

class NoisePainter extends CustomPainter {
  final double intensity;
  final Random _random = Random();

  NoisePainter({
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final noisePaint = Paint()
      ..color = Colors.white.withOpacity(intensity);

    for (int i = 0; i < size.width.toInt(); i += 2) {
      for (int j = 0; j < size.height.toInt(); j += 2) {
        if (_random.nextDouble() < 0.1) {
          canvas.drawCircle(
            Offset(i.toDouble(), j.toDouble()),
            _random.nextDouble() * 0.5,
            noisePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant NoisePainter oldDelegate) => false;
}