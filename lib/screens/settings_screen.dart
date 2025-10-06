import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import '../utils/settings_manager.dart';
import '../utils/history_manager.dart';
import '../utils/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/scan_history.dart';
import '../utils/exporter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scanAnimation;
  Animation<double>? _glowAnimation;
  Animation<double>? _pulseAnimation;

  bool _notifications = true;
  bool _autoScan = false;
  bool _highAccuracy = false;
  double _scanSensitivity = 0.5; // represents level / 10 (default level 5)
  double _previousSensitivity = 0.5;
  String _selectedLanguage = 'English';

  final List<String> _languages = ['English', 'Indonesian'];

  @override
  void initState() {
    super.initState();
    _loadSensitivity();
    _loadHighAccuracy();
    _loadAutoScan();
    _loadNotifications();
    _loadLanguage();
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat(reverse: true);

      _scanAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _glowAnimation = Tween<double>(
        begin: 0.4,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.95,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _scanAnimation = const AlwaysStoppedAnimation(0.0);
      _glowAnimation = const AlwaysStoppedAnimation(0.6);
      _pulseAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final code = await SettingsManager.getLanguage();
      setState(() {
        _selectedLanguage = (code == 'id') ? 'Indonesian' : 'English';
      });
    } catch (_) {}
  }

  Future<void> _loadSensitivity() async {
    try {
      final lvl = await SettingsManager.getSensitivityLevel();
      setState(() {
        _scanSensitivity = (lvl.clamp(1, 10) / 10.0);
      });
    } catch (_) {}
  }

  Future<void> _loadHighAccuracy() async {
    try {
      final high = await SettingsManager.getHighAccuracy();
      setState(() {
        _highAccuracy = high;
        if (_highAccuracy) {
          _previousSensitivity = _scanSensitivity;
          _scanSensitivity = 1.0; // lock to 100%
        }
      });
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    try {
      final n = await SettingsManager.getNotifications();
      setState(() {
        _notifications = n;
      });
    } catch (_) {}
  }

  Future<void> _loadAutoScan() async {
    try {
      final auto = await SettingsManager.getAutoScan();
      setState(() {
        _autoScan = auto;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      body: Stack(
        children: [
          // Background dengan efek cyberpunk
          _buildCyberpunkBackground(),
          
          // Grid pattern overlay
          _buildGridPattern(),
          
          // Content utama
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan animasi
                  _buildHeader(),
                  
                  const SizedBox(height: 30),
                  
                  // Settings content
                  Expanded(
                    child: _buildSettingsContent(),
                  ),
                ],
              ),
            ),
          ),
          
          // Corner borders decorative
          _buildCornerBorders(),
        ],
      ),
    );
  }

  Widget _buildCyberpunkBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomRight,
          radius: 1.5,
          colors: [
            Colors.black,
            Colors.purple.shade900.withOpacity(0.5),
            Colors.blue.shade900.withOpacity(0.3),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _CyberpunkBackgroundPainter(animation: _controller ?? const AlwaysStoppedAnimation(0.0)),
      ),
    );
  }

  Widget _buildGridPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(
          painter: _GridPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedBuilder(
              animation: _controller ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(_glowAnimation?.value ?? 0.6),
                        Colors.pink.withOpacity(_glowAnimation?.value ?? 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 30,
                  ),
                );
              },
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppLocalizations.t('system_config'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.cyan.shade300,
                      letterSpacing: 2,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppLocalizations.t('neural_network_settings'),
                    style: TextStyle(
                      color: Colors.pink.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 3,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 10),
        
        Text(
          AppLocalizations.t('detection_settings'),
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsContent() {
    return AnimatedBuilder(
      animation: _controller ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Stack(
          children: [
            // Scan line effect
            Positioned(
              top: (_scanAnimation?.value ?? 0.0) * MediaQuery.of(context).size.height,
              child: Container(
                width: MediaQuery.of(context).size.width - 40,
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyan.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Settings list
            ListView(
              children: [
                _buildSectionHeader('DETECTION SETTINGS'),
                _buildSettingSwitch(
                  title: 'High Accuracy Mode',
                  subtitle: 'Maximum detection precision (slower)',
                  value: _highAccuracy,
                  onChanged: (value) async {
                    // toggle high accuracy: if enabling, lock sensitivity to 100%; if disabling, restore previous
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
                      // restore sensitivity level based on previous sensitivity
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
                const SizedBox(height: 20),
                
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
                const SizedBox(height: 20),
                
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
                const SizedBox(height: 20),
                
                _buildSystemInfo(),
                const SizedBox(height: 30),
                
                _buildActionButtons(),
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          fontFamily: 'Courier',
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
      animation: _controller ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Opacity(
                  opacity: _glowAnimation?.value ?? 0.6,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          color.withOpacity(0.62),
                          color.withOpacity(0.12),
                        ],
                      ),
                      border: Border.all(
                        color: color.withOpacity(0.92),
                        width: 1.6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.12),
                          blurRadius: 6,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 4,
                          spreadRadius: 0,
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
                        color: color.withOpacity(0.28),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 20),
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
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: _pulseAnimation?.value ?? 1.0,
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade900.withOpacity(0.45),
            Colors.pink.shade900.withOpacity(0.45),
          ],
        ),
        border: Border.all(
          color: Colors.pink.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.pink.shade300, size: 20),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.t('detection_sensitivity'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Slider(
                value: _scanSensitivity,
                onChanged: _highAccuracy ? null : (value) => setState(() => _scanSensitivity = value),
                onChangeEnd: _highAccuracy
                    ? null
                    : (value) async {
                        // map slider value (0.1..1.0) to level 1..10 and persist
                        final level = (value * 10).round().clamp(1, 10);
                        await SettingsManager.setSensitivityLevel(level);
                      },
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: '${(_scanSensitivity * 100).round()}%',
                activeColor: Colors.pink,
                inactiveColor: Colors.pink.withOpacity(0.3),
              ),
              if (_highAccuracy)
                Positioned(
                  right: 8,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade300, borderRadius: BorderRadius.circular(8)),
                    child: Text(AppLocalizations.t('locked_badge'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.t('low_label'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                AppLocalizations.t('high_label'),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900.withOpacity(0.48),
            Colors.cyan.shade900.withOpacity(0.48),
          ],
        ),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.language, color: Colors.cyan.shade300, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Language',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButton<String>(
            value: _selectedLanguage,
            dropdownColor: Colors.black,
            style: const TextStyle(color: Colors.white),
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
              setState(() {
                _selectedLanguage = newValue!;
              });
              // persist language code
              final code = (_selectedLanguage == 'Indonesian') ? 'id' : 'en';
              SettingsManager.setLanguage(code);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withOpacity(0.36),
            Colors.transparent,
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 4),
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
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                  ),
                  child: Icon(icon, color: color, size: 20),
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
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
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
    );
  }

  Widget _buildSystemInfo() {
    // Use a FutureBuilder to compute database size dynamically from history
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

        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey.shade900.withOpacity(0.6),
                Colors.black.withOpacity(0.7),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                spreadRadius: 0,
                offset: const Offset(0, 4),
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
              const SizedBox(height: 10),
              _buildInfoRow('Version', 'Neural Detector'),
              _buildInfoRow('Last Updated', lastUpdated),
              _buildInfoRow('Database Size', snapshot.hasData ? '${dbSizeMb.toStringAsFixed(1)} MB' : '—'),
              _buildInfoRow('AI Model', 'Tensor Flow Lite'),
            ],
          ),
        );
      },
    );
  }

  // Try to parse various size string formats into bytes.
  // Accepts raw bytes as string, or values with units like '247.3 MB', '12 KB', etc.
  int? _parseSizeToBytes(String? input) {
    if (input == null) return null;
    final s = input.trim();
    if (s.isEmpty) return null;

    // Try plain integer bytes
    try {
      return int.parse(s);
    } catch (_) {}

    // Try to match number + unit
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Courier'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Action buttons removed per design request. Keep layout space minimal.
    return const SizedBox.shrink();
  }

  Widget _buildCyberButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _controller ?? const AlwaysStoppedAnimation(0.0),
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
              color: color.withOpacity(_glowAnimation?.value ?? 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
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
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
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

  Widget _buildCornerBorders() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink,
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
    // Ask for confirmation then clear history
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Confirm'),
        content: const Text('Are you sure you want to delete ALL scan history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
            },
            child: Text(AppLocalizations.t('clear_scan_history')),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await HistoryManager.clearHistory();
        // show a small confirmation dialog
        _showDialog('History Cleared', 'All scan history has been removed.');
      }
    });
  }

  void _exportData() {
    // Gather history, map to exporter rows, prompt folder picker and save files
    HistoryManager.loadHistory().then((list) async {
      if (list.isEmpty) {
        _showDialog(AppLocalizations.t('export_data'), AppLocalizations.t('no_history_to_export'));
        return;
      }

      // Convert ScanHistory objects to the map shape expected by Exporter
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
        _showDialog(AppLocalizations.t('export_data'), AppLocalizations.t('export_cancelled'));
      } else {
        _showDialog(AppLocalizations.t('export_data'), AppLocalizations.t('export_saved_to') + '\n$path');
      }
    });
  }

  // Action buttons were removed; no reset/save methods required.

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
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
            border: Border.all(color: Colors.cyan, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.cyan, size: 50),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.cyan.shade300,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
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
    );
  }
}

class _CyberpunkBackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  _CyberpunkBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.purple.shade900.withOpacity(0.1),
          Colors.blue.shade900.withOpacity(0.1),
          Colors.black,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.2 * animation.value)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 30) {
      final x = i + animation.value * 30;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 35) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}