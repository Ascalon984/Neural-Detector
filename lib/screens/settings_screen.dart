import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import '../utils/settings_manager.dart';
import '../utils/history_manager.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../utils/exporter.dart';
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;

  bool _notifications = true;
  bool _autoScan = false;
  bool _highAccuracy = false;
  double _scanSensitivity = 0.5;
  double _previousSensitivity = 0.5;
  String _selectedLanguage = 'English';

  final List<String> _languages = ['English', 'Indonesian'];

  @override
  void initState() {
    super.initState();
    
    // Initialize multiple animation controllers for different effects
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 1, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    // Initialize animation objects (use AlwaysStoppedAnimation when animations are disabled)
    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);

      _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
    }

    _loadSensitivity();
    _loadHighAccuracy();
    _loadAutoScan();
    _loadNotifications();
    _loadLanguage();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguage() async {
    try {
      final code = await SettingsManager.getLanguage();
      if (mounted) {
        setState(() {
          _selectedLanguage = (code == 'id') ? 'Indonesian' : 'English';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSensitivity() async {
    try {
      final lvl = await SettingsManager.getSensitivityLevel();
      if (mounted) {
        setState(() {
          _scanSensitivity = (lvl.clamp(1, 10) / 10.0);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadHighAccuracy() async {
    try {
      final high = await SettingsManager.getHighAccuracy();
      if (mounted) {
        setState(() {
          _highAccuracy = high;
          if (_highAccuracy) {
            _previousSensitivity = _scanSensitivity;
            _scanSensitivity = 1.0;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    try {
      final n = await SettingsManager.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = n;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAutoScan() async {
    try {
      final auto = await SettingsManager.getAutoScan();
      if (mounted) {
        setState(() {
          _autoScan = auto;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated cyberpunk background
          _buildAnimatedBackground(),
          
          // Grid overlay effect
          _buildGridOverlay(),
          
          // Scan line effect
          _buildScanLine(),
          
          // Glitch effect overlay
          _buildGlitchEffect(),
          
          // Floating particles effect
          _buildFloatingParticles(),
          
          // Main content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed header (will not scroll)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildHeader(),
                    ),

                    // Scrollable settings area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 16),
                            child: _buildSettingsContent(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Cyberpunk frame borders
          _buildCyberpunkFrame(),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF0a0a0a),
                  const Color(0xFF1a0033),
                  _backgroundAnimation.value,
                )!,
                Color.lerp(
                  const Color(0xFF0d1117),
                  const Color(0xFF0a0e27),
                  _backgroundAnimation.value,
                )!,
                Colors.black,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top: _scanAnimation.value * MediaQuery.of(context).size.height,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.cyan.withOpacity(0.8),
                  Colors.pink.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlitchEffect() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: (_glowAnimation.value - 0.3).clamp(0.0, 0.1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.pink.withOpacity(0.1),
                    Colors.cyan.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _rotateController,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlesPainter(_rotateController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(_glowAnimation.value),
                        Colors.pink.withOpacity(_glowAnimation.value),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'SYSTEM CONFIG',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 360 ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'NEURAL NETWORK SETTINGS',
                    style: TextStyle(
                      color: Colors.pink.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                      fontFamily: 'Courier',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsContent() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Scan line effect
            Positioned(
              top: _scanAnimation.value * MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyan.withOpacity(0.6),
                      Colors.pink.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Settings list
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSectionHeader('DETECTION SETTINGS'),
                _buildSettingSwitch(
                  title: 'High Accuracy Mode',
                  subtitle: 'Maximum detection precision (slower)',
                  value: _highAccuracy,
                  onChanged: (value) async {
                    if (value) {
                      _previousSensitivity = _scanSensitivity;
                      setState(() {
                        _highAccuracy = true;
                        _scanSensitivity = 1.0;
                      });
                      await SettingsManager.setHighAccuracy(true);
                      await SettingsManager.setSensitivityLevel(10);
                    } else {
                      setState(() {
                        _highAccuracy = false;
                        _scanSensitivity = _previousSensitivity;
                      });
                      await SettingsManager.setHighAccuracy(false);
                      final restoredLevel = (_previousSensitivity * 10).round().clamp(1, 10);
                      await SettingsManager.setSensitivityLevel(restoredLevel);
                    }
                  },
                  icon: Icons.psychology,
                  color: Colors.cyan,
                ),
                _buildSettingSwitch(
                  title: 'Auto-scan Documents',
                  subtitle: 'Automatically scan uploaded files',
                  value: _autoScan,
                  onChanged: (value) async {
                    setState(() => _autoScan = value);
                    await SettingsManager.setAutoScan(value);
                  },
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                ),
                _buildSensitivitySlider(),
                const SizedBox(height: 15),
                
                _buildSectionHeader('SYSTEM PREFERENCES'),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, child) => _buildSettingSwitch(
                    title: 'Dark Mode',
                    subtitle: 'Cyberpunk interface theme',
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(),
                    icon: Icons.dark_mode,
                    color: Colors.pink,
                  ),
                ),
                _buildSettingSwitch(
                  title: 'Notifications',
                  subtitle: 'Receive scan completion alerts',
                  value: _notifications,
                  onChanged: (value) async {
                    setState(() => _notifications = value);
                    await SettingsManager.setNotifications(value);
                  },
                  icon: Icons.notifications,
                  color: Colors.blue,
                ),
                _buildLanguageSelector(),
                const SizedBox(height: 15),
                
                _buildSectionHeader('DATA & PRIVACY'),
                _buildSettingButton(
                  title: 'Clear Scan History',
                  subtitle: 'Remove all previous scan data',
                  icon: Icons.delete,
                  color: Colors.red,
                  onTap: _clearHistory,
                ),
                _buildSettingButton(
                  title: 'Export Data',
                  subtitle: 'Download all analysis results',
                  icon: Icons.download,
                  color: Colors.green,
                  onTap: _exportData,
                ),
                const SizedBox(height: 15),
                
                _buildSystemInfo(),
                const SizedBox(height: 20),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.cyan.shade300,
          fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          fontFamily: 'Orbitron',
        ),
      ),
    );
  }

  Widget _buildSettingSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(_glowAnimation.value * 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Orbitron',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: color,
                    activeTrackColor: color.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSensitivitySlider() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade900.withOpacity(0.3),
                Colors.pink.shade900.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: Colors.pink.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Colors.pink.shade300, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detection Sensitivity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.pink,
                      inactiveTrackColor: Colors.pink.withOpacity(0.3),
                      thumbColor: Colors.pink,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayColor: Colors.pink.withOpacity(0.2),
                      valueIndicatorColor: Colors.pink,
                      valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                    ),
                    child: Slider(
                      value: _scanSensitivity,
                      onChanged: _highAccuracy ? null : (value) => setState(() => _scanSensitivity = value),
                      onChangeEnd: _highAccuracy
                          ? null
                          : (value) async {
                              final level = (value * 10).round().clamp(1, 10);
                              await SettingsManager.setSensitivityLevel(level);
                            },
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(_scanSensitivity * 100).round()}%',
                    ),
                  ),
                  if (_highAccuracy)
                    Positioned(
                      right: 8,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LOW',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  Text(
                    'HIGH',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelector() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900.withOpacity(0.3),
                Colors.cyan.shade900.withOpacity(0.3),
              ],
            ),
            border: Border.all(
              color: Colors.cyan.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.language, color: Colors.cyan.shade300, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Language',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(_glowAnimation.value),
                    width: 1,
                  ),
                ),
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan),
                  underline: Container(height: 0),
                  isExpanded: true,
                  items: _languages.map((String language) {
                    return DropdownMenuItem<String>(
                      value: language,
                      child: Text(language),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedLanguage = newValue;
                      });
                      final code = (_selectedLanguage == 'Indonesian') ? 'id' : 'en';
                      SettingsManager.setLanguage(code);
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.3),
                              color.withOpacity(0.1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(_glowAnimation.value * 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Orbitron',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: color, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemInfo() {
    return FutureBuilder<List<ScanHistory>>(
      future: HistoryManager.loadHistory(),
      builder: (context, snapshot) {
        double dbSizeMb = 0.0;
        if (snapshot.hasData) {
          final list = snapshot.data!;
          int totalBytes = 0;
          for (final h in list) {
            final bytes = _parseSizeToBytes(h.fileSize);
            if (bytes != null) totalBytes += bytes;
          }
          dbSizeMb = totalBytes / (1024 * 1024);
        }

        final lastUpdated = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade900.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYSTEM INFORMATION',
                    style: TextStyle(
                      color: Colors.cyan.shade300,
                      fontSize: MediaQuery.of(context).size.width < 360 ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Version', 'Neural Detector'),
                  _buildInfoRow('Last Updated', lastUpdated),
                  _buildInfoRow('Database Size', snapshot.hasData ? '${dbSizeMb.toStringAsFixed(1)} MB' : '—'),
                  _buildInfoRow('AI Model', 'Tensor Flow Lite'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int? _parseSizeToBytes(String? input) {
    if (input == null) return null;
    final s = input.trim();
    if (s.isEmpty) return null;

    try {
      return int.parse(s);
    } catch (_) {}

    final regex = RegExp(r"([0-9]+(?:\.[0-9]+)?)\s*([kKmMgG][bB])");
    final m = regex.firstMatch(s);
    if (m != null) {
      final numPart = double.tryParse(m.group(1) ?? '0') ?? 0.0;
      final unit = (m.group(2) ?? '').toUpperCase();
      switch (unit) {
        case 'KB':
          return (numPart * 1024).round();
        case 'MB':
          return (numPart * 1024 * 1024).round();
        case 'GB':
          return (numPart * 1024 * 1024 * 1024).round();
        default:
          return null;
      }
    }

    return null;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Courier',
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCyberpunkFrame() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top border
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom border
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Left border
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Right border
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.cyan.withOpacity(_glowAnimation.value),
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

  void _clearHistory() {
    showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade900.withOpacity(0.9),
                Colors.deepOrange.shade900.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: Colors.red.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(_glowAnimation.value * 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.deepOrange],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                      fontFamily: 'Orbitron',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you sure you want to delete ALL scan history? This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCyberButton(
                          text: 'CANCEL',
                          icon: Icons.close,
                          onPressed: () => Navigator.of(context).pop(false),
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCyberButton(
                          text: 'DELETE',
                          icon: Icons.delete,
                          onPressed: () async {
                            Navigator.of(context).pop(true);
                            await HistoryManager.clearHistory();
                            _showDialog('History Cleared', 'All scan history has been removed.');
                          },
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await HistoryManager.clearHistory();
        _showDialog('History Cleared', 'All scan history has been removed.');
      }
    });
  }

  void _exportData() {
    HistoryManager.loadHistory().then((list) async {
      if (list.isEmpty) {
        _showDialog('Export Data', 'No history to export');
        return;
      }

      final rows = list.map((ScanHistory h) {
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(h.date);
        } catch (_) {
          parsedDate = null;
        }
        int? sizeBytes;
        try {
          sizeBytes = int.parse(h.fileSize);
        } catch (_) {
          sizeBytes = null;
        }
        double? aiScore;
        try {
          aiScore = h.aiDetection / 100.0;
        } catch (_) {
          aiScore = null;
        }

        return {
          'filename': h.fileName,
          'date': parsedDate ?? h.date,
          'sizeBytes': sizeBytes,
          'aiScore': aiScore,
          'backend': h.status,
          'language': '',
          'notes': '',
        };
      }).toList();

      final path = await Exporter.exportToFolder(rows, suggestedName: 'scan_history');
      if (path == null) {
        _showDialog('Export Data', 'Export cancelled');
      } else {
        _showDialog('Export Data', 'Data saved to:\n$path');
      }
    });
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade900.withOpacity(0.9),
                Colors.purple.shade900.withOpacity(0.9),
              ],
            ),
            border: Border.all(
              color: Colors.cyan.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.pink],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade300,
                      fontFamily: 'Orbitron',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildCyberButton(
                    text: 'OK',
                    icon: Icons.done,
                    onPressed: () => Navigator.pop(context),
                    color: Colors.cyan,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCyberButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(_glowAnimation.value),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const gridSize = 30.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  
  _ParticlesPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent particles
    
    for (int i = 0; i < 20; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}