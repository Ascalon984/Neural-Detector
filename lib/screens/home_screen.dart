import 'package:flutter/material.dart';
import '../config/animation_config.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../widgets/no_scroll_behavior.dart';
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
  
  // Dashboard state
  String _selectedPeriod = 'daily'; // daily, weekly, monthly
  List<double> _aiRateData = [];
  List<int> _scanFreqData = [];
  
  // Search/filter state
  late TextEditingController _searchController;
  late Map<String, dynamic> _searchFilters;
  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _loadingSuggestions = false;
  
  // Tips & Insights state
  int _currentTipIndex = 0;
  Timer? _tipRotationTimer;
  final List<String> _tips = [
    'Model AI kami paling akurat saat menganalisis teks dengan lebih dari 100 kata. Untuk hasil terbaik, gunakan paragraf lengkap.',
    'Bahasa formal cenderung lebih mudah dideteksi sebagai AI daripada bahasa informal atau percakapan.',
    'Model AI kami telah dilatih dengan berbagai gaya penulisan, namun akurasi tertinggi dicapai pada teks akademis dan profesional.',
    'Pemindaian berulang pada dokumen yang sama dapat memberikan hasil yang sedikit berbeda karena faktor acak dalam algoritma.',
    'Untuk hasil yang paling akurat, pastikan teks yang dianalisis dalam bahasa yang konsisten tanpa campuran bahasa.',
    'Model kami lebih baik dalam mendeteksi konten yang dihasilkan oleh model AI terbaru daripada model yang lebih lama.',
    'Sensitivitas yang lebih tinggi dapat membantu mendeteksi konten AI yang lebih halus, tetapi juga dapat meningkatkan false positives.',
    'Hasil pemindaian paling andal untuk teks asli. Teks yang telah diedit secara signifikan mungkin memberikan hasil yang kurang akurat.',
    'Model kami secara teratur diperbarui dengan teknik deteksi terbaru untuk mengidentifikasi konten yang dihasilkan AI.',
    'Untuk analisis batch, pertimbangkan untuk menggunakan API kami untuk pemrosesan yang lebih efisien.'
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    // initialize search filters
    _searchFilters = {
      'source': 'all', // all/history/upload/editor
      'minConfidence': 50,
      'sensitivityOverride': null,
      'dateFrom': null,
      'dateTo': null,
      'onlyAi': false,
      'sort': 'relevance', // relevance/newest/confidence
    };

    // generate sample dashboard data
    _generateDashboardData();
    // Touch generated data so analyzer doesn't complain about unused fields
    if (_aiRateData.isNotEmpty || _scanFreqData.isNotEmpty) {
      final avgAi = _aiRateData.isNotEmpty ? _aiRateData.reduce((a, b) => a + b) / _aiRateData.length : 0.0;
      final totalScans = _scanFreqData.isNotEmpty ? _scanFreqData.fold<int>(0, (p, e) => p + e) : 0;
      // small debug output (kept intentionally) to mark data as used during development
      // ignore: avoid_print
      print('Dashboard sample data: avgAi=${avgAi.toStringAsFixed(1)}, totalScans=$totalScans');
    }
    
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

    // Initialize tip rotation timer
    _tipRotationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });

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

  void _generateDashboardData() {
    // Create simple deterministic sample data for charts so UI looks complete.
    final rnd = math.Random(42);
    if (_selectedPeriod == 'daily') {
      _aiRateData = List.generate(24, (i) => 40 + rnd.nextDouble() * 60); // hourly
      _scanFreqData = List.generate(24, (i) => 5 + rnd.nextInt(20));
    } else if (_selectedPeriod == 'weekly') {
      _aiRateData = List.generate(7, (i) => 30 + rnd.nextDouble() * 70); // days
      _scanFreqData = List.generate(7, (i) => 50 + rnd.nextInt(200));
    } else {
      // monthly (last 30 days)
      _aiRateData = List.generate(30, (i) => 35 + rnd.nextDouble() * 65);
      _scanFreqData = List.generate(30, (i) => 20 + rnd.nextInt(150));
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
    _tipRotationTimer?.cancel();
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
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final isNarrowScreen = screenWidth < 350;
    final isExtremelySmallScreen = screenWidth < 320;
    
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
          
          // Main content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep header fixed and make only the content below scrollable
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    isVerySmallScreen ? 8 : 12,
                    16,
                    isVerySmallScreen ? 8 : 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fixed Header
                      _buildHeader(isSmallScreen, isVerySmallScreen),
                      SizedBox(height: isVerySmallScreen ? 8 : 12),

                      // The rest of the page scrolls
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: const NoScrollbarBehavior(),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search bar
                                _buildSearchBar(isSmallScreen, isVerySmallScreen, isNarrowScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Tips & Insights Dashboard
                                _buildTipsDashboard(isSmallScreen, isVerySmallScreen, isNarrowScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Stats overview
                                _buildStatsOverview(isSmallScreen, isVerySmallScreen, isExtremelySmallScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Feature cards
                                _buildFeatureCards(isSmallScreen, isVerySmallScreen),
                                SizedBox(height: 16),
                              ],
                            ),
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

  Widget _buildHeader(bool isSmallScreen, bool isVerySmallScreen) {
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
                Icons.home,
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
                      'BERANDA',
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

  Widget _buildSearchBar(bool isSmallScreen, bool isVerySmallScreen, bool isNarrowScreen) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isVerySmallScreen ? 12 : 16,
                  // Reduced vertical padding to make the search box less tall
                  vertical: isVerySmallScreen ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 20 : 25),
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
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Search icon
                    GestureDetector(
                      onTap: () => _onSearchSubmitted(_searchController.text),
                        child: Container(
                        padding: EdgeInsets.all(isVerySmallScreen ? 3 : 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.cyan.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.search,
                          color: Colors.cyan.shade300,
                          size: isVerySmallScreen ? 16 : 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (q) => _onSearchSubmitted(q),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isVerySmallScreen ? 14 : 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Telusuri hasil pemindaian...',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: isVerySmallScreen ? 14 : 16,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _openFilterSheet,
                      icon: Container(
                        padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.cyan.withOpacity(_glowAnimation.value),
                              Colors.pink.withOpacity(_glowAnimation.value),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.tune,
                          color: Colors.white,
                          size: isVerySmallScreen ? 16 : 20,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Suggestions dropdown
              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: BoxConstraints(
                    maxHeight: isVerySmallScreen ? 120 : 150,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white12),
                    itemBuilder: (ctx, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          s,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isVerySmallScreen ? 13 : 14,
                          ),
                        ),
                        leading: Icon(
                          Icons.history,
                          color: Colors.white70,
                          size: isVerySmallScreen ? 14 : 16,
                        ),
                        onTap: () {
                          _searchController.text = s;
                          _onSearchSubmitted(s);
                        },
                      );
                    },
                  ),
                ),

              // Loading indicator
              if (_loadingSuggestions) 
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.cyan.withOpacity(_glowAnimation.value),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipsDashboard(bool isSmallScreen, bool isVerySmallScreen, bool isNarrowScreen) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {

        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(_glowAnimation.value * 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tips & Wawasan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isVerySmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentTipIndex = (_currentTipIndex - 1) % _tips.length;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white10,
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white70,
                              size: isVerySmallScreen ? 14 : 16,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white10,
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.white70,
                              size: isVerySmallScreen ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isVerySmallScreen ? 6 : 8),
                Container(
                  padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(0.1),
                        Colors.purple.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.cyan,
                            size: isSmallScreen ? 16 : 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tips Hari Ini',
                            style: TextStyle(
                              color: Colors.cyan,
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _tips[_currentTipIndex],
                          key: ValueKey<int>(_currentTipIndex),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: isSmallScreen ? 11 : 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _tips.length,
                          (index) => Container(
                            width: 6,
                            height: 6,
                            margin: EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == _currentTipIndex
                                  ? Colors.cyan
                                  : Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isVerySmallScreen ? 6 : 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInsightCard(
                        icon: Icons.trending_up,
                        title: 'Tingkat Akurasi',
                        value: '98.7%',
                        color: Colors.green,
                        isSmall: isSmallScreen || isVerySmallScreen,
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 6 : 10),
                    Expanded(
                      child: _buildInsightCard(
                        icon: Icons.speed,
                        title: 'Kecepatan Rata-rata',
                        value: '2.1s',
                        color: Colors.purple,
                        isSmall: isSmallScreen || isVerySmallScreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isSmall,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: isSmall ? 16 : 18,
              ),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmall ? 10 : 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isSmall ? 14 : 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(bool isSmallScreen, bool isVerySmallScreen, bool isExtremelySmallScreen) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Stat cards removed per user request — return empty placeholder to keep layout stable
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  // _buildCompactStatCard removed — previously used to render four small stat cards

  Widget _buildFeatureCards(bool isSmallScreen, bool isVerySmallScreen) {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.edit,
          title: 'EDITOR TEKS',
          subtitle: 'Deteksi AI Saat Mengetik',
          gradient: [Colors.cyan, Colors.blue],
          onTap: () => _navigateTo(1),
          isSmallScreen: isSmallScreen,
          isVerySmallScreen: isVerySmallScreen,
        ),
        SizedBox(height: isVerySmallScreen ? 8 : 12),
        _buildFeatureCard(
          icon: Icons.upload_file,
          title: 'UNGGAH FILE',
          subtitle: 'Mulai Analisis Dokumen',
          gradient: [Colors.purple, Colors.pink],
          onTap: () => _navigateTo(2),
          isSmallScreen: isSmallScreen,
          isVerySmallScreen: isVerySmallScreen,
        ),
        SizedBox(height: isVerySmallScreen ? 8 : 12),
        _buildFeatureCard(
          icon: Icons.history,
          title: 'ARSIP DATA',
          subtitle: 'Riwayat Pemindaian',
          gradient: [Colors.blue, Colors.purple],
          onTap: () => _navigateTo(3),
          isSmallScreen: isSmallScreen,
          isVerySmallScreen: isVerySmallScreen,
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
    required bool isVerySmallScreen,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: isVerySmallScreen ? 70 : (isSmallScreen ? 80 : 90),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : 16),
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
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradient[0].withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(isVerySmallScreen ? 10 : 14),
                child: Row(
                  children: [
                    Container(
                      width: isVerySmallScreen ? 40 : (isSmallScreen ? 45 : 50),
                      height: isVerySmallScreen ? 40 : (isSmallScreen ? 45 : 50),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 10 : 12),
                        boxShadow: [
                          BoxShadow(
                            color: gradient[0].withOpacity(_glowAnimation.value * 0.6),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 25),
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 16),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          SizedBox(height: isVerySmallScreen ? 2 : 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 12),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: gradient[0].withOpacity(_glowAnimation.value),
                      size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
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
          // Only bottom border for navbar
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

  void _onSearchSubmitted(String q) {
    // For now: do a simple action — in real app, integrate search/index and scan
    if (q.trim().isEmpty) return;
    final filters = Map<String, dynamic>.from(_searchFilters);
    if (widget.onNavTap != null) {
      // set bridge so History screen can pick it up and then switch tab to history index (now 3)
      SearchBridge.set(q, filters);
      widget.onNavTap!(3);
      return;
    }

    // fallback: push history screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          initialQuery: q,
          initialFilters: filters,
        ),
      ),
    );
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            style: TextButton.styleFrom(foregroundColor: Colors.white70),
                            child: const Text('Batal'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Sumber',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _neonChip('all', 'Semua', source, (v) => setC(() => source = v)),
                          _neonChip('history', 'Riwayat', source, (v) => setC(() => source = v)),
                          _neonChip('upload', 'Unggah', source, (v) => setC(() => source = v)),
                          _neonChip('editor', 'Editor', source, (v) => setC(() => source = v)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Kepercayaan minimum: $minConf%',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.purpleAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.pinkAccent,
                          overlayColor: Colors.pinkAccent.withOpacity(0.3),
                          trackHeight: 8,
                        ),
                        child: Slider(
                          value: minConf.toDouble(),
                          min: 50,
                          max: 100,
                          divisions: 50,
                          label: '$minConf%',
                          onChanged: (v) => setC(() => minConf = v.round()),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Penggantian sensitivitas: $sensitivity',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.cyanAccent,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.cyanAccent,
                          overlayColor: Colors.cyanAccent.withOpacity(0.3),
                          trackHeight: 8,
                        ),
                        child: Slider(
                          value: sensitivity.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '$sensitivity',
                          onChanged: (v) => setC(() => sensitivity = v.round()),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
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
                            child: Text(
                              'Hanya yang terdeteksi AI',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Urutkan berdasarkan',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          _neonChip('relevance', 'Relevansi', sort, (v) => setC(() => sort = v)),
                          _neonChip('newest', 'Terbaru', sort, (v) => setC(() => sort = v)),
                          _neonChip('confidence', 'Kepercayaan', sort, (v) => setC(() => sort = v)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
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
                                side: const BorderSide(color: Colors.white24),
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
                                gradient: const LinearGradient(
                                  colors: [Colors.cyanAccent, Colors.pinkAccent],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyan.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
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
                                child: const Text(
                                  'Terapkan',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.cyan.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? Colors.cyanAccent : Colors.white24),
          boxShadow: active
              ? [BoxShadow(color: Colors.cyan.withOpacity(0.15), blurRadius: 10, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active) const Icon(Icons.check, size: 14, color: Colors.cyanAccent),
            if (active) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    if (widget.onNavTap != null) {
      widget.onNavTap!(index);
    }
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