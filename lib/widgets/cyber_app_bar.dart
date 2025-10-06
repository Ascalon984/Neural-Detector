import 'package:flutter/material.dart';
import 'dart:ui';
import '../config/animation_config.dart';

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
  State<CyberAppBar> createState() => _CyberAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

class _CyberAppBarState extends State<CyberAppBar>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.linear,
      ));

      _slideAnimation = Tween<double>(
        begin: -2.0,
        end: 2.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _glowAnimation = AlwaysStoppedAnimation(0.3);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _slideAnimation = AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
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
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Background Glow Effect
              if (widget.enableGlowEffect) _buildBackgroundGlow(),
              
              // Main App Bar Content
              _buildMainContent(),
              
              // Scan Line Effect
              if (widget.enableScanLine) _buildScanLine(),
              
              // Bottom Border with Glow
              _buildBottomBorder(),
              
              // Corner Accents
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
            radius: 1.5,
            colors: [
              widget.primaryColor.withOpacity(0.1 * _glowAnimation.value),
              widget.secondaryColor.withOpacity(0.05 * _glowAnimation.value),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Transform.translate(
      offset: Offset(0, _slideAnimation.value),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              border: Border(
                bottom: BorderSide(
                  color: widget.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Leading Icon/Button
                    _buildLeadingButton(),
                    
                    const SizedBox(width: 16),
                    
                    // Title Section
                    Expanded(
                      child: _buildTitleSection(),
                    ),
                    
                    // Actions
                    if (widget.actions != null) ...[
                      const SizedBox(width: 16),
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
          size: 20,
        ),
      );
    }
    
    return CyberButton(
      onPressed: () => Scaffold.of(context).openDrawer(),
      glowColor: widget.primaryColor,
      child: const Icon(
        Icons.menu,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Title with Gradient
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
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Courier',
              shadows: [
                Shadow(
                  color: widget.primaryColor.withOpacity(0.5 * _glowAnimation.value),
                  blurRadius: 15,
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        
        // Subtitle (if provided)
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.5,
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
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _controller ?? AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(MediaQuery.of(context).size.width * (1 - _scanAnimation.value), 0),
            child: Container(
              width: 150,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    widget.primaryColor.withOpacity(0.8),
                    widget.secondaryColor.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
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
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              widget.primaryColor.withOpacity(0.6 * _glowAnimation.value),
              widget.secondaryColor.withOpacity(0.4 * _glowAnimation.value),
              Colors.transparent,
            ],
          ),
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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: widget.secondaryColor, width: 2),
                  top: BorderSide(color: widget.secondaryColor, width: 2),
                ),
              ),
            ),
          ),
          
          // Top Right Corner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: widget.secondaryColor, width: 2),
                  top: BorderSide(color: widget.secondaryColor, width: 2),
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
    this.size = 44,
  }) : super(key: key);

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
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
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.glowColor.withOpacity(0.3 * _glowAnimation.value),
                Colors.transparent,
              ],
            ),
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
                    color: widget.glowColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(child: widget.child),
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
  State<CyberAppBar> createState() => _CyberAppBarWithStatusState();
}

class _CyberAppBarWithStatusState extends _CyberAppBarState {
  @override
  Widget _buildTitleSection() {
    final cyberAppBarWithStatus = widget as CyberAppBarWithStatus;
    
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
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'Courier',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cyberAppBarWithStatus.statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cyberAppBarWithStatus.statusColor,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cyberAppBarWithStatus.statusColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cyberAppBarWithStatus.status,
                    style: TextStyle(
                      color: cyberAppBarWithStatus.statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Courier',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}