import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double height;
  final double? width;
  final IconData? icon;
  final bool isLoading;
  final bool outlined;

  const GradientButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.colors,
    this.height = 56,
    this.width,
    this.icon,
    this.isLoading = false,
    this.outlined = false,
  }) : super(key: key);

  @override
  _GradientButtonState createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed != null && !widget.isLoading) {
      HapticFeedback.lightImpact();
      widget.onPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? [
      AppTheme.accentCyan,
      AppTheme.accentPurple,
      AppTheme.accentPink,
    ];

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        _handleTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: widget.height,
              width: widget.width,
              decoration: BoxDecoration(
                gradient: widget.outlined ? null : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
                border: widget.outlined ? Border.all(
                  color: colors.first,
                  width: 2,
                ) : null,
                borderRadius: BorderRadius.circular(28),
                boxShadow: widget.outlined ? null : [
                  BoxShadow(
                    color: colors.first.withAlpha((_glowAnimation.value * 255).round()),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: colors.last.withAlpha((0.2 * 255).round()),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _handleTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isLoading) ...[
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ] else if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: widget.outlined ? colors.first : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                        ],
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.text,
                            style: AppTheme.button.copyWith(
                              color: widget.outlined ? colors.first : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
// (No alias needed; the widget class is now `GradientButton`)

