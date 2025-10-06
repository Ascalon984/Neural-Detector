import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavTap;
  final int currentIndex;

  const HomeScreen({super.key, this.onNavTap, this.currentIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _scanAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    if (AnimationConfig.enableBackgroundAnimations) {
      _controller = AnimationController(
        duration: const Duration(seconds: 4),
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
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.98,
        end: 1.02,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));

      _fadeAnimation = Tween<double>(
        begin: 0.6,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.3);
      _pulseAnimation = AlwaysStoppedAnimation(0.98);
      _fadeAnimation = AlwaysStoppedAnimation(0.6);
    }
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
          // Background dengan efek cyberpunk (tanpa animasi)
          _buildCyberpunkBackground(),
          
          // Scan line effect
          _buildScanLine(),
          
          // Content utama
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan animasi (constrained to a smaller fraction of screen)
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.15,
                    child: _buildHeader(),
                  ),

            // increase spacing so the search/quick-actions block doesn't crowd the subtitle
            const SizedBox(height: 18),
                  
                  // Search bar futuristik
                  _buildSearchBar(),
                  
                  const SizedBox(height: 25),
                  
                  // Quick actions grid
                  _buildQuickActions(),
                  
                  const SizedBox(height: 25),
                  
                  // Stats overview
                  _buildStatsOverview(),
                  
                  const SizedBox(height: 25),
                  
                  // Main feature cards
                  Expanded(
                    child: _buildFeatureCards(),
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
    return SizedBox.expand(
      child: CustomPaint(
        painter: _CyberpunkBackgroundPainter(),
      ),
    );
  }

  Widget _buildScanLine() {
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller ?? AlwaysStoppedAnimation(0.0),
        builder: (context, child) {
          return Positioned(
            top: _scanAnimation.value * MediaQuery.of(context).size.height,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(0.6),
                    Colors.pink.withOpacity(0.6),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _controller ?? AlwaysStoppedAnimation(0.0),
          builder: (context, child) {
            return Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
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
                        color: Colors.cyan.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEURAL',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.cyan.shade300,
                          letterSpacing: 2,
                          fontFamily: AppTheme.defaultFontFamily,
                          shadows: [
                            Shadow(
                              color: Colors.cyan.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'DETECTOR',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.pink.shade300,
                          letterSpacing: 2,
                          fontFamily: AppTheme.defaultFontFamily,
                          shadows: [
                            Shadow(
                              color: Colors.pink.withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
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
        ),
        const SizedBox(height: 10),
        const Text(
          'Quantum AI detection system with neural analysis',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.3),
                  Colors.purple.shade900.withOpacity(0.3),
                ],
              ),
              border: Border.all(
                color: Colors.cyan.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.cyan.shade300, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search documents, text, or analysis...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(0.3),
                        Colors.pink.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.tune, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildCyberActionButton(
            icon: Icons.edit,
            label: 'TEXT EDITOR',
            color: Colors.cyan,
            onTap: () => _navigateTo(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCyberActionButton(
            icon: Icons.upload_file,
            label: 'UPLOAD',
            color: Colors.purple,
            onTap: () => _navigateTo(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCyberActionButton(
            icon: Icons.camera_alt,
            label: 'SCAN',
            color: Colors.pink,
            onTap: () => _navigateTo(3),
          ),
        ),
      ],
    );
  }

  Widget _buildCyberActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return GestureDetector(
          onTap: onTap,
        child: Container(
      decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '98.7%',
            label: 'ACCURACY',
            icon: Icons.verified,
            color: Colors.cyan,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            value: '2.1s',
            label: 'SPEED',
            icon: Icons.bolt,
            color: Colors.pink,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            value: '1.2k',
            label: 'SCANS',
            icon: Icons.analytics,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Courier',
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCards() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildFeatureCard(
          icon: Icons.edit,
          title: 'NEURAL TEXT EDITOR',
          subtitle: 'Real-time AI detection while typing',
          gradient: [Colors.cyan, Colors.blue],
          onTap: () => _navigateTo(1),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.upload_file,
          title: 'QUANTUM UPLOAD',
          subtitle: 'Advanced document analysis',
          gradient: [Colors.purple, Colors.pink],
          onTap: () => _navigateTo(2),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.camera_alt,
          title: 'CYBER SCANNER',
          subtitle: 'OCR with neural processing',
          gradient: [Colors.pink, Colors.cyan],
          onTap: () => _navigateTo(3),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.history,
          title: 'DATA ARCHIVE',
          subtitle: 'Complete scan history database',
          gradient: [Colors.blue, Colors.purple],
          onTap: () => _navigateTo(4),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      gradient[0].withOpacity(0.45),
                      gradient[1].withOpacity(0.18),
                    ],
                  ),
                  border: Border.all(
                    color: gradient[0].withOpacity(0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient[0].withOpacity(0.12),
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: gradient[0].withOpacity(0.28),
                              blurRadius: 4,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                fontFamily: 'Courier',
                              ),
                            ),
                            const SizedBox(height: 5),
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
                      Icon(
                        Icons.arrow_forward_ios,
                        color: gradient[0],
                        size: 20,
                      ),
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

  Widget _buildCornerBorders() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top border
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
          // Bottom border
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

  void _navigateTo(int index) {
    if (widget.onNavTap != null) {
      widget.onNavTap!(index);
    }
  }
}

class _CyberpunkBackgroundPainter extends CustomPainter {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

