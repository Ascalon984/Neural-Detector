import 'package:flutter/material.dart';
import '../config/animation_config.dart';
import '../utils/history_manager.dart';
import '../models/scan_history.dart' as Model;
import '../utils/app_localizations.dart';
import 'dart:math' as math;
import '../data/search_index.dart';
import '../utils/search_bridge.dart';
import '../widgets/no_scroll_behavior.dart';

// Global tooltip manager: ensures only one overlay tooltip is visible at a time
OverlayEntry? _activeTooltipOverlay;
void _showGlobalTooltip(OverlayEntry entry, OverlayState overlay) {
  // remove any existing tooltip first
  try {
    _activeTooltipOverlay?.remove();
  } catch (_) {}
  _activeTooltipOverlay = entry;
  overlay.insert(entry);
}
void _hideGlobalTooltip() {
  try {
    _activeTooltipOverlay?.remove();
  } catch (_) {}
  _activeTooltipOverlay = null;
}

class HistoryScreen extends StatefulWidget {
  final String? initialQuery;
  final Map<String, dynamic>? initialFilters;

  const HistoryScreen({super.key, this.initialQuery, this.initialFilters});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
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
  late Animation<double> _glitchAnimation;
  late Animation<double> _hexagonAnimation;
  late Animation<double> _dataStreamAnimation;

  List<Model.ScanHistory> _scanHistory = [];
  int _aiAvg = 0;
  int _humanAvg = 0;
  SortOption _currentSort = SortOption.newest;
  final ScrollController _scrollController = ScrollController();
  bool _showGraph = false;
  // This map is populated for potential grouped views; currently not read in all code paths.
  // ignore: unused_field
  Map<String, List<Model.ScanHistory>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    
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
      
      _glitchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _glitchController,
        curve: Curves.easeInOut,
      ));
      
      _hexagonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_hexagonController);
      
      _dataStreamAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_dataStreamController);
      
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
      _glitchAnimation = AlwaysStoppedAnimation(0.0);
      _hexagonAnimation = AlwaysStoppedAnimation(0.0);
      _dataStreamAnimation = AlwaysStoppedAnimation(0.0);
    }

    _loadHistory();
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    List<Model.ScanHistory> list;
    final qFromBridge = (widget.initialQuery == null) ? SearchBridge.consumeQuery() : null;
    final fFromBridge = (widget.initialFilters == null) ? SearchBridge.consumeFilters() : null;

    final query = widget.initialQuery ?? qFromBridge ?? '';
    final filters = widget.initialFilters ?? fFromBridge;

    if (query.isNotEmpty || filters != null) {
      list = await SearchIndex.fullSearch(query, filters ?? {});
    } else {
      list = await HistoryManager.loadHistory();
    }
    
    final Map<String, List<Model.ScanHistory>> grouped = {};
    for (var item in list) {
      final dt = _parseDate(item.date);
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    setState(() {
      _scanHistory = list;
      _groupedHistory = grouped;
      if (_scanHistory.isNotEmpty) {
        final aiTotal = _scanHistory.map((e) => e.aiDetection).reduce((a, b) => a + b);
        final humanTotal = _scanHistory.map((e) => e.humanWritten).reduce((a, b) => a + b);
        _aiAvg = (aiTotal / _scanHistory.length).round();
        _humanAvg = (humanTotal / _scanHistory.length).round();
      } else {
        _aiAvg = 0;
        _humanAvg = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          _buildHexagonGridOverlay(),
          _buildDataStreamEffect(),
          _buildScanLine(),
          _buildGlitchEffect(),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          SizedBox(height: screenHeight * 0.03),
                          _buildStatsOverview(),
                          SizedBox(height: screenHeight * 0.025),
                          if (_showGraph) buildHistoryGraph(_scanHistory, _glowAnimation.value),
                          _buildListHeader(),
                          SizedBox(height: screenHeight * 0.02),

                          Expanded(
                            child: _scanHistory.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    itemCount: _scanHistory.length,
                                    itemBuilder: (context, index) => _buildHistoryItem(_scanHistory[index], index),
                                  ),
                          ),
                        ],
                      ),
                    );
              },
            ),
          ),
          
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
        animation: _glitchAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _glitchAnimation.value,
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
                Icons.history,
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
                      'ARSIP DATA',
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
            // Keep the existing filter button for interactions
            _buildFilterButton(),
          ],
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return PopupMenuButton<SortOption>(
          tooltip: 'Filter / Sort',
          onSelected: (opt) => _applySort(opt),
          itemBuilder: (context) => [
            PopupMenuItem(value: SortOption.az, child: Text(AppLocalizations.t('sort_az'))),
            PopupMenuItem(value: SortOption.newest, child: Text(AppLocalizations.t('sort_newest'))),
            PopupMenuItem(value: SortOption.oldest, child: Text(AppLocalizations.t('sort_oldest'))),
          ],
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.pink.withOpacity(_glowAnimation.value),
                    width: 2.5,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.pink.withOpacity(0.3),
                      Colors.pink.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(_glowAnimation.value * 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.filter_list,
                  color: Colors.pink.shade300,
                  size: 26,
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _currentSort == SortOption.az ? AppLocalizations.t('sort_badge_az') : 
                    (_currentSort == SortOption.newest ? AppLocalizations.t('sort_badge_new') : 
                    AppLocalizations.t('sort_badge_old')),
                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _applySort(SortOption option) {
    setState(() {
      _currentSort = option;
      if (option == SortOption.az) {
        _scanHistory.sort((a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()));
      } else if (option == SortOption.newest) {
        _scanHistory.sort((a, b) => _parseDate(b.date).compareTo(_parseDate(a.date)));
      } else if (option == SortOption.oldest) {
        _scanHistory.sort((a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)));
      }
    });
  }

  DateTime _parseDate(String s) {
    try {
      final d = DateTime.tryParse(s);
      if (d != null) return d;
      final parts = s.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final y = int.tryParse(dateParts[0]) ?? 1970;
        final m = int.tryParse(dateParts[1]) ?? 1;
        final day = int.tryParse(dateParts[2]) ?? 1;
        final hh = int.tryParse(timeParts[0]) ?? 0;
        final mm = int.tryParse(timeParts[1]) ?? 0;
        return DateTime(y, m, day, hh, mm);
      }
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildStatsOverview() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 18,
                spreadRadius: 3,
              ),
            ],
          ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Total Scans', '${_scanHistory.length}', Icons.analytics, Colors.cyan),
                  _buildStatItem('AI Avg', '${_aiAvg}%', Icons.psychology, Colors.pink),
                  _buildStatItem('Human Avg', '${_humanAvg}%', Icons.person, Colors.purple),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() => _showGraph = !_showGraph),
                child: AnimatedRotation(
                  turns: _showGraph ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyan.withOpacity(_glowAnimation.value), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.cyan.withOpacity(_glowAnimation.value * 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.cyan.shade300, size: 22),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'PEMINDAIAN TERBARU',
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'Orbitron',
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.pink.withOpacity(_glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withOpacity(_glowAnimation.value * 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            '${_scanHistory.length} ENTRI',
            style: TextStyle(
              color: Colors.pink.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Courier',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 220,
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
          color: Colors.cyan.withOpacity(_glowAnimation.value),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.cyan.withOpacity(_glowAnimation.value * 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              color: Colors.cyan.withOpacity(_glowAnimation.value),
              size: 55,
            ),
            const SizedBox(height: 18),
            Text(
              'NO SCAN HISTORY',
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start scanning to see results here',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(Model.ScanHistory history, int index) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.5),
                  Colors.purple.shade900.withOpacity(0.4),
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
                  spreadRadius: 3,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                onTap: () => _showHistoryDetails(history),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      _buildFileIcon(history),
                      
                      const SizedBox(width: 18),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              history.fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              history.date,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildDetectionBar(history),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      _buildStatusIndicator(history),
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

  Widget _buildFileIcon(Model.ScanHistory history) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _rotateController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotateController.value * 2 * math.pi,
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.cyan.withOpacity(_glowAnimation.value),
                    width: 2.5,
                  ),
                ),
              ),
            );
          },
        ),
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.cyan.withOpacity(_glowAnimation.value),
                Colors.pink.withOpacity(_glowAnimation.value),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 28,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _getAiLevelColor(history.aiDetection),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _getAiLevelColor(history.aiDetection),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionBar(Model.ScanHistory history) {
    return Column(
      children: [
        Container(
          height: 7,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.black.withOpacity(0.4),
          ),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.blue.shade900.withOpacity(0.4),
                ),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.4 * (history.aiDetection / 100),
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      _getAiLevelColor(history.aiDetection),
                      _getAiLevelColor(history.aiDetection).withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getAiLevelColor(history.aiDetection),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${history.aiDetection}% AI',
              style: TextStyle(
                color: _getAiLevelColor(history.aiDetection),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
            Text(
              '${history.humanWritten}% Human',
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(Model.ScanHistory history) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.withOpacity(_glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            history.status,
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Orbitron',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          history.fileSize,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildCyberpunkFrame() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Top thin glass-blue navbar line (match editor)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  height: 3,
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
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Bottom subtle border
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
                    color: Colors.black.withOpacity(0.6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4a9fff).withOpacity(_glowAnimation.value * 0.12),
                        blurRadius: 8,
                        spreadRadius: 0,
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

  void _showHistoryDetails(Model.ScanHistory history) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
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
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: ScrollConfiguration(
                behavior: const NoScrollbarBehavior(),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SCAN DETAILS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan.shade300,
                              fontFamily: 'Orbitron',
                              letterSpacing: 2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(_glowAnimation.value),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              history.status,
                              style: TextStyle(
                                color: Colors.green.shade300,
                                fontSize: 11,
                                fontFamily: 'Orbitron',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildDetailItem('Nama Dokumen', history.fileName),
                      _buildDetailItem('Tanggal & Waktu', history.date),
                      _buildDetailItem('Ukuran File', history.fileSize),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.cyan.withOpacity(_glowAnimation.value),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'HASIL',
                              style: TextStyle(
                                color: Colors.pink.shade300,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Orbitron',
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildResultIndicator('AI', '${history.aiDetection}%', _getAiLevelColor(history.aiDetection)),
                                _buildResultIndicator('HUMAN', '${history.humanWritten}%', Colors.cyan),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _buildCyberButton(
                        text: 'TUTUP',
                        icon: Icons.close,
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
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.4),
                color.withOpacity(0.1),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(_glowAnimation.value),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
          ),
        ),
      ],
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
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
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
                blurRadius: 18,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  // Get color based on AI detection percentage
  Color _getAiLevelColor(int aiPercentage) {
    // Define color levels based on percentage
    if (aiPercentage <= 10) {
      return Colors.green.shade400; // Very low AI - green
    } else if (aiPercentage <= 20) {
      return Colors.green.shade300; // Low AI - light green
    } else if (aiPercentage <= 30) {
      return Colors.lime.shade400; // Low-mid AI - lime
    } else if (aiPercentage <= 40) {
      return Colors.yellow.shade400; // Mid-low AI - yellow
    } else if (aiPercentage <= 50) {
      return Colors.amber.shade400; // Mid AI - amber
    } else if (aiPercentage <= 60) {
      return Colors.orange.shade400; // Mid-high AI - orange
    } else if (aiPercentage <= 70) {
      return Colors.deepOrange.shade400; // High AI - deep orange
    } else if (aiPercentage <= 80) {
      return Colors.red.shade400; // Very high AI - red
    } else if (aiPercentage <= 90) {
      return Colors.red.shade600; // Extremely high AI - dark red
    } else {
      return Colors.red.shade800; // Almost all AI - very dark red
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

// Enhanced history graph with individual scan bars and cyberpunk theme
Widget buildHistoryGraph(List<Model.ScanHistory> scanHistory, double glow) {
  if (scanHistory.isEmpty) return const SizedBox.shrink();

  // Limit to the most recent scans for better visualization
  final limitedHistory = scanHistory.length > 20 
      ? scanHistory.sublist(0, 20) 
      : scanHistory;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black.withOpacity(0.8),
          Colors.blue.shade900.withOpacity(0.4),
        ],
      ),
      border: Border.all(
        color: Colors.cyan.withOpacity(glow),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.cyan.withOpacity(glow * 0.4),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, color: Colors.cyan.shade300, size: 18),
            const SizedBox(width: 10),
            Text(
              'RIWAYAT ANALISIS',
              style: TextStyle(
                color: Colors.cyan.shade300,
                fontWeight: FontWeight.bold,
                fontFamily: 'Orbitron',
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              'Total: ${scanHistory.length}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontFamily: 'Orbitron',
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 190,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive bar width based on available space
              final barWidth = math.max(18.0, (constraints.maxWidth - 20) / limitedHistory.length - 5);
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: limitedHistory.asMap().entries.map((entry) {
                    final history = entry.value;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: _IndividualScanBar(
                        height: 160, // Fixed height for all bars
                        width: barWidth,
                        label: _formatDateTimeLabel(history.date),
                        aiDetection: history.aiDetection,
                        humanDetection: history.humanWritten,
                        glow: glow,
                        fileName: history.fileName,
                        date: history.date,
                        status: history.status,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('AI Content', Colors.pink.shade400),
            const SizedBox(width: 25),
            _buildLegendItem('Human Content', Colors.cyan.shade400),
          ],
        ),
      ],
    ),
  );
}

// Format date and time for chart labels
String _formatDateTimeLabel(String dateStr) {
  try {
    final date = DateTime.parse(dateStr);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final mon = months[(date.month - 1).clamp(0, 11)];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $mon · $hour:$minute';
  } catch (_) {
    // Fallback for different date formats
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final day = dateParts[2].padLeft(2, '0');
        final monthIdx = int.tryParse(dateParts[1]) ?? 1;
        const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final mon = months[(monthIdx - 1).clamp(0, 11)];
        final hour = timeParts[0].padLeft(2, '0');
        final minute = timeParts[1].padLeft(2, '0');
        return '$day $mon · $hour:$minute';
      }
    } catch (_) {}
    return dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr;
  }
}

Widget _buildLegendItem(String label, Color color) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontFamily: 'Orbitron',
        ),
      ),
    ],
  );
}

class _IndividualScanBar extends StatefulWidget {
  final double height;
  final double width;
  final String label;
  final int aiDetection;
  final int humanDetection;
  final double glow;
  final String fileName;
  final String date;
  final String status;

  const _IndividualScanBar({
    required this.height,
    required this.width,
    required this.label,
    required this.aiDetection,
    required this.humanDetection,
    required this.glow,
    required this.fileName,
    required this.date,
    required this.status,
  });

  @override
  State<_IndividualScanBar> createState() => _IndividualScanBarState();
}

class _IndividualScanBarState extends State<_IndividualScanBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _isHovered = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: widget.height).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _showTooltip();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _removeOverlay();
      },
      child: GestureDetector(
        onTap: () {
          if (_overlayEntry == null) {
            _showTooltip();
          } else {
            _removeOverlay();
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Enhanced cyberpunk bar with glow effect
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                final totalHeight = _anim.value;
                final aiFrac = widget.aiDetection.toDouble().clamp(0.0, 100.0) / 100.0;
                final aiHeight = totalHeight * aiFrac;
                final humanHeight = (totalHeight - aiHeight).clamp(0.0, totalHeight);

                return Container(
                  width: widget.width,
                  height: totalHeight,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: _isHovered 
                          ? Colors.cyan.withOpacity(widget.glow * 0.8)
                          : Colors.black.withOpacity(0.4),
                        blurRadius: _isHovered ? 18 : 6,
                        spreadRadius: _isHovered ? 3 : 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Human content bar (cyan)
                        Container(
                          height: humanHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.cyan.shade700,
                                Colors.cyan.shade400,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withOpacity(widget.glow * 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        // AI content bar (pink with gradient based on percentage)
                        Container(
                          height: aiHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                _getAiLevelColor(widget.aiDetection),
                                _getAiLevelColor(widget.aiDetection).withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _getAiLevelColor(widget.aiDetection).withOpacity(0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Responsive label with font size adjustment for mobile
            Container(
              constraints: BoxConstraints(maxWidth: widget.width),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontFamily: 'Orbitron',
                    fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTooltip() {
    // remove any existing global tooltip and show this one
    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final tooltipWidth = math.min(220.0, MediaQuery.of(context).size.width * 0.8);
    final tooltipHeight = 110.0; // Increased height for better content display

    final screenSize = MediaQuery.of(context).size;
    double top = offset.dy - tooltipHeight - 10;
    if (top < MediaQuery.of(context).padding.top + 10) {
      top = offset.dy + size.height + 10;
    }

    double left = offset.dx + (size.width / 2) - (tooltipWidth / 2);
    left = left.clamp(10.0, screenSize.width - tooltipWidth - 10.0);

    _overlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
        top: top,
        left: left,
        width: tooltipWidth,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _removeOverlay,
            behavior: HitTestBehavior.translucent,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.blue.shade900.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.cyan.withOpacity(widget.glow),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(widget.glow * 0.6),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File name with truncation
                  Text(
                    widget.fileName.length > 25 
                        ? '${widget.fileName.substring(0, 25)}...' 
                        : widget.fileName,
                    style: TextStyle(
                      color: Colors.cyan.shade300,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Orbitron',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  // AI and Human percentages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _getAiLevelColor(widget.aiDetection),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI: ${widget.aiDetection}%',
                            style: TextStyle(
                              color: _getAiLevelColor(widget.aiDetection),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.cyan.shade400,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Human: ${widget.humanDetection}%',
                            style: TextStyle(
                              color: Colors.cyan.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.date,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });

    _showGlobalTooltip(_overlayEntry!, overlay);
  }

  void _removeOverlay() {
    _hideGlobalTooltip();
    _overlayEntry = null;
  }
}

// Get color based on AI detection percentage
Color _getAiLevelColor(int aiPercentage) {
  // Define color levels based on percentage
  if (aiPercentage <= 10) {
    return Colors.green.shade400; // Very low AI - green
  } else if (aiPercentage <= 20) {
    return Colors.green.shade300; // Low AI - light green
  } else if (aiPercentage <= 30) {
    return Colors.lime.shade400; // Low-mid AI - lime
  } else if (aiPercentage <= 40) {
    return Colors.yellow.shade400; // Mid-low AI - yellow
  } else if (aiPercentage <= 50) {
    return Colors.amber.shade400; // Mid AI - amber
  } else if (aiPercentage <= 60) {
    return Colors.orange.shade400; // Mid-high AI - orange
  } else if (aiPercentage <= 70) {
    return Colors.deepOrange.shade400; // High AI - deep orange
  } else if (aiPercentage <= 80) {
    return Colors.red.shade400; // Very high AI - red
  } else if (aiPercentage <= 90) {
    return Colors.red.shade600; // Extremely high AI - dark red
  } else {
    return Colors.red.shade800; // Almost all AI - very dark red
  }
}

enum SortOption { az, newest, oldest }