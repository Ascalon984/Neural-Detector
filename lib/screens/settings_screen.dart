import 'package:flutter/material.dart';
import '../config/animation_config.dart';
// provider and theme provider removed because dark mode and language features were removed
import '../utils/settings_manager.dart';
import '../utils/history_manager.dart';
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
  late AnimationController _hexagonController;
  late AnimationController _dataStreamController;
  late AnimationController _glitchController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _hexagonAnimation;
  late Animation<double> _dataStreamAnimation;

  bool _notifications = true;
  bool _autoScan = false;
  bool _highAccuracy = false;
  double _scanSensitivity = 0.5;
  double _previousSensitivity = 0.5;
  // language support removed per user request

  @override
  void initState() {
    super.initState();
    
    // Initialize multiple animation controllers for different effects
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: Duration(seconds: 2, milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    
    _hexagonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _dataStreamController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    // Initialize animation objects (use AlwaysStoppedAnimation when animations are disabled)
    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_backgroundController);

      _glowAnimation = Tween<double>(begin: 0.4, end: 0.9).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(begin: -0.2, end: 1.2).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      
      _hexagonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_hexagonController);
      
      _dataStreamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_dataStreamController);
      
      // Randomly trigger glitch effect
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _triggerGlitch();
        }
      });
    } else {
      _backgroundAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.5);
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _pulseAnimation = AlwaysStoppedAnimation(1.0);
      _hexagonAnimation = AlwaysStoppedAnimation(0.0);
      _dataStreamAnimation = AlwaysStoppedAnimation(0.0);
    }

  _loadSensitivity();
  _loadHighAccuracy();
  _loadAutoScan();
  _loadNotifications();
  }

  void _triggerGlitch() {
    if (AnimationConfig.enableBackgroundAnimations) {
      _glitchController.forward().then((_) {
        _glitchController.reverse();
      });
      
      // Schedule next glitch
      Future.delayed(Duration(seconds: 5 + math.Random().nextInt(10)), () {
        if (mounted) {
          _triggerGlitch();
        }
      });
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _glowController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _hexagonController.dispose();
    _dataStreamController.dispose();
    _glitchController.dispose();
    super.dispose();
  }

  // language handling removed

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
          // Enhanced animated cyberpunk background
          _buildAnimatedBackground(),
          
          // Hexagon grid overlay effect
          _buildHexagonGridOverlay(),
          
          // Data stream effect
          _buildDataStreamEffect(),
          
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
                      padding: const EdgeInsets.all(18),
                      child: _buildHeader(),
                    ),

                    // Scrollable settings area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20, bottom: 20),
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
          
          // Enhanced cyberpunk frame borders
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
            gradient: RadialGradient(
              center: Alignment(0.5 - _backgroundAnimation.value * 0.3, 0.3),
              radius: 1.2 + _backgroundAnimation.value * 0.3,
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

  Widget _buildHexagonGridOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _hexagonAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _HexagonGridPainter(_hexagonAnimation.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  Widget _buildDataStreamEffect() {
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _dataStreamAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _DataStreamPainter(_dataStreamAnimation.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildScanLine() {
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top: _scanAnimation.value * MediaQuery.of(context).size.height,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
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
                  color: Colors.cyan.withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlitchEffect() {
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _glitchController,
        builder: (context, child) {
          return Opacity(
            opacity: _glitchController.value,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: isVerySmallScreen ? 40 : (isSmallScreen ? 50 : 60),
              height: isVerySmallScreen ? 40 : (isSmallScreen ? 50 : 60),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : (isSmallScreen ? 15 : 20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.settings,
                color: Colors.white,
                size: isVerySmallScreen ? 20 : (isSmallScreen ? 25 : 30),
              ),
            ),
            const SizedBox(width: 12),
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
                      'PENGATURAN',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 18 : (isSmallScreen ? 22 : 26),
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  SizedBox(height: isVerySmallScreen ? 2 : 4),
                  Container(
                    height: 2,
                    width: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.cyan.withOpacity(_glowAnimation.value),
                          Colors.pink.withOpacity(_glowAnimation.value),
                        ],
                      ),
                    ),
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
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyan.withOpacity(0.7),
                      Colors.pink.withOpacity(0.7),
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
                _buildSectionHeader('PENGATURAN DETEKSI'),
                _buildSettingSwitch(
                  title: 'Mode Akurasi Tinggi',
                  subtitle: 'Presisi deteksi maksimum (lebih lambat)',
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
                  title: 'Pindai Dokumen Otomatis',
                  subtitle: 'Secara otomatis pindai file yang diunggah',
                  value: _autoScan,
                  onChanged: (value) async {
                    setState(() => _autoScan = value);
                    await SettingsManager.setAutoScan(value);
                  },
                  icon: Icons.auto_awesome,
                  color: Colors.purple,
                ),
                _buildSensitivitySlider(),
                const SizedBox(height: 20),
                
                _buildSectionHeader('PREFERENSI SISTEM'),
                // Dark mode removed from settings per user request
                _buildSettingSwitch(
                  title: 'Notifikasi',
                  subtitle: 'Terima pemberitahuan penyelesaian pemindaian',
                  value: _notifications,
                  onChanged: (value) async {
                    setState(() => _notifications = value);
                    await SettingsManager.setNotifications(value);
                  },
                  icon: Icons.notifications,
                  color: Colors.blue,
                ),
                // Language selector removed per user request
                const SizedBox(height: 20),
                
                _buildSectionHeader('DATA & PRIVASI'),
                _buildSettingButton(
                  title: 'Hapus Riwayat Pemindaian',
                  subtitle: 'Hapus semua data pemindaian sebelumnya',
                  icon: Icons.delete,
                  color: Colors.red,
                  onTap: _clearHistory,
                ),
                _buildSettingButton(
                  title: 'Ekspor Data',
                  subtitle: 'Unduh semua hasil analisis',
                  icon: Icons.download,
                  color: Colors.green,
                  onTap: _exportData,
                ),
                const SizedBox(height: 20),
                
                _buildSystemInfo(),
                const SizedBox(height: 25),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.cyan.shade300,
          fontSize: MediaQuery.of(context).size.width < 360 ? 17 : 19,
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
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.4),
                  color.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.4),
                        color.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(_glowAnimation.value * 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Orbitron',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
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
                    activeTrackColor: color.withOpacity(0.4),
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade900.withOpacity(0.4),
                Colors.pink.shade900.withOpacity(0.4),
              ],
            ),
            border: Border.all(
              color: Colors.pink.withOpacity(_glowAnimation.value),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, color: Colors.pink.shade300, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sensivitas Deteksi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Orbitron',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Stack(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.pink,
                      inactiveTrackColor: Colors.pink.withOpacity(0.4),
                      thumbColor: Colors.pink,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayColor: Colors.pink.withOpacity(0.3),
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
                      right: 10,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade300,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 5,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text(
                          'LOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RENDAH',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  Text(
                    'TINGGI',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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

  // Language selector removed per user request

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
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  color.withOpacity(0.4),
                  color.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.4),
                              color.withOpacity(0.1),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(_glowAnimation.value * 0.6),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'Orbitron',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: color, size: 18),
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

  final lastUpdated = '09 Oktober 2025';

        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade900.withOpacity(0.4),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INFORMASI SISTEM',
                    style: TextStyle(
                      color: Colors.cyan.shade300,
                      fontSize: MediaQuery.of(context).size.width < 360 ? 15 : 17,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoRow('Versi', '1.0.0'),
                  _buildInfoRow('Terakhir Diperbarui', lastUpdated),
                  _buildInfoRow('Ukuran Database', snapshot.hasData ? '${dbSizeMb.toStringAsFixed(1)} MB' : '—'),
                  _buildInfoRow('Model AI', 'Tensor Flow Lite'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
          // Bottom navbar-like thin bar (match Home)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a253e).withOpacity(0.95),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                );
              },
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
            borderRadius: BorderRadius.circular(25),
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
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 25,
                spreadRadius: 6,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.red, Colors.deepOrange],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Confirm Deletion',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 17 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade300,
                      fontFamily: 'Orbitron',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Are you sure you want to delete ALL scan history? This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
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
                      const SizedBox(width: 15),
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

      final result = await Exporter.exportToFolder(rows, suggestedName: 'scan_history');
      if (!result.success) {
        _showDialog('Export Data', 'Export failed: ${result.errorMessage}');
      } else {
        _showDialog('Export Data', 'Data saved to:\n${result.filePath}');
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
            borderRadius: BorderRadius.circular(25),
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
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 25,
                spreadRadius: 6,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.cyan, Colors.pink],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(0.5),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 360 ? 17 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade300,
                      fontFamily: 'Orbitron',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
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
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.4),
                color.withOpacity(0.2),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(_glowAnimation.value),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
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

class _HexagonGridPainter extends CustomPainter {
  final double animationValue;
  _HexagonGridPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const hexSize = 40.0;
    const hexHeight = hexSize * 2;
    final hexWidth = math.sqrt(3) * hexSize;
    final vertDist = hexHeight * 3 / 4;

    int cols = (size.width / hexWidth).ceil() + 1;
    int rows = (size.height / vertDist).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = col * hexWidth + (row % 2) * hexWidth / 2;
        final y = row * vertDist;
        
        // Add some animation by shifting hexagons
        final offsetX = math.sin(animationValue * 2 * math.pi + row * 0.1) * 5;
        final offsetY = math.cos(animationValue * 2 * math.pi + col * 0.1) * 5;
        
        _drawHexagon(canvas, Offset(x + offsetX, y + offsetY), hexSize, paint);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DataStreamPainter extends CustomPainter {
  final double animationValue;
  _DataStreamPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.pink.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final random = math.Random(123);
    
    for (int i = 0; i < 5; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = -50.0;
      final endY = size.height + 50;
      
      path.moveTo(startX, startY);
      
      for (double y = startY; y < endY; y += 20) {
        final x = startX + math.sin((y / 50) + animationValue * 2 * math.pi + i) * 30;
        path.lineTo(x, y + (animationValue * size.height) % (size.height + 100) - 50);
      }
      
      canvas.drawPath(path, paint);
      path.reset();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ParticlesPainter extends CustomPainter {
  final double animationValue;
  
  _ParticlesPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    
    final random = math.Random(42); // Fixed seed for consistent particles
    
    for (int i = 0; i < 25; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 3 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}