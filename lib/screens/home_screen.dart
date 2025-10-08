import 'package:flutter/material.dart';
import '../config/animation_config.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../data/search_index.dart';
import 'history_screen.dart';
import '../utils/search_bridge.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavTap;
  final int currentIndex;

  const HomeScreen({super.key, this.onNavTap, this.currentIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _glitchController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  // removed unused _glitchAnimation
  // Search/filter state
  late TextEditingController _searchController;
  late Map<String, dynamic> _searchFilters;
  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _loadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    // initialize search filters
    _searchFilters = {
      'source': 'all', // all/history/upload/camera/editor
      'minConfidence': 50,
      'sensitivityOverride': null,
      'dateFrom': null,
      'dateTo': null,
      'onlyAi': false,
      'sort': 'relevance', // relevance/newest/confidence
    };
    
    // Initialize multiple animation controllers for different effects
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
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
    
    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_backgroundController);

      _glowAnimation = Tween<double>(
        begin: 0.3,
        end: 0.8,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));

      _scanAnimation = Tween<double>(
        begin: -0.2,
        end: 1.2,
      ).animate(CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ));

      _pulseAnimation = Tween<double>(
        begin: 0.98,
        end: 1.02,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));

      _fadeAnimation = Tween<double>(
        begin: 0.7,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ));
      
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
      _fadeAnimation = AlwaysStoppedAnimation(1.0);
  // no glitch animation when disabled
    }
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
    _glitchController.dispose();
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() { _suggestions = []; _loadingSuggestions = false; });
        return;
      }
      if (mounted) setState(() { _loadingSuggestions = true; });
      final s = await SearchIndex.searchSuggestions(q, _searchFilters);
      if (!mounted) return;
      setState(() { _suggestions = s; _loadingSuggestions = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
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
                // Lock the top area (header/search/stats) while making the features list scrollable
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth * 0.05,
                    screenHeight * 0.02,
                    screenWidth * 0.05,
                    screenHeight * 0.02,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed top area
                      _buildHeader(),
                      SizedBox(height: screenHeight * 0.02),
                      _buildSearchBar(),
                      SizedBox(height: screenHeight * 0.03),
                      _buildStatsOverview(),
                      SizedBox(height: screenHeight * 0.02),

                      // separator between fixed top and scrollable area
                      _buildTopSeparator(),

                      // Scrollable features area
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildFeatureCards(),
                              SizedBox(height: math.max(16, screenHeight * 0.02)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
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
    if (!AnimationConfig.enableBackgroundAnimations) return const SizedBox.shrink();
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

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                color: Colors.white,
                size: 35,
              ),
            ),
            const SizedBox(width: 20),
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
                    child: const Text(
                      'NEURAL',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.pink.withOpacity(_glowAnimation.value),
                        Colors.cyan.withOpacity(_glowAnimation.value),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'DETECTOR',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        fontFamily: 'Orbitron',
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

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: LayoutBuilder(builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade900.withOpacity(0.4),
                    Colors.purple.shade900.withOpacity(0.4),
                  ],
                ),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Make search icon act as submit button (left side)
                      GestureDetector(
                        onTap: () => _onSearchSubmitted(_searchController.text),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyan.withOpacity(0.08),
                          ),
                          child: Icon(Icons.search, color: Colors.cyan.shade300, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (q) => _onSearchSubmitted(q),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Telusuri hasil pemindaian...',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openFilterSheet,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan.withOpacity(_glowAnimation.value),
                                Colors.pink.withOpacity(_glowAnimation.value),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  // Suggestions dropdown constrained to search box width so it won't widen parent
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: availableWidth - 8, // a little padding
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyan.withOpacity(0.08)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (ctx, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(s, style: const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.history, color: Colors.white70, size: 18),
                            onTap: () {
                              _searchController.text = s;
                              _onSearchSubmitted(s);
                            },
                          );
                        },
                      ),
                    ),

                  if (_loadingSuggestions) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTopSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.cyan.withOpacity(0.06),
              Colors.transparent,
              Colors.pink.withOpacity(0.06),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 6, offset: const Offset(0, 2)),
            BoxShadow(color: Colors.cyan.withOpacity(0.02), blurRadius: 8, spreadRadius: 1),
          ],
        ),
      ),
    );
  }

  void _onSearchSubmitted(String q) {
    // For now: do a simple action — in real app, integrate search/index and scan
    if (q.trim().isEmpty) return;
    final filters = Map<String, dynamic>.from(_searchFilters);
    if (widget.onNavTap != null) {
      // set bridge so History screen can pick it up and then switch tab to index 4 (history)
      SearchBridge.set(q, filters);
      widget.onNavTap!(4);
      return;
    }

    // fallback: push history screen
    Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(initialQuery: q, initialFilters: filters)));
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int sensitivity = (_searchFilters['sensitivityOverride'] as int?) ?? 5;
        int minConf = (_searchFilters['minConfidence'] as int?) ?? 50;
        String source = (_searchFilters['source'] as String?) ?? 'all';
        bool onlyAi = (_searchFilters['onlyAi'] as bool?) ?? false;
        String sort = (_searchFilters['sort'] as String?) ?? 'relevance';

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(builder: (c, setC) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.deepPurple.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(color: Colors.cyan.withOpacity(0.12)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Filter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Orbitron')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          child: const Text('Batal'),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      const Text('Sumber', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _neonChip('all', 'Semua', source, (v) => setC(() => source = v)),
                        _neonChip('history', 'Riwayat', source, (v) => setC(() => source = v)),
                        _neonChip('upload', 'Unggah', source, (v) => setC(() => source = v)),
                        _neonChip('camera', 'Kamera', source, (v) => setC(() => source = v)),
                        _neonChip('editor', 'Editor', source, (v) => setC(() => source = v)),
                      ]),
                      const SizedBox(height: 12),
                      Text('Kepercayaan minimum: $minConf%', style: const TextStyle(color: Colors.white70)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purpleAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.pinkAccent,
                          overlayColor: Colors.pinkAccent.withOpacity(0.2),
                          trackHeight: 6,
                        ),
                        child: Slider(value: minConf.toDouble(), min: 50, max: 100, divisions: 50, label: '$minConf%', onChanged: (v) => setC(() => minConf = v.round())),
                      ),
                      const SizedBox(height: 8),
                      Text('Penggantian sensitivitas: $sensitivity', style: const TextStyle(color: Colors.white70)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.cyanAccent,
                          overlayColor: Colors.cyanAccent.withOpacity(0.2),
                          trackHeight: 6,
                        ),
                        child: Slider(value: sensitivity.toDouble(), min: 1, max: 10, divisions: 9, label: '$sensitivity', onChanged: (v) => setC(() => sensitivity = v.round())),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Transform.scale(
                          scale: 1.1,
                          child: Checkbox(
                            value: onlyAi,
                            onChanged: (v) => setC(() => onlyAi = v ?? false),
                            checkColor: Colors.black,
                            activeColor: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text('Hanya yang terdeteksi AI', style: TextStyle(color: Colors.white70)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      const Text('Urutkan berdasarkan', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        _neonChip('relevance', 'Relevansi', sort, (v) => setC(() => sort = v)),
                        _neonChip('newest', 'Terbaru', sort, (v) => setC(() => sort = v)),
                        _neonChip('confidence', 'Kepercayaan', sort, (v) => setC(() => sort = v)),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              // reset filters to defaults
                              _searchFilters = {
                                'source': 'all',
                                'minConfidence': 50,
                                'sensitivityOverride': null,
                                'dateFrom': null,
                                'dateTo': null,
                                'onlyAi': false,
                                'sort': 'relevance',
                              };
                              Navigator.pop(ctx, _searchFilters);
                            }),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white12),
                              foregroundColor: Colors.white70,
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.cyanAccent, Colors.pinkAccent]),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.15), blurRadius: 10, spreadRadius: 1)],
                            ),
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, {
                                'source': source,
                                'minConfidence': minConf,
                                'sensitivityOverride': sensitivity,
                                'onlyAi': onlyAi,
                                'sort': sort,
                              }),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Terapkan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );

    if (result != null) {
      setState(() {
        _searchFilters = result;
      });
    }
  }

  // legacy filter chip removed in favor of neon-styled _neonChip

  Widget _neonChip(String value, String label, String selected, ValueChanged<String> onTap) {
    final bool active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.cyan.withOpacity(0.18) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.cyanAccent : Colors.white12),
          boxShadow: active
              ? [BoxShadow(color: Colors.cyan.withOpacity(0.12), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) const Icon(Icons.check, size: 14, color: Colors.cyanAccent),
            if (active) const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '98.7%',
            label: 'HIT RATE',
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
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: AnimationConfig.enableBackgroundAnimations 
                  ? Alignment.bottomRight 
                  : Alignment.center,
                colors: [
                  color.withOpacity(0.25),
                  color.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: color.withOpacity(_glowAnimation.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(_glowAnimation.value * 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
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
                        blurRadius: 10,
                      ),
                    ],
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
                    fontFamily: 'Orbitron',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
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
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.edit,
          title: 'EDITOR TEKS',
          subtitle: 'Deteksi AI real-time saat mengetik',
          gradient: [Colors.cyan, Colors.blue],
          onTap: () => _navigateTo(1),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.upload_file,
          title: 'UNGGAH FILE',
          subtitle: 'Analisis dokumen neural lanjutan',
          gradient: [Colors.purple, Colors.pink],
          onTap: () => _navigateTo(2),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.camera_alt,
          title: 'PEMINDAI',
          subtitle: 'OCR pemindaian real time',
          gradient: [Colors.pink, Colors.cyan],
          onTap: () => _navigateTo(3),
        ),
        const SizedBox(height: 15),
        _buildFeatureCard(
          icon: Icons.history,
          title: 'ARSIP DATA',
          subtitle: 'Database riwayat pemindaian lengkap',
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
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
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
                    gradient[0].withOpacity(0.4),
                    gradient[1].withOpacity(0.2),
                  ],
                ),
                border: Border.all(
                  color: gradient[0].withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
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
                            color: gradient[0].withOpacity(_glowAnimation.value * 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 15),
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
                              letterSpacing: 1.5,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          const SizedBox(height: 5),
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
                    Icon(
                      Icons.arrow_forward_ios,
                      color: gradient[0].withOpacity(_glowAnimation.value),
                      size: 20,
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

  void _navigateTo(int index) {
    if (widget.onNavTap != null) {
      widget.onNavTap!(index);
    }
  }

  Widget _buildFloatingParticles() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _rotateController,
        builder: (context, child) {
          return CustomPaint(
            painter: _HomeParticlesPainter(_rotateController.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _HomeParticlesPainter extends CustomPainter {
  final double animationValue;
  _HomeParticlesPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);

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