import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  // Responsive heights based on screen size
  double get _barHeight {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return 65.0; // Small phones
    if (screenHeight < 750) return 75.0; // Medium phones
    return 85.0; // Large phones/tablets
  }

  // Responsive icon sizes
  double get _iconSize {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return 18.0; // Small phones
    if (screenHeight < 750) return 22.0; // Medium phones
    return 26.0; // Large phones/tablets
  }

  // Responsive container sizes
  double get _containerSize {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return 35.0; // Small phones
    if (screenHeight < 750) return 40.0; // Medium phones
    return 45.0; // Large phones/tablets
  }

  // Responsive font sizes
  double get _selectedFontSize {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return 9.0; // Small phones
    if (screenHeight < 750) return 10.0; // Medium phones
    return 11.0; // Large phones/tablets
  }

  double get _unselectedFontSize {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight < 600) return 7.0; // Small phones
    if (screenHeight < 750) return 8.0; // Medium phones
    return 9.0; // Large phones/tablets
  }

  static const List<String> _labels = ['HOME', 'EDIT', 'UPLOAD', 'SCAN', 'HISTORY', 'SETTINGS'];
  static const List<IconData> _icons = [
    Icons.home_outlined,
    Icons.edit_note,
    Icons.upload_file,
    Icons.camera_alt_outlined,
    Icons.history,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _slideController.reset();
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _barHeight + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.9),
            Colors.black,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(_glowAnimation.value * 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            top: false,
            bottom: false,
            child: SizedBox(
              height: _barHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_labels.length, (index) {
                    return _buildNavItem(_icons[index], index, _labels[index]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    final isSelected = widget.currentIndex == index;
    final double iconSize = isSelected ? _iconSize : _iconSize - 2;
    final Color iconColor = isSelected ? Colors.white : Colors.white70;
    final Color textColor = isSelected ? Colors.white : Colors.white54;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: GestureDetector(
          onTap: () {
            widget.onTap(index);
            HapticFeedback.lightImpact();
          },
          child: AnimatedBuilder(
            animation: isSelected ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              return Transform.scale(
                scale: isSelected ? _pulseAnimation.value : 1.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon container with responsive design
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _containerSize,
                      height: _containerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  Colors.cyan.withOpacity(_glowAnimation.value),
                                  Colors.pink.withOpacity(_glowAnimation.value),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.05),
                                  Colors.white.withOpacity(0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyan.withOpacity(_glowAnimation.value * 0.7)
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring for selected item (smaller on small screens)
                          if (isSelected)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _containerSize + 8,
                              height: _containerSize + 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                          
                          // Icon
                          Icon(
                            icon,
                            color: iconColor,
                            size: iconSize,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: MediaQuery.of(context).size.height < 600 ? 3 : 5),

                    // Label with responsive font size
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: textColor,
                        fontSize: isSelected ? _selectedFontSize : _unselectedFontSize,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: isSelected ? 0.3 : 0.2,
                        fontFamily: 'Orbitron',
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    // Indicator for selected item (smaller on small screens)
                    if (isSelected) ...[
                      SizedBox(height: MediaQuery.of(context).size.height < 600 ? 2 : 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: MediaQuery.of(context).size.height < 600 ? 15 : 20,
                        height: MediaQuery.of(context).size.height < 600 ? 2 : 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyan.withOpacity(_glowAnimation.value),
                              Colors.pink.withOpacity(_glowAnimation.value),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ] else
                      SizedBox(height: MediaQuery.of(context).size.height < 600 ? 5 : 7),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}