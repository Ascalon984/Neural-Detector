import 'package:flutter/material.dart';
import '../config/animation_config.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import '../widgets/no_scroll_behavior.dart';
import '../data/search_index.dart';
import 'history_screen.dart';
import '../utils/search_bridge.dart';
import '../utils/history_manager.dart';
import '../models/scan_history.dart' as Model;
import '../utils/live_analysis_bridge.dart';
import '../models/chart_statistics.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavTap;
  final int currentIndex;

  const HomeScreen({super.key, this.onNavTap, this.currentIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _backgroundController;
  late AnimationController _glowController;
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _glitchController;
  late AnimationController _hexagonController;
  late AnimationController _dataStreamController;
  
  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _hexagonAnimation;
  late Animation<double> _dataStreamAnimation;
  
  // Dashboard State - IMPROVED
  String _selectedPeriod = '1d';
  ChartStatistics _aiRateStats = ChartStatistics.empty('1d');
  ChartStatistics _scanFreqStats = ChartStatistics.empty('1d');
  
  // Search/Filter State
  late TextEditingController _searchController;
  late Map<String, dynamic> _searchFilters;
  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _loadingSuggestions = false;

  // Data Subscriptions
  StreamSubscription<Model.ScanHistory>? _historySub;
  StreamSubscription<LiveAnalysis>? _liveSub;

  @override
  void initState() {
    super.initState();
    _initializeSearch();
    _initializeData();
    _setupDataSubscriptions();
    _initializeAnimations();
  }

  // ============ SEARCH INITIALIZATION ============
  void _initializeSearch() {
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    
    _searchFilters = {
      'source': 'all',
      'minConfidence': 50,
      'sensitivityOverride': null,
      'dateFrom': null,
      'dateTo': null,
      'onlyAi': false,
      'sort': 'relevance',
    };
  }

  // ============ DATA INITIALIZATION ============
  void _initializeData() async {
    try {
      await _loadChartData();
    } catch (e) {
      print('Error initializing chart data: $e');
      // Set empty data on error
      if (mounted) {
        setState(() {
          _aiRateStats = ChartStatistics.empty(_selectedPeriod);
          _scanFreqStats = ChartStatistics.empty(_selectedPeriod);
        });
      }
    }
  }

  void _setupDataSubscriptions() {
    // Subscribe to live editor analyses
    _liveSub = LiveAnalysisBridge().stream.listen((entry) {
      if (!mounted) return;
      _handleNewAnalysis(entry);
    });
    
    // Subscribe to history additions
    _historySub = HistoryManager.onNewEntry.listen((entry) {
      if (!mounted) return;
      _handleNewHistoryEntry(entry);
    });
  }

  void _handleNewAnalysis(LiveAnalysis entry) {
    _loadChartData(); // Reload data untuk konsistensi
  }

  void _handleNewHistoryEntry(Model.ScanHistory entry) {
    _loadChartData(); // Reload data untuk konsistensi
  }

  // ============ CHART DATA PROCESSING ============
  Future<void> _loadChartData() async {
    try {
      final historyData = await HistoryManager.loadHistory();
      final liveData = LiveAnalysisBridge().recent;
      
      final allDataPoints = await _combineAndProcessData(historyData, liveData);
      
      if (mounted) {
        setState(() {
          _aiRateStats = _calculateAiRateStatistics(allDataPoints, _selectedPeriod);
          _scanFreqStats = _calculateScanFrequencyStatistics(allDataPoints, _selectedPeriod);
        });
      }
    } catch (e) {
      print('Error loading chart data: $e');
      if (mounted) {
        setState(() {
          _aiRateStats = ChartStatistics.empty(_selectedPeriod);
          _scanFreqStats = ChartStatistics.empty(_selectedPeriod);
        });
      }
    }
  }

  Future<List<ChartDataPoint>> _combineAndProcessData(
    List<Model.ScanHistory> historyData, 
    List<LiveAnalysis> liveData
  ) async {
    final allDataPoints = <ChartDataPoint>[];
    
    // Process history data
    for (final history in historyData) {
      try {
        final timestamp = _parseHistoryTimestamp(history.date);
        final dataPoint = ChartDataPoint(
          timestamp: timestamp,
          aiPercentage: history.aiDetection.toDouble(),
          scanCount: 1,
        );
        allDataPoints.add(dataPoint);
      } catch (e) {
        print('Error parsing history entry: $e');
      }
    }
    
    // Process live data
    for (final live in liveData) {
      try {
        final dataPoint = ChartDataPoint(
          timestamp: live.time.toLocal(),
          aiPercentage: live.aiPercent,
          scanCount: 1,
        );
        allDataPoints.add(dataPoint);
      } catch (e) {
        print('Error parsing live analysis: $e');
      }
    }
    
    // Sort by timestamp (oldest first)
    allDataPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return allDataPoints;
  }

  DateTime _parseHistoryTimestamp(String dateString) {
    try {
      final normalizedDate = dateString.replaceFirst(' ', 'T');
      return DateTime.parse(normalizedDate).toLocal();
    } catch (e) {
      print('Failed to parse date: $dateString, using current time');
      return DateTime.now().toLocal();
    }
  }

  ChartStatistics _calculateAiRateStatistics(List<ChartDataPoint> allData, String period) {
    final filteredData = _filterDataByPeriod(allData, period);
    
    if (filteredData.isEmpty) {
      return ChartStatistics.empty(period);
    }
    
    final bucketedData = _bucketDataByTime(filteredData, period);
    
    // Calculate average AI percentage per bucket
    final averagedData = bucketedData.asMap().entries.map((entry) {
      final index = entry.key;
      final bucket = entry.value;
      
      if (bucket.isEmpty) {
        return ChartDataPoint(
          timestamp: _getBaseTimeForBucket(period, index),
          aiPercentage: 0.0,
          scanCount: 0,
        );
      }
      
      final totalAi = bucket.map((point) => point.aiPercentage).reduce((a, b) => a + b);
      final averageAi = totalAi / bucket.length;
      
      return ChartDataPoint(
        timestamp: bucket.first.timestamp,
        aiPercentage: averageAi,
        scanCount: bucket.length,
      );
    }).toList();
    
    // Calculate overall average
    final overallAverage = filteredData.map((point) => point.aiPercentage).reduce((a, b) => a + b) / filteredData.length;
    
    return ChartStatistics(
      dataPoints: averagedData,
      averageAiPercentage: double.parse(overallAverage.toStringAsFixed(1)),
      totalScans: filteredData.length,
      period: period,
    );
  }

  ChartStatistics _calculateScanFrequencyStatistics(List<ChartDataPoint> allData, String period) {
    final filteredData = _filterDataByPeriod(allData, period);
    
    if (filteredData.isEmpty) {
      return ChartStatistics.empty(period);
    }
    
    final bucketedData = _bucketDataByTime(filteredData, period);
    
    // Create data points with scan count per bucket
    final frequencyData = bucketedData.asMap().entries.map((entry) {
      final index = entry.key;
      final bucket = entry.value;
      
      return ChartDataPoint(
        timestamp: _getBaseTimeForBucket(period, index),
        aiPercentage: 0.0,
        scanCount: bucket.length,
      );
    }).toList();
    
    return ChartStatistics(
      dataPoints: frequencyData,
      averageAiPercentage: 0.0,
      totalScans: filteredData.length,
      period: period,
    );
  }

  List<ChartDataPoint> _filterDataByPeriod(List<ChartDataPoint> data, String period) {
    final now = DateTime.now().toLocal();
    final cutoff = _getCutoffDate(period, now);
    
    return data.where((point) => point.timestamp.isAfter(cutoff)).toList();
  }

  DateTime _getCutoffDate(String period, DateTime now) {
    switch (period) {
      case '1d':
        return now.subtract(const Duration(days: 1));
      case '3d':
        return now.subtract(const Duration(days: 3));
      case '7d':
        return now.subtract(const Duration(days: 7));
      default:
        return now.subtract(const Duration(days: 1));
    }
  }

  List<List<ChartDataPoint>> _bucketDataByTime(List<ChartDataPoint> data, String period) {
    final buckets = <List<ChartDataPoint>>[];
    final now = DateTime.now().toLocal();
    
    switch (period) {
      case '1d':
        // 24 buckets for hours
        for (int i = 0; i < 24; i++) {
          final hourStart = DateTime(now.year, now.month, now.day).subtract(Duration(hours: 23 - i));
          final hourEnd = hourStart.add(const Duration(hours: 1));
          final bucket = data.where((point) => 
            point.timestamp.isAfter(hourStart) && point.timestamp.isBefore(hourEnd)
          ).toList();
          buckets.add(bucket);
        }
        break;
        
      case '3d':
        // 18 buckets (6 per day, 4-hour windows)
        for (int i = 0; i < 18; i++) {
          final hoursAgo = (17 - i) * 4;
          final windowStart = now.subtract(Duration(hours: hoursAgo + 4));
          final windowEnd = windowStart.add(const Duration(hours: 4));
          final bucket = data.where((point) => 
            point.timestamp.isAfter(windowStart) && point.timestamp.isBefore(windowEnd)
          ).toList();
          buckets.add(bucket);
        }
        break;
        
      case '7d':
        // 7 buckets for days
        for (int i = 0; i < 7; i++) {
          final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
          final dayEnd = dayStart.add(const Duration(days: 1));
          final bucket = data.where((point) => 
            point.timestamp.isAfter(dayStart) && point.timestamp.isBefore(dayEnd)
          ).toList();
          buckets.add(bucket);
        }
        break;
    }
    
    return buckets;
  }

  DateTime _getBaseTimeForBucket(String period, int index) {
    final now = DateTime.now().toLocal();
    
    switch (period) {
      case '1d':
        return DateTime(now.year, now.month, now.day).add(Duration(hours: index));
      case '3d':
        return now.subtract(Duration(hours: (17 - index) * 4));
      case '7d':
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index));
      default:
        return now;
    }
  }

  void _onPeriodChanged(String newPeriod) {
    setState(() {
      _selectedPeriod = newPeriod;
    });
    _loadChartData();
  }

  // ============ ANIMATION INITIALIZATION ============
  void _initializeAnimations() {
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
      duration: const Duration(seconds: 2, milliseconds: 500),
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
      
      Future.delayed(Duration(seconds: 5 + math.Random().nextInt(10)), () {
        if (mounted) {
          _triggerGlitch();
        }
      });
    }
  }

  // ============ DISPOSE ============
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
    _historySub?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }

  // ============ SEARCH METHODS ============
  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _loadingSuggestions = false;
          });
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _loadingSuggestions = true;
        });
      }
      
      final suggestions = await SearchIndex.searchSuggestions(query, _searchFilters);
      
      if (!mounted) return;
      
      setState(() {
        _suggestions = suggestions;
        _loadingSuggestions = false;
      });
    });
  }

  void _onSearchSubmitted(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    
    final filters = Map<String, dynamic>.from(_searchFilters);
    
    if (widget.onNavTap != null) {
      SearchBridge.set(trimmedQuery, filters);
      widget.onNavTap!(3); // Navigate to history tab
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          initialQuery: trimmedQuery,
          initialFilters: filters,
        ),
      ),
    );
  }

  // ============ BUILD METHOD ============
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
          // Background Effects
          _buildAnimatedBackground(),
          _buildHexagonGridOverlay(),
          _buildDataStreamEffect(),
          _buildScanLine(),
          _buildGlitchEffect(),
          
          // Main Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
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

                      // Scrollable Content
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: const NoScrollbarBehavior(),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search Bar
                                _buildSearchBar(isSmallScreen, isVerySmallScreen, isNarrowScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Mini Dashboard with IMPROVED Charts
                                _buildMiniDashboard(isSmallScreen, isVerySmallScreen, isNarrowScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Stats Overview
                                _buildStatsOverview(isSmallScreen, isVerySmallScreen, isExtremelySmallScreen),
                                SizedBox(height: isVerySmallScreen ? 8 : 12),

                                // Feature Cards
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
          
          // Cyberpunk Frame
          _buildCyberpunkFrame(),
        ],
      ),
    );
  }

  // ============ BACKGROUND EFFECT WIDGETS ============
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

  // ============ MAIN CONTENT WIDGETS ============
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
                  vertical: isVerySmallScreen ? 8 : 12,
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
                    GestureDetector(
                      onTap: () => _onSearchSubmitted(_searchController.text),
                      child: Container(
                        padding: EdgeInsets.all(isVerySmallScreen ? 4 : 6),
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
                        onSubmitted: _onSearchSubmitted,
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
                        padding: EdgeInsets.all(isVerySmallScreen ? 6 : 8),
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
                      final suggestion = _suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          suggestion,
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
                          _searchController.text = suggestion;
                          _onSearchSubmitted(suggestion);
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

  Widget _buildMiniDashboard(bool isSmallScreen, bool isVerySmallScreen, bool isNarrowScreen) {
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
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    ToggleButtons(
                      isSelected: [
                        _selectedPeriod == '1d',
                        _selectedPeriod == '3d',
                        _selectedPeriod == '7d'
                      ],
                      onPressed: (index) {
                        final newPeriod = index == 0 ? '1d' : index == 1 ? '3d' : '7d';
                        _onPeriodChanged(newPeriod);
                      },
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white70,
                      selectedColor: Colors.black,
                      fillColor: Colors.cyanAccent,
                      constraints: BoxConstraints(
                        minWidth: isVerySmallScreen ? 28 : 32,
                        minHeight: isVerySmallScreen ? 24 : 28,
                      ),
                      children: const [
                        Text('1D', style: TextStyle(fontSize: 12)),
                        Text('3D', style: TextStyle(fontSize: 12)),
                        Text('7D', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isVerySmallScreen ? 6 : 8),

                // IMPROVED Charts with new data structure
                Row(
                  children: [
                    Expanded(
                      child: _MiniChartCard(
                        title: 'AI Rate (avg %)',
                        subtitle: 'Rata-rata: ${_aiRateStats.averageAiPercentage}%',
                        isSmall: isSmallScreen || isVerySmallScreen,
                        child: CustomPaint(
                          size: Size(
                            double.infinity,
                            isVerySmallScreen ? 50 : (isSmallScreen ? 60 : 80),
                          ),
                          painter: _LineChartPainter(
                            _aiRateStats.dataPoints.map((point) => point.aiPercentage).toList(),
                            Colors.cyanAccent.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isVerySmallScreen ? 6 : 10),
                    Expanded(
                      child: _MiniChartCard(
                        title: 'Scan frequency',
                        subtitle: 'Total: ${_scanFreqStats.totalScans} scans',
                        isSmall: isSmallScreen || isVerySmallScreen,
                        child: CustomPaint(
                          size: Size(
                            double.infinity,
                            isVerySmallScreen ? 50 : (isSmallScreen ? 60 : 80),
                          ),
                          painter: _BarLineChartPainter(
                            _scanFreqStats.dataPoints.map((point) => point.scanCount.toDouble()).toList(),
                            Colors.pinkAccent.withOpacity(0.9),
                          ),
                        ),
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

  Widget _buildStatsOverview(bool isSmallScreen, bool isVerySmallScreen, bool isExtremelySmallScreen) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double gap = isExtremelySmallScreen ? 4 : (isVerySmallScreen ? 6 : 12);
              final double totalGaps = isExtremelySmallScreen ? gap : (gap * 3);
              final double perCardMax = isExtremelySmallScreen 
                  ? (constraints.maxWidth - gap) / 2.0
                  : (constraints.maxWidth - totalGaps).clamp(0.0, constraints.maxWidth) / 4.0;

              Widget constrainedCard(Widget card) => ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: perCardMax),
                    child: Flexible(child: card),
                  );

              if (isExtremelySmallScreen) {
                return Column(
                  children: [
                    Row(
                      children: [
                        constrainedCard(_buildCompactStatCard(
                          value: '98.7%',
                          label: 'HIT RATE',
                          icon: Icons.verified,
                          color: Colors.cyan,
                          isSmall: isSmallScreen || isVerySmallScreen,
                          isVerySmall: isVerySmallScreen,
                          isExtremelySmall: isExtremelySmallScreen,
                        )),
                        SizedBox(width: gap),
                        constrainedCard(_buildCompactStatCard(
                          value: '2.1s',
                          label: 'SPEED',
                          icon: Icons.bolt,
                          color: Colors.pink,
                          isSmall: isSmallScreen || isVerySmallScreen,
                          isVerySmall: isVerySmallScreen,
                          isExtremelySmall: isExtremelySmallScreen,
                        )),
                      ],
                    ),
                    SizedBox(height: gap),
                    Row(
                      children: [
                        constrainedCard(_buildCompactStatCard(
                          value: '1.2k',
                          label: 'VOLUME',
                          icon: Icons.folder_open,
                          color: Colors.purple,
                          isSmall: isSmallScreen || isVerySmallScreen,
                          isVerySmall: isVerySmallScreen,
                          isExtremelySmall: isExtremelySmallScreen,
                        )),
                        SizedBox(width: gap),
                        constrainedCard(_buildCompactStatCard(
                          value: '94.3%',
                          label: 'EFFICIENCY',
                          icon: Icons.speed,
                          color: Colors.green,
                          isSmall: isSmallScreen || isVerySmallScreen,
                          isVerySmall: isVerySmallScreen,
                          isExtremelySmall: isExtremelySmallScreen,
                        )),
                      ],
                    ),
                  ],
                );
              }
              
              return Row(
                children: [
                  constrainedCard(_buildCompactStatCard(
                    value: '98.7%',
                    label: 'RATE',
                    icon: Icons.verified,
                    color: Colors.cyan,
                    isSmall: isSmallScreen || isVerySmallScreen,
                    isVerySmall: isVerySmallScreen,
                    isExtremelySmall: isExtremelySmallScreen,
                  )),
                  SizedBox(width: gap),
                  constrainedCard(_buildCompactStatCard(
                    value: '2.1s',
                    label: 'SPEED',
                    icon: Icons.bolt,
                    color: Colors.pink,
                    isSmall: isSmallScreen || isVerySmallScreen,
                    isVerySmall: isVerySmallScreen,
                    isExtremelySmall: isExtremelySmallScreen,
                  )),
                  SizedBox(width: gap),
                  constrainedCard(_buildCompactStatCard(
                    value: '1.2k',
                    label: 'VOL',
                    icon: Icons.folder_open,
                    color: Colors.purple,
                    isSmall: isSmallScreen || isVerySmallScreen,
                    isVerySmall: isVerySmallScreen,
                    isExtremelySmall: isExtremelySmallScreen,
                  )),
                  SizedBox(width: gap),
                  constrainedCard(_buildCompactStatCard(
                    value: '94.3%',
                    label: 'EFF',
                    icon: Icons.speed,
                    color: Colors.green,
                    isSmall: isSmallScreen || isVerySmallScreen,
                    isVerySmall: isVerySmallScreen,
                    isExtremelySmall: isExtremelySmallScreen,
                  )),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCompactStatCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSmall,
    required bool isVerySmall,
    bool isExtremelySmall = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isExtremelySmall ? 4 : (isVerySmall ? 6 : (isSmall ? 8 : 10)),
            vertical: isExtremelySmall ? 4 : (isVerySmall ? 6 : (isSmall ? 8 : 10)),
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(isExtremelySmall ? 8 : 12),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(isExtremelySmall ? 2 : (isVerySmall ? 4 : 6)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.95),
                      color.withOpacity(0.6),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_glowAnimation.value * 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isExtremelySmall ? 12 : (isVerySmall ? 14 : (isSmall ? 16 : 18)),
                ),
              ),
              SizedBox(width: isExtremelySmall ? 4 : (isVerySmall ? 6 : 8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: isExtremelySmall ? 10 : (isVerySmall ? 12 : (isSmall ? 14 : 16)),
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: const Color.fromARGB(179, 255, 255, 255),
                            fontSize: isExtremelySmall ? 7 : (isVerySmall ? 8 : (isSmall ? 10 : 11)),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  // ============ FILTER SHEET ============
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
          child: StatefulBuilder(builder: (context, setState) {
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
                          _neonChip('all', 'Semua', source, (v) => setState(() => source = v)),
                          _neonChip('history', 'Riwayat', source, (v) => setState(() => source = v)),
                          _neonChip('upload', 'Unggah', source, (v) => setState(() => source = v)),
                          _neonChip('editor', 'Editor', source, (v) => setState(() => source = v)),
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
                          onChanged: (value) => setState(() => minConf = value.round()),
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
                          onChanged: (value) => setState(() => sensitivity = value.round()),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: onlyAi,
                              onChanged: (value) => setState(() => onlyAi = value ?? false),
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
                          _neonChip('relevance', 'Relevansi', sort, (v) => setState(() => sort = v)),
                          _neonChip('newest', 'Terbaru', sort, (v) => setState(() => sort = v)),
                          _neonChip('confidence', 'Kepercayaan', sort, (v) => setState(() => sort = v)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _searchFilters = {
                                    'source': 'all',
                                    'minConfidence': 50,
                                    'sensitivityOverride': null,
                                    'dateFrom': null,
                                    'dateTo': null,
                                    'onlyAi': false,
                                    'sort': 'relevance',
                                  };
                                });
                                Navigator.pop(ctx, _searchFilters);
                              },
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

// ============ SUPPORTING WIDGETS ============
class _MiniChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool isSmall;
  
  const _MiniChartCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isSmall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmall ? 10 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: isSmall ? 2 : 4),
          SizedBox(
            height: isSmall ? 50 : 60,
            child: child,
          ),
          SizedBox(height: isSmall ? 2 : 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmall ? 8 : 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  
  _LineChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    const double leftPadding = 28.0;

    if (data.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Belum ada data',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(minWidth: 0, maxWidth: size.width - leftPadding);

      final offset = Offset(leftPadding + (size.width - leftPadding - textPainter.width) / 2, (size.height - textPainter.height) / 2);
      textPainter.paint(canvas, offset);
      return;
    }

    final List<double> fixedData = data.map((d) => d.clamp(0.0, 100.0)).toList();

    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(color: Colors.white54, fontSize: 10);
    const ticks = [0, 25, 50, 75, 100];
    for (final tick in ticks) {
      final normalizedY = 1.0 - (tick / 100.0);
      final y = normalizedY * size.height;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);

      final textPainter = TextPainter(
        text: TextSpan(text: '$tick', style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(minWidth: 0, maxWidth: leftPadding - 4);
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 4, y - textPainter.height / 2));
    }

    final path = Path();
    final denominator = (fixedData.length - 1) <= 0 ? 1 : (fixedData.length - 1);
    for (int i = 0; i < fixedData.length; i++) {
      final x = leftPadding + (i / denominator) * (size.width - leftPadding);
      final normalizedValue = (fixedData[i] / 100.0).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPaint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(leftPadding, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    final glowPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    final markerPaint = Paint()..color = color;
    for (int i = 0; i < fixedData.length; i++) {
      final x = leftPadding + (i / denominator) * (size.width - leftPadding);
      final normalizedValue = (fixedData[i] / 100.0).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);
      canvas.drawCircle(Offset(x, y), 2.0, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BarLineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  
  _BarLineChartPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    const double leftPadding = 28.0;

    if (data.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Belum ada data',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(minWidth: 0, maxWidth: size.width - leftPadding);

      final offset = Offset(leftPadding + (size.width - leftPadding - textPainter.width) / 2, (size.height - textPainter.height) / 2);
      textPainter.paint(canvas, offset);
      return;
    }

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final rawRange = (max - min) == 0 ? 1.0 : (max - min).toDouble();
    final range = rawRange < 5.0 ? 5.0 : rawRange;

    final gridPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(color: Colors.white54, fontSize: 10);
    final mid = (min + max) / 2.0;
    final labels = [min, mid, max].map((v) => v.round()).toList();
    for (int i = 0; i < 3; i++) {
      final value = i == 0 ? min : (i == 1 ? mid : max);
      final normalizedValue = (value - min) / range;
      final y = size.height - (normalizedValue * size.height);
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
      final textPainter = TextPainter(
        text: TextSpan(text: '${labels[i]}', style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(minWidth: 0, maxWidth: leftPadding - 4);
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 4, y - textPainter.height / 2));
    }

    final path = Path();
    final denominator = (data.length - 1) <= 0 ? 1 : (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (i / denominator) * (size.width - leftPadding);
      final normalizedValue = ((data[i] - min) / range).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(leftPadding, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(path, paint);
    final markerPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (i / denominator) * (size.width - leftPadding);
      final normalizedValue = ((data[i] - min) / range).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);
      canvas.drawCircle(Offset(x, y), 1.8, markerPaint);
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
    final verticalDistance = hexHeight * 3 / 4;

    int columns = (size.width / hexWidth).ceil() + 1;
    int rows = (size.height / verticalDistance).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final x = col * hexWidth + (row % 2) * hexWidth / 2;
        final y = row * verticalDistance;
        
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