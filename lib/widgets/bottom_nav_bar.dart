import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  static const double _barHeight = 75;
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
  Widget build(BuildContext context) {
    return Container(
      height: _barHeight + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.9),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_labels.length, (index) {
              return _buildNavItem(_icons[index], index, _labels[index]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    final isSelected = currentIndex == index;
    final double iconSize = isSelected ? 24 : 20;
    final Color iconColor = isSelected ? AppTheme.accentCyan : Colors.white70;
    final Color textColor = isSelected ? AppTheme.accentCyan : Colors.white54;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [AppTheme.accentCyan, AppTheme.accentPurple],
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
                    border: isSelected
                        ? Border.all(
                            color: AppTheme.accentCyan.withOpacity(0.5),
                            width: 1.5,
                          )
                        : Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.accentCyan.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: AppTheme.accentPurple.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: iconSize,
                  ),
                ),

                const SizedBox(height: 4),

                // Label
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.accentCyan, AppTheme.accentPurple],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}