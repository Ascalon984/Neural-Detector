import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/animation_config.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class CyberAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool enableGlowEffect;
  final bool enableScanLine;
  final Color primaryColor;
  final Color secondaryColor;

  const CyberAppBar({
    Key? key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.enableGlowEffect = true,
    this.enableScanLine = true,
    this.primaryColor = const Color(0xFF00F5FF),
    this.secondaryColor = const Color(0xFFFF00AA),
  }) : super(key: key);

  @override
  State<CyberAppBar> createState() => _CyberAppBarState<CyberAppBar>();

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

class _CyberAppBarState<T extends CyberAppBar> extends State<T>
  with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _particleController;
  
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _particleAnimation;

  @override
  void initState() {
    super.initState();
    
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(seconds: 4),
        vsync: this,
      )..repeat(reverse: true);

      _glowController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      _pulseController = AnimationController(
        duration: Duration(seconds: 2, milliseconds: 500),
        vsync: this,
      )..repeat(reverse: true);

      _scanController = AnimationController(
        duration: const Duration(seconds: 5),
        vsync: this,
      )..repeat();

      _particleController = AnimationController(
        duration: const Duration(seconds: 15),
        vsync: this,
      )..repeat();

      _glowAnimation = Tween<double>(
        begin: 0.4,
        end: 0.9,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.linear,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.95,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      
      _particleAnimation = Tween<double>(begin: 0, end: 1).animate(_particleController);
    } else {
      _glowAnimation = AlwaysStoppedAnimation(0.4);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
      _particleAnimation = AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.preferredSize.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.5),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Enhanced Background Glow Effect
              if (widget.enableGlowEffect) _buildBackgroundGlow(),
              
              // Floating Particles
              if (AnimationConfig.enableBackgroundAnimations) _buildFloatingParticles(),
              
              // Main App Bar Content
              _buildMainContent(),
              
              // Enhanced Scan Line Effect
              if (widget.enableScanLine) _buildScanLine(),
              
              // Enhanced Bottom Border with Glow
              _buildBottomBorder(),
              
              // Enhanced Corner Accents
              _buildCornerAccents(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackgroundGlow() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.8,
            colors: [
              widget.primaryColor.withOpacity(0.15 * _glowAnimation.value),
              widget.secondaryColor.withOpacity(0.08 * _glowAnimation.value),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _AppBarParticlesPainter(_particleAnimation.value),
      ),
    );
  }

  Widget _buildMainContent() {
    return Transform.translate(
      offset: Offset(0, math.sin(_pulseAnimation.value * math.pi) * 2),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              border: Border(
                bottom: BorderSide(
                  color: widget.primaryColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Row(
                  children: [
                    // Enhanced Leading Icon/Button
                    _buildLeadingButton(),
                    
                    const SizedBox(width: 18),
                    
                    // Enhanced Title Section
                    Expanded(
                      child: _buildTitleSection(),
                    ),
                    
                    // Actions
                    if (widget.actions != null) ...[
                      const SizedBox(width: 18),
                      Row(
                        children: widget.actions!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingButton() {
    if (widget.leading != null) {
      return widget.leading!;
    }
    
    if (widget.showBackButton && Navigator.canPop(context)) {
      return CyberButton(
        onPressed: () => Navigator.pop(context),
        glowColor: widget.primaryColor,
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 22,
        ),
      );
    }
    
    return CyberButton(
      onPressed: () => Scaffold.of(context).openDrawer(),
      glowColor: widget.primaryColor,
      child: const Icon(
        Icons.menu,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Enhanced Main Title with Gradient
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              widget.primaryColor,
              widget.secondaryColor,
            ],
            stops: const [0.3, 0.7],
          ).createShader(bounds),
          child: Text(
            widget.title.toUpperCase(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              fontFamily: AppTheme.defaultFontFamily,
              shadows: [
                Shadow(
                  color: widget.primaryColor.withOpacity(0.6 * _glowAnimation.value),
                  blurRadius: 20,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Enhanced Subtitle (if provided)
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.8,
              fontFamily: 'Courier',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildScanLine() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _scanAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(MediaQuery.of(context).size.width * (1 - _scanAnimation.value), 0),
            child: Container(
              width: 200,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.primaryColor.withOpacity(0.8),
                    widget.secondaryColor.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBorder() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              widget.primaryColor.withOpacity(0.7 * _glowAnimation.value),
              widget.secondaryColor.withOpacity(0.5 * _glowAnimation.value),
              Colors.transparent,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.3 * _glowAnimation.value),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerAccents() {
    return Positioned.fill(
      child: Stack(
        children: [
          // Top Left Corner
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: widget.secondaryColor, width: 2.5),
                  top: BorderSide(color: widget.secondaryColor, width: 2.5),
                ),
              ),
            ),
          ),
          
          // Top Right Corner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: widget.secondaryColor, width: 2.5),
                  top: BorderSide(color: widget.secondaryColor, width: 2.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CyberButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color glowColor;
  final double size;

  const CyberButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.glowColor = const Color(0xFF00F5FF),
    this.size = 48,
  }) : super(key: key);

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.glowColor.withOpacity(0.4 * _glowAnimation.value),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(0.6 * _glowAnimation.value),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: widget.onPressed,
                customBorder: const CircleBorder(),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.glowColor.withOpacity(0.7),
                      width: 2,
                    ),
                  ),
                  child: Center(child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Enhanced App Bar with Status Indicators
class CyberAppBarWithStatus extends CyberAppBar {
  final String status;
  final Color statusColor;
  final bool isOnline;

  const CyberAppBarWithStatus({
    Key? key,
    required String title,
    String? subtitle,
    required this.status,
    required this.statusColor,
    required this.isOnline,
    List<Widget>? actions,
    Widget? leading,
    bool showBackButton = true,
  }) : super(
          key: key,
          title: title,
          subtitle: subtitle,
          actions: actions,
          leading: leading,
          showBackButton: showBackButton,
        );

  @override
  State<CyberAppBarWithStatus> createState() => _CyberAppBarWithStatusState();
}

class _CyberAppBarWithStatusState extends _CyberAppBarState<CyberAppBarWithStatus> {
  @override
  Widget _buildTitleSection() {
  final cyberAppBarWithStatus = widget;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    widget.primaryColor,
                    widget.secondaryColor,
                  ],
                ).createShader(bounds),
                child: Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    fontFamily: 'Courier',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Enhanced Status Indicator
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cyberAppBarWithStatus.statusColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cyberAppBarWithStatus.statusColor.withOpacity(_glowAnimation.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cyberAppBarWithStatus.statusColor.withOpacity(_glowAnimation.value * 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated status dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyberAppBarWithStatus.isOnline
                              ? cyberAppBarWithStatus.statusColor
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cyberAppBarWithStatus.status,
                        style: TextStyle(
                          color: cyberAppBarWithStatus.isOnline 
                            ? cyberAppBarWithStatus.statusColor 
                            : Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _AppBarParticlesPainter extends CustomPainter {
  final double animationValue;
  
  _AppBarParticlesPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent particles
    
    // Create a limited number of particles for performance
    for (int i = 0; i < 20; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 2 + 0.5;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}