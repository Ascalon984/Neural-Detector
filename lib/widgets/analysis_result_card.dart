import 'package:flutter/material.dart';

class AnalysisResultCard extends StatefulWidget {
  final double aiPercentage;
  final double humanPercentage;
  final String title;
  final String scanId;
  final DateTime scanDate;
  final VoidCallback? onViewDetails;
  final VoidCallback? onExport;
  final VoidCallback? onShare;

  const AnalysisResultCard({
    Key? key,
    required this.aiPercentage,
    required this.humanPercentage,
    required this.title,
    this.scanId = 'SCAN_001',
    required this.scanDate,
    this.onViewDetails,
    this.onExport,
    this.onShare,
  }) : super(key: key);

  @override
  State<AnalysisResultCard> createState() => _AnalysisResultCardState();
}

class _AnalysisResultCardState extends State<AnalysisResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuart),
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _progressAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value * (1 - _progressAnimation.value)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade900.withOpacity(0.3),
                      Colors.purple.shade900.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.cyan.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withOpacity(0.2 * _glowAnimation.value),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.1 * _glowAnimation.value),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background Pattern
                    _buildBackgroundPattern(),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          _buildHeaderSection(),
                          
                          const SizedBox(height: 24),
                          
                          // Scan Info
                          _buildScanInfo(),
                          
                          const SizedBox(height: 32),
                          
                          // Progress Bars
                          _buildProgressSection(),
                          
                          const SizedBox(height: 32),
                          
                          // Confidence Indicator
                          _buildConfidenceIndicator(),
                          
                          const SizedBox(height: 24),
                          
                          // Action Buttons
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                    
                    // Corner Accents
                    ..._buildCornerAccents(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundPattern() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(
          painter: _CardPatternPainter(animation: _controller),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      children: [
        // Animated Icon
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.cyan.withOpacity(_glowAnimation.value),
                    Colors.pink.withOpacity(_glowAnimation.value),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.3 * _glowAnimation.value),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 32,
                  ),
                  if (_progressAnimation.value < 1.0)
                    CircularProgressIndicator(
                      value: _progressAnimation.value,
                      strokeWidth: 3,
                      color: Colors.white.withOpacity(0.5),
                    ),
                ],
              ),
            );
          },
        ),
        
        const SizedBox(width: 16),
        
        // Title and Status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.cyan.shade300,
                  letterSpacing: 2,
                  fontFamily: 'Courier',
                  shadows: [
                    Shadow(
                      color: Colors.cyan.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                'QUANTUM ANALYSIS COMPLETE',
                style: TextStyle(
                  color: Colors.pink.shade300,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3,
                  fontFamily: 'Courier',
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              const Text(
                'Neural network processing finished',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green),
          ),
          child: Text(
            'VERIFIED',
            style: TextStyle(
              color: Colors.green.shade300,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'Courier',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SCAN ID',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              Text(
                widget.scanId,
                style: TextStyle(
                  color: Colors.cyan.shade300,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'DATE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                ),
              ),
              Text(
                _formatDate(widget.scanDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Courier',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        // AI Detection Progress
        _buildCyberProgressBar(
          label: 'AI DETECTION',
          percentage: widget.aiPercentage,
          progress: widget.aiPercentage / 100 * _progressAnimation.value,
          color: Colors.pink,
          icon: Icons.smart_toy,
        ),
        
        const SizedBox(height: 20),
        
        // Human Detection Progress
        _buildCyberProgressBar(
          label: 'HUMAN WRITTEN',
          percentage: widget.humanPercentage,
          progress: widget.humanPercentage / 100 * _progressAnimation.value,
          color: Colors.cyan,
          icon: Icons.person,
        ),
      ],
    );
  }

  Widget _buildCyberProgressBar({
    required String label,
    required double percentage,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Icon(
                      icon,
                      color: color.withOpacity(_glowAnimation.value),
                      size: 18,
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Text(
                  '${(percentage * _progressAnimation.value).toInt()}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Courier',
                    shadows: [
                      Shadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Progress Bar Container
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Stack(
            children: [
              // Background
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              
              // Progress Fill & Glow (use LayoutBuilder so widths are relative to the card)
              LayoutBuilder(builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final fillWidth = (trackWidth) * progress;
                return Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Container(
                          width: fillWidth.clamp(0.0, trackWidth),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.8),
                                color.withOpacity(0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.3 * _glowAnimation.value),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Container(
                          width: fillWidth.clamp(0.0, trackWidth),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              colors: [
                                color.withOpacity(0.4 * _glowAnimation.value),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Progress Label
        Text(
          _getAnalysisLabel(percentage),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceIndicator() {
    final confidence = _calculateConfidence();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified,
            color: Colors.cyan.shade300,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIDENCE LEVEL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  '$confidence% - ${_getConfidenceLabel(confidence)}',
                  style: TextStyle(
                    color: Colors.cyan.shade300,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          CircularProgressIndicator(
            value: confidence / 100,
            backgroundColor: Colors.white.withOpacity(0.2),
            color: Colors.cyan,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildCyberButton(
            text: 'DETAILS',
            icon: Icons.visibility,
            onPressed: widget.onViewDetails,
            color: Colors.cyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCyberButton(
            text: 'EXPORT',
            icon: Icons.download,
            onPressed: widget.onExport,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCyberButton(
            text: 'SHARE',
            icon: Icons.share,
            onPressed: widget.onShare,
            color: Colors.pink,
          ),
        ),
      ],
    );
  }

  Widget _buildCyberButton({
    required String text,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(_glowAnimation.value),
              width: 1.5,
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
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      text,
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
          ),
        );
      },
    );
  }

  List<Widget> _buildCornerAccents() {
    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink, width: 3),
              top: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink, width: 3),
              top: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.pink, width: 3),
              bottom: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.pink, width: 3),
              bottom: BorderSide(color: Colors.pink, width: 3),
            ),
          ),
        ),
      ),
    ];
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getAnalysisLabel(double percentage) {
    if (percentage < 20) return 'LOW PROBABILITY';
    if (percentage < 50) return 'MODERATE CONFIDENCE';
    if (percentage < 80) return 'HIGH CONFIDENCE';
    return 'VERY HIGH CONFIDENCE';
  }

  double _calculateConfidence() {
    final diff = (widget.aiPercentage - widget.humanPercentage).abs();
    return 100 - (diff / 100 * 50);
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence < 60) return 'LOW';
    if (confidence < 80) return 'MEDIUM';
    if (confidence < 90) return 'HIGH';
    return 'VERY HIGH';
  }
}

class _CardPatternPainter extends CustomPainter {
  final Animation<double> animation;

  _CardPatternPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Draw grid pattern
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw animated scan line
    final scanPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3 * animation.value)
      ..strokeWidth = 2;

    final scanY = size.height * animation.value;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}