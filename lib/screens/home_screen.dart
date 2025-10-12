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
  late AnimationController _hexagonController;
  late AnimationController _dataStreamController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _hexagonAnimation;
  late Animation<double> _dataStreamAnimation;
  
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
    
    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _hexagonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _dataStreamController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    if (AnimationConfig.enableBackgroundAnimations) {
      _backgroundAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_backgroundController);

      _glowAnimation = Tween<double>(
        begin: 0.4,
        end: 0.9,
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
        begin: 0.97,
        end: 1.03,
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
      
      _hexagonAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_hexagonController);
      
      _dataStreamAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(_dataStreamController);
      
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
      _hexagonAnimation = AlwaysStoppedAnimation(0.0);
      _dataStreamAnimation = AlwaysStoppedAnimation(0.0);
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
    _hexagonController.dispose();
    _dataStreamController.dispose();
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
    final isSmallScreen = screenHeight < 700;
    
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
                // Lock the top area (header/search/stats) while making the features list scrollable
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16, // Fixed horizontal padding instead of percentage
                    isSmallScreen ? 8 : 16, // Reduced vertical padding for small screens
                    16,
                    isSmallScreen ? 8 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed top area
                      _buildHeader(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 8 : 16),
                      _buildSearchBar(),
                      SizedBox(height: isSmallScreen ? 12 : 20),
                      _buildStatsOverview(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 8 : 16),

                      // separator between fixed top and scrollable area
                      _buildTopSeparator(),

                      // Scrollable features area
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildFeatureCards(isSmallScreen),
                              SizedBox(height: 16),
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

  Widget _buildHeader(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Row(
          children: [
            Container(
              width: isSmallScreen ? 60 : 80, // Smaller icon for small screens
              height: isSmallScreen ? 60 : 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 25,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 20,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                Icons.home,
                color: Colors.white,
                size: isSmallScreen ? 30 : 40, // Smaller icon for small screens
              ),
            ),
            const SizedBox(width: 16),
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
                      'BERANDA',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 24 : 32, // Smaller font for small screens
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 3,
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

  Widget _buildSearchBar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: LayoutBuilder(builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced padding
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30), // Slightly smaller border radius
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade900.withOpacity(0.5),
                    Colors.purple.shade900.withOpacity(0.5),
                  ],
                ),
                border: Border.all(
                  color: Colors.cyan.withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
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
                          padding: const EdgeInsets.all(6), // Reduced padding
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyan.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(Icons.search, color: Colors.cyan.shade300, size: 20), // Smaller icon
                        ),
                      ),
                      const SizedBox(width: 10), // Reduced spacing
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
                          padding: const EdgeInsets.all(8), // Reduced padding
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan.withOpacity(_glowAnimation.value),
                                Colors.pink.withOpacity(_glowAnimation.value),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20), // Smaller icon
                        ),
                      ),
                    ],
                  ),

                  // Suggestions dropdown constrained to search box width so it won't widen parent
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: availableWidth - 8, // a little padding
                      constraints: const BoxConstraints(maxHeight: 150), // Reduced max height
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(12), // Smaller border radius
                        border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white12),
                        itemBuilder: (ctx, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(s, style: const TextStyle(color: Colors.white)),
                            leading: const Icon(Icons.history, color: Colors.white70, size: 16), // Smaller icon
                            onTap: () {
                              _searchController.text = s;
                              _onSearchSubmitted(s);
                            },
                          );
                        },
                      ),
                    ),

                  if (_loadingSuggestions) 
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(
                        minHeight: 2, // Reduced height
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.cyan.withOpacity(_glowAnimation.value),
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Reduced padding
      child: Container(
        height: 8, // Reduced height
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10), // Smaller border radius
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.cyan.withOpacity(0.1),
              Colors.transparent,
              Colors.pink.withOpacity(0.1),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 8, offset: const Offset(0, 2)),
            BoxShadow(color: Colors.cyan.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.deepPurple.withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Filter', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Orbitron')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                          child: const Text('Batal'),
                        ),
                      ]),
                      const SizedBox(height: 15),
                      const Text('Sumber', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        _neonChip('all', 'Semua', source, (v) => setC(() => source = v)),
                        _neonChip('history', 'Riwayat', source, (v) => setC(() => source = v)),
                        _neonChip('upload', 'Unggah', source, (v) => setC(() => source = v)),
                        _neonChip('camera', 'Kamera', source, (v) => setC(() => source = v)),
                        _neonChip('editor', 'Editor', source, (v) => setC(() => source = v)),
                      ]),
                      const SizedBox(height: 15),
                      Text('Kepercayaan minimum: $minConf%', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purpleAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.pinkAccent,
                          overlayColor: Colors.pinkAccent.withOpacity(0.3),
                          trackHeight: 8,
                        ),
                        child: Slider(value: minConf.toDouble(), min: 50, max: 100, divisions: 50, label: '$minConf%', onChanged: (v) => setC(() => minConf = v.round())),
                      ),
                      const SizedBox(height: 10),
                      Text('Penggantian sensitivitas: $sensitivity', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.cyanAccent,
                          overlayColor: Colors.cyanAccent.withOpacity(0.3),
                          trackHeight: 8,
                        ),
                        child: Slider(value: sensitivity.toDouble(), min: 1, max: 10, divisions: 9, label: '$sensitivity', onChanged: (v) => setC(() => sensitivity = v.round())),
                      ),
                      const SizedBox(height: 15),
                      Row(children: [
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: onlyAi,
                            onChanged: (v) => setC(() => onlyAi = v ?? false),
                            checkColor: Colors.black,
                            activeColor: Colors.cyanAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Text('Hanya yang terdeteksi AI', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ),
                      ]),
                      const SizedBox(height: 15),
                      const Text('Urutkan berdasarkan', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, children: [
                        _neonChip('relevance', 'Relevansi', sort, (v) => setC(() => sort = v)),
                        _neonChip('newest', 'Terbaru', sort, (v) => setC(() => sort = v)),
                        _neonChip('confidence', 'Kepercayaan', sort, (v) => setC(() => sort = v)),
                      ]),
                      const SizedBox(height: 20),
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
                              side: BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.cyanAccent, Colors.pinkAccent]),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)],
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Terapkan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _neonChip(String value, String label, String selected, ValueChanged<String> onTap) {
    final bool active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
        decoration: BoxDecoration(
          color: active ? Colors.cyan.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(12), // Smaller border radius
          border: Border.all(color: active ? Colors.cyanAccent : Colors.white24),
          boxShadow: active
              ? [BoxShadow(color: Colors.cyan.withOpacity(0.15), blurRadius: 10, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) const Icon(Icons.check, size: 14, color: Colors.cyanAccent), // Smaller icon
            if (active) const SizedBox(width: 4),
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 13)), // Smaller font
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '98.7%',
            label: 'HIT RATE',
            icon: Icons.verified,
            color: Colors.cyan,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 10), // Reduced spacing
        Expanded(
          child: _buildStatCard(
            value: '2.1s',
            label: 'SPEED',
            icon: Icons.bolt,
            color: Colors.pink,
            isSmallScreen: isSmallScreen,
          ),
        ),
        const SizedBox(width: 10), // Reduced spacing
        Expanded(
          child: _buildStatCard(
            value: '1.2k',
            label: 'SCANS',
            icon: Icons.analytics,
            color: Colors.purple,
            isSmallScreen: isSmallScreen,
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
    required bool isSmallScreen,
  }) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 18), // Reduced padding for small screens
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 18), // Smaller border radius
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: AnimationConfig.enableBackgroundAnimations 
                  ? Alignment.bottomRight 
                  : Alignment.center,
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
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 10), // Reduced padding for small screens
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
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24), // Smaller icon
                ),
                SizedBox(height: isSmallScreen ? 6 : 10), // Reduced spacing
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20, // Smaller font for small screens
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3 : 5), // Reduced spacing
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isSmallScreen ? 9 : 11, // Smaller font for small screens
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

  Widget _buildFeatureCards(bool isSmallScreen) {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.edit,
          title: 'EDITOR TEKS',
          subtitle: 'Deteksi AI saat mengetik',
          gradient: [Colors.cyan, Colors.blue],
          onTap: () => _navigateTo(1),
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(height: isSmallScreen ? 12 : 18), // Reduced spacing
        _buildFeatureCard(
          icon: Icons.upload_file,
          title: 'UNGGAH FILE',
          subtitle: 'Mulai analisis dokumen',
          gradient: [Colors.purple, Colors.pink],
          onTap: () => _navigateTo(2),
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(height: isSmallScreen ? 12 : 18), // Reduced spacing
        _buildFeatureCard(
          icon: Icons.camera_alt,
          title: 'PEMINDAI',
          subtitle: 'OCR pemindaian secara langsung',
          gradient: [Colors.pink, Colors.cyan],
          onTap: () => _navigateTo(3),
          isSmallScreen: isSmallScreen,
        ),
        SizedBox(height: isSmallScreen ? 12 : 18), // Reduced spacing
        _buildFeatureCard(
          icon: Icons.history,
          title: 'ARSIP DATA',
          subtitle: 'Database riwayat pemindaian',
          gradient: [Colors.blue, Colors.purple],
          onTap: () => _navigateTo(4),
          isSmallScreen: isSmallScreen,
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
    required bool isSmallScreen,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: isSmallScreen ? 90 : 110, // Reduced height for small screens
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 22), // Smaller border radius
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    gradient[0].withOpacity(0.5),
                    gradient[1].withOpacity(0.25),
                  ],
                ),
                border: Border.all(
                  color: gradient[0].withOpacity(_glowAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 20,
                    spreadRadius: 3,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 18), // Reduced padding
                child: Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 50 : 70, // Smaller for small screens
                      height: isSmallScreen ? 50 : 70, // Smaller for small screens
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 18), // Smaller border radius
                        boxShadow: [
                          BoxShadow(
                            color: gradient[0].withOpacity(_glowAnimation.value * 0.6),
                            blurRadius: 20,
                            spreadRadius: 3,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: isSmallScreen ? 25 : 35), // Smaller icon
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 18), // Reduced spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 18, // Smaller font for small screens
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                            SizedBox(height: isSmallScreen ? 4 : 6), // Reduced spacing
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isSmallScreen ? 11 : 13, // Smaller font for small screens
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
                      size: isSmallScreen ? 20 : 24, // Smaller icon
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
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Bottom border
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.pink.withOpacity(_glowAnimation.value),
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Left border
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 3,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Right border
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: 3,
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
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
      ..color = Colors.cyan.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);

    for (int i = 0; i < 30; i++) {
      final x = (random.nextDouble() * size.width);
      final y = (random.nextDouble() * size.height + animationValue * size.height) % size.height;
      final radius = random.nextDouble() * 3 + 1;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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