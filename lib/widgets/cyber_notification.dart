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

class _AnimatedNotificationState extends State<_AnimatedNotification> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _showThenHide();
  }

  Future<void> _showThenHide() async {
    try {
      await _ctrl.forward();
      final visible = widget.durationMs - 600; // subtract in/out
      if (visible > 0) await Future.delayed(Duration(milliseconds: visible));
      await _ctrl.reverse();
    } finally {
      widget.entry.remove();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
            child: _CyberCard(title: widget.title, message: widget.message),
          ),
        ),
      ),
    );
  }
}

class _CyberCard extends StatelessWidget {
  final String title;
  final String message;
  const _CyberCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.blue.shade900.withOpacity(0.95), Colors.purple.shade900.withOpacity(0.95)],
        ),
        border: Border.all(color: Colors.cyan, width: 2),
        boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.22), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Colors.cyan, Colors.pink]),
              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 6)],
            ),
            child: const Icon(Icons.notifications, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
