import 'package:flutter/material.dart';

class CyberNotification {
  static void show(BuildContext context, String title, String message, {int durationMs = 1800}) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AnimatedNotification(entry: entry, title: title, message: message, durationMs: durationMs),
    );

    overlay.insert(entry);
  }
}

class _AnimatedNotification extends StatefulWidget {
  final OverlayEntry entry;
  final String title;
  final String message;
  final int durationMs;
  const _AnimatedNotification({required this.entry, required this.title, required this.message, required this.durationMs});

  @override
  State<_AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<_AnimatedNotification> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _glowController;
  late final AnimationController _pulseController;
  
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _glow;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1, milliseconds: 500))
      ..repeat(reverse: true);
    
    _slide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _glow = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut)
    );
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
    );

    _showThenHide();
  }

  Future<void> _showThenHide() async {
    try {
      await _ctrl.forward();
      final visible = widget.durationMs - 800; // subtract in/out
      if (visible > 0) await Future.delayed(Duration(milliseconds: visible));
      await _ctrl.reverse();
    } finally {
      widget.entry.remove();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: _CyberCard(
              title: widget.title, 
              message: widget.message,
              glowAnimation: _glow,
              pulseAnimation: _pulse,
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberCard extends StatelessWidget {
  final String title;
  final String message;
  final Animation<double> glowAnimation;
  final Animation<double> pulseAnimation;
  
  const _CyberCard({
    required this.title, 
    required this.message,
    required this.glowAnimation,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.95),
                  Colors.purple.shade900.withOpacity(0.95),
                ],
              ),
              border: Border.all(
                color: Colors.cyan.withOpacity(glowAnimation.value),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(glowAnimation.value * 0.4),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Colors.pink.withOpacity(glowAnimation.value * 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.cyan.withOpacity(glowAnimation.value),
                            Colors.pink.withOpacity(glowAnimation.value),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(glowAnimation.value * 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Orbitron',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Animated status indicator (inline, not Positioned)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: AnimatedBuilder(
                    animation: glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withOpacity(glowAnimation.value),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(glowAnimation.value * 0.5),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}