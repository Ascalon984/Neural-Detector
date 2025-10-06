import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/animation_config.dart';
import '../theme/theme_provider.dart';
import '../theme/app_theme.dart';
import '../utils/history_manager.dart';
import '../models/scan_history.dart' as Model;
import '../utils/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _scanAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;

  List<Model.ScanHistory> _scanHistory = [];
  int _aiAvg = 0;
  int _humanAvg = 0;
  SortOption _currentSort = SortOption.newest;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    
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

      _fadeAnimation = Tween<double>(
        begin: 0.6,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      ));
    } else {
      _scanAnimation = AlwaysStoppedAnimation(0.0);
      _glowAnimation = AlwaysStoppedAnimation(0.4);
      _fadeAnimation = AlwaysStoppedAnimation(0.6);
    }
  }

  Future<void> _loadHistory() async {
    final list = await HistoryManager.loadHistory();
    setState(() {
      _scanHistory = list;
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
                  
                  // Stats overview
                  _buildStatsOverview(),
                  
                  const SizedBox(height: 25),
                  
                  // History list header
                  _buildListHeader(),
                  
                  const SizedBox(height: 15),
                  
                  // History list
                  Expanded(
                    child: _buildHistoryList(),
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
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            Colors.black,
            Colors.purple.shade900.withOpacity(0.5),
            Colors.blue.shade900.withOpacity(0.3),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _CyberpunkBackgroundPainter(),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _controller ?? AlwaysStoppedAnimation(0.0),
                  builder: (context, child) {
                    return Container(
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
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.history,
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
                          fontFamily: AppTheme.defaultFontFamily,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SCAN HISTORY DATABASE',
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
            _buildFilterButton(),
          ],
        ),
        
        const SizedBox(height: 10),
        
        Text(
          AppLocalizations.t('history_description'),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.pink.withOpacity(_glowAnimation.value),
                    width: 2,
                  ),
                  color: Colors.black.withOpacity(0.5),
                ),
                child: Icon(
                  Icons.filter_list,
                  color: Colors.pink.shade300,
                  size: 24,
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
                    _currentSort == SortOption.az ? AppLocalizations.t('sort_badge_az') : (_currentSort == SortOption.newest ? AppLocalizations.t('sort_badge_new') : AppLocalizations.t('sort_badge_old')),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
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
      // fallback parsing for 'YYYY-MM-DD HH:mm'
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade900.withOpacity(0.5),
            Colors.purple.shade900.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Scans', '${_scanHistory.length}', Icons.analytics),
          _buildStatItem('AI Avg', '${_aiAvg}%', Icons.psychology),
          _buildStatItem('Human Avg', '${_humanAvg}%', Icons.person),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.cyan.withOpacity(0.5),
                Colors.pink.withOpacity(0.5),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.cyan.shade300,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'RECENT SCANS',
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontFamily: 'Courier',
          ),
        ),
        Text(
          '${_scanHistory.length} ITEMS',
          style: TextStyle(
            color: Colors.pink.shade300,
            fontSize: 12,
            fontWeight: FontWeight.w300,
            fontFamily: 'Courier',
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Stack(
          children: [
            // Scan line effect
            Positioned(
              top: _scanAnimation.value * MediaQuery.of(context).size.height,
              child: Container(
                width: MediaQuery.of(context).size.width - 40,
                height: 2,
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
            
            // History list
            ListView.builder(
              itemCount: _scanHistory.length,
                itemBuilder: (context, index) {
                  return _buildHistoryItem(_scanHistory[index], index);
                },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(Model.ScanHistory history, int index) {
    return AnimatedBuilder(
      animation: _controller ?? AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.blue.shade900.withOpacity(0.72),
                  Colors.purple.shade900.withOpacity(0.55),
                ],
              ),
              // stronger, crisper border
              border: Border.all(
                color: Colors.cyan.withOpacity(0.9),
                width: 2,
              ),
              // tighter shadows for HD appearance
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.12),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.32),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: () => _showHistoryDetails(history),
                borderRadius: BorderRadius.circular(15),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      // File icon dengan status
                      _buildFileIcon(history),
                      
                      const SizedBox(width: 15),
                      
                      // File info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              history.fileName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              history.date,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetectionBar(history),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 15),
                      
                      // Status indicator
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
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.cyan.withOpacity(0.9),
                Colors.pink.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.cyan.withOpacity(0.28),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 30,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: history.aiDetection < 20 ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionBar(Model.ScanHistory history) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: history.aiDetection / 100,
                backgroundColor: Colors.blue.shade900.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  history.aiDetection < 20 ? Colors.green : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${history.aiDetection}% AI',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${history.humanWritten}% Human',
          style: TextStyle(
            color: Colors.cyan.shade300,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(Model.ScanHistory history) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green),
          ),
          child: Text(
            history.status,
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          history.fileSize,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
        ),
      ],
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

  void _showHistoryDetails(Model.ScanHistory history) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan.shade300,
                            fontFamily: 'Courier',
                            letterSpacing: 2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            history.id,
                            style: TextStyle(
                              color: Colors.green.shade300,
                              fontSize: 12,
                              fontFamily: 'Courier',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDetailItem('File Name', history.fileName),
                    _buildDetailItem('Date & Time', history.date),
                    _buildDetailItem('File Size', history.fileSize),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'ANALYSIS RESULTS',
                            style: TextStyle(
                              color: Colors.pink.shade300,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Courier',
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildResultIndicator('AI', '${history.aiDetection}%', Colors.orange),
                              _buildResultIndicator('HUMAN', '${history.humanWritten}%', Colors.cyan),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ScanHistory model now lives in lib/models/scan_history.dart

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

    // Static lines (tanpa animasi)
    final linePaint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 1;

    for (int i = 0; i < size.width; i += 30) {
      canvas.drawLine(
        Offset(i.toDouble(), 0), 
        Offset(i.toDouble(), size.height), 
        linePaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

enum SortOption { az, newest, oldest }