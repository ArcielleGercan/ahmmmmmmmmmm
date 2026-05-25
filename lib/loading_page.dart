import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Full-page loading screen — responsive:
///   • Mobile  (<600 px wide): vertical wave-trail layout, smaller flowers
///   • Desktop (≥600 px wide): original horizontal bounce layout
class LoadingPage extends StatefulWidget {
  final String? message;

  const LoadingPage({
    super.key,
    this.message,
  });

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _waveController;   // mobile-only wave
  late List<AnimationController> _pinwheelControllers;

  // ── Desktop pinwheel positions (unchanged) ────────────────────────────────
  final List<Map<String, dynamic>> _desktopPinwheelPositions = [
    {'top': 0.08, 'left': 0.05,  'speed': 15.0, 'reverse': false},
    {'top': 0.08, 'left': 0.5,   'speed': 20.0, 'reverse': true,  'centered': true},
    {'top': 0.08, 'right': 0.05, 'speed': 15.0, 'reverse': false},
    {'top': 0.22, 'left': 0.20,  'speed': 18.0, 'reverse': true},
    {'top': 0.22, 'right': 0.20, 'speed': 17.0, 'reverse': false},
    {'top': 0.5,  'left': 0.05,  'speed': 20.0, 'reverse': false, 'centerY': true},
    {'top': 0.5,  'right': 0.05, 'speed': 19.0, 'reverse': true,  'centerY': true},
    {'top': 0.64, 'left': 0.20,  'speed': 16.0, 'reverse': false},
    {'top': 0.64, 'right': 0.20, 'speed': 18.0, 'reverse': true},
    {'bottom': 0.08, 'left': 0.05,  'speed': 17.0, 'reverse': true},
    {'bottom': 0.08, 'left': 0.5,   'speed': 15.0, 'reverse': false, 'centered': true},
    {'bottom': 0.08, 'right': 0.05, 'speed': 20.0, 'reverse': true},
  ];

  // ── Mobile pinwheel positions — symmetric grid around the centre content ──
  //
  //   x     x     x   ← top row
  //       x     x     ← upper-middle row
  //      [birds]
  //     [loading]
  //       x     x     ← lower-middle row
  //   x     x     x   ← bottom row
  final List<Map<String, dynamic>> _mobilePinwheelPositions = [
    // ── Top row: x  x  x ──────────────────────────────────────────────────
    {'top': 0.04, 'left':  0.05, 'speed': 12.0, 'reverse': false},
    {'top': 0.04, 'left':  0.5,  'speed': 20.0, 'reverse': true,  'centered': true},
    {'top': 0.04, 'right': 0.05, 'speed': 14.0, 'reverse': true},
    // ── Upper-middle row:  x  x ───────────────────────────────────────────
    {'top': 0.19, 'left':  0.18, 'speed': 16.0, 'reverse': true},
    {'top': 0.19, 'right': 0.18, 'speed': 15.0, 'reverse': false},
    // ── Lower-middle row:  x  x ───────────────────────────────────────────
    {'top': 0.68, 'left':  0.18, 'speed': 13.0, 'reverse': false},
    {'top': 0.68, 'right': 0.18, 'speed': 17.0, 'reverse': true},
    // ── Bottom row: x  x  x ───────────────────────────────────────────────
    {'bottom': 0.04, 'left':  0.05, 'speed': 11.0, 'reverse': true},
    {'bottom': 0.04, 'left':  0.5,  'speed': 18.0, 'reverse': false, 'centered': true},
    {'bottom': 0.04, 'right': 0.05, 'speed': 13.0, 'reverse': false},
  ];

  bool get _isMobile => _cachedWidth != null && _cachedWidth! < 600;
  double? _cachedWidth;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Initialise controllers for the larger desktop set
    // (we'll re-use subset count for mobile)
    final positions = _desktopPinwheelPositions.length >
            _mobilePinwheelPositions.length
        ? _desktopPinwheelPositions
        : _mobilePinwheelPositions;

    _pinwheelControllers = positions.map((pos) {
      return AnimationController(
        vsync: this,
        duration: Duration(seconds: (pos['speed'] as double).toInt()),
      )..repeat(reverse: pos['reverse'] as bool);
    }).toList();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _waveController.dispose();
    for (var c in _pinwheelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _cachedWidth = size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: GeometricPatternPainter()),
          ),
          // Pinwheels
          ..._buildPinwheels(size),
          // Content
          _isMobile ? _buildMobileContent(size) : _buildDesktopContent(),
        ],
      ),
    );
  }

  // ── Desktop layout (original) ─────────────────────────────────────────────
  Widget _buildDesktopContent() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _animatedBird(-120, 0.0),
                _animatedBird(0, 0.15),
                _animatedBird(120, 0.3),
              ],
            ),
          ),
          const SizedBox(height: 60),
          _loadingText(24),
        ],
      ),
    );
  }

  // ── Mobile layout — diagonal wave trail ──────────────────────────────────
  Widget _buildMobileContent(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Birds in a diagonal wave arc
          SizedBox(
            width: size.width * 0.72,
            height: 200,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bird 1 — top-left
                    _mobileBird(
                      dx: -size.width * 0.22,
                      dy: _mobileWave(_waveController.value, 0.0),
                      progress: _bounceController.value,
                      delay: 0.0,
                      scale: 0.78,
                    ),
                    // Bird 2 — centre (slightly larger)
                    _mobileBird(
                      dx: 0,
                      dy: _mobileWave(_waveController.value, 0.2),
                      progress: _bounceController.value,
                      delay: 0.15,
                      scale: 0.92,
                    ),
                    // Bird 3 — bottom-right
                    _mobileBird(
                      dx: size.width * 0.22,
                      dy: _mobileWave(_waveController.value, 0.4),
                      progress: _bounceController.value,
                      delay: 0.3,
                      scale: 0.78,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _loadingText(18),
        ],
      ),
    );
  }

  /// Smooth sinusoidal vertical wave offset for mobile birds
  double _mobileWave(double progress, double delay) {
    final p = (progress + delay) % 1.0;
    return -38 * math.sin(p * math.pi * 2);
  }

  /// A single mobile bird with scale + translate
  Widget _mobileBird({
    required double dx,
    required double dy,
    required double progress,
    required double delay,
    required double scale,
  }) {
    final isUp = _isBirdUp(progress, delay);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          isUp ? 'assets/images-icons/2.png' : 'assets/images-icons/1.png',
          width: 110,
          height: 110,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.flutter_dash, size: 70, color: Color(0xFFE91E63)),
        ),
      ),
    );
  }

  /// Three pulsing dots below the birds on mobile
  Widget _dotLoader() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_waveController.value + i * 0.2) % 1.0);
            final scale = 0.5 + 0.5 * math.sin(phase * math.pi * 2).abs();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
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
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _loadingText(double fontSize) {
    return Text(
      widget.message ?? 'Loading...',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        decoration: TextDecoration.none,
        shadows: const [
          Shadow(
            color: Color.fromRGBO(0, 0, 0, 0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _animatedBird(double offsetX, double delay) {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        final progress = _bounceController.value;
        final bounceValue = _calculateBounce(progress, delay);
        return Transform.translate(
          offset: Offset(offsetX, bounceValue),
          child: _buildBird(progress, delay),
        );
      },
    );
  }

  List<Widget> _buildPinwheels(Size screenSize) {
    final isMobile = screenSize.width < 600;
    final positions =
        isMobile ? _mobilePinwheelPositions : _desktopPinwheelPositions;
    // Mobile uses smaller pinwheels
    final double pinwheelSize = isMobile ? 62 : 120;

    return List.generate(positions.length, (index) {
      if (index >= _pinwheelControllers.length) return const SizedBox.shrink();
      final pos = positions[index];
      final controller = _pinwheelControllers[index];

      double? top =
          pos['top'] != null ? screenSize.height * (pos['top'] as double) : null;
      double? bottom = pos['bottom'] != null
          ? screenSize.height * (pos['bottom'] as double)
          : null;
      double? left =
          pos['left'] != null ? screenSize.width * (pos['left'] as double) : null;
      double? right = pos['right'] != null
          ? screenSize.width * (pos['right'] as double)
          : null;

      final half = pinwheelSize / 2;
      if (pos['centered'] == true) {
        left = screenSize.width * (pos['left'] as double) - half;
      }
      if (pos['centerY'] == true) {
        top = screenSize.height * (pos['top'] as double) - half;
      }

      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: controller.value *
                  2 *
                  math.pi *
                  ((pos['reverse'] as bool) ? -1 : 1),
              child: child,
            );
          },
          child: Pinwheel(size: pinwheelSize),
        ),
      );
    });
  }

  double _calculateBounce(double progress, double delay) {
    final adjustedProgress = (progress + delay) % 1.0;
    return -60 * math.sin(adjustedProgress * math.pi * 2).abs();
  }

  bool _isBirdUp(double progress, double delay) {
    final adjustedProgress = (progress + delay) % 1.0;
    final bounceValue = math.sin(adjustedProgress * math.pi * 2).abs();
    return bounceValue > 0.5;
  }

  Widget _buildBird(double progress, double delay) {
    final isUp = _isBirdUp(progress, delay);
    return Image.asset(
      isUp ? 'assets/images-icons/2.png' : 'assets/images-icons/1.png',
      width: 120,
      height: 120,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.flutter_dash, size: 80, color: Color(0xFFE91E63));
      },
    );
  }
}

/// Custom painter for geometric diamond pattern
class GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lighterBluePaint = Paint()
      ..color = const Color(0xFF9AD9EA).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final slightlyDarkerBluePaint = Paint()
      ..color = const Color(0xFF7AC5DC).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    const spacing = 70.0;

    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      for (double x = -spacing; x < size.width + spacing; x += spacing) {
        final path = Path();
        path.moveTo(x, y - spacing / 2);
        path.lineTo(x + spacing / 2, y);
        path.lineTo(x, y + spacing / 2);
        path.lineTo(x - spacing / 2, y);
        path.close();

        final isLighter =
            ((x / spacing).floor() + (y / spacing).floor()) % 2 == 0;
        canvas.drawPath(
            path, isLighter ? lighterBluePaint : slightlyDarkerBluePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pinwheel widget with 5 petals
class Pinwheel extends StatelessWidget {
  final double size;

  const Pinwheel({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: PinwheelPainter(size: size)),
    );
  }
}

/// Custom painter for pinwheel — scales petals with size
class PinwheelPainter extends CustomPainter {
  final double size;
  const PinwheelPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final scale = size / 120.0; // normalise to original 120px size

    final petalPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 72) * math.pi / 180;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      final path = Path();
      path.moveTo(0, 0);
      path.cubicTo(-10 * scale, -10 * scale, -15 * scale, -25 * scale,
          -12 * scale, -38 * scale);
      path.cubicTo(
          -8 * scale, -42 * scale, 8 * scale, -42 * scale, 12 * scale, -38 * scale);
      path.cubicTo(
          15 * scale, -25 * scale, 10 * scale, -10 * scale, 0, 0);
      path.close();

      canvas.drawPath(path, petalPaint);
      canvas.restore();
    }

    canvas.drawCircle(center, 18 * scale, circlePaint);

    final innerCirclePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12 * scale, innerCirclePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rectangular popup with grid pattern background and 3 bouncing birds
class LoadingWidget extends StatefulWidget {
  final String? message;
  final double width;
  final double height;

  const LoadingWidget({
    super.key,
    this.message,
    this.width = 400,
    this.height = 280,
  });

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final birdSize = widget.height * 0.28;
    final spacing = widget.width * 0.18;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF87CEEB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: GeometricPatternPainter()),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: widget.height * 0.4,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            final progress = _bounceController.value;
                            final bounceValue = _calculateBounce(
                                progress, 0.0, widget.height * 0.1);
                            return Transform.translate(
                              offset: Offset(-spacing, bounceValue),
                              child: _buildSmallBird(birdSize, progress, 0.0),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            final progress = _bounceController.value;
                            final bounceValue = _calculateBounce(
                                progress, 0.15, widget.height * 0.1);
                            return Transform.translate(
                              offset: Offset(0, bounceValue),
                              child:
                                  _buildSmallBird(birdSize, progress, 0.15),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _bounceController,
                          builder: (context, child) {
                            final progress = _bounceController.value;
                            final bounceValue = _calculateBounce(
                                progress, 0.3, widget.height * 0.1);
                            return Transform.translate(
                              offset: Offset(spacing, bounceValue),
                              child: _buildSmallBird(birdSize, progress, 0.3),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: widget.height * 0.06),
                  if (widget.message != null)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: widget.width * 0.08),
                      child: Text(
                        widget.message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: widget.height * 0.08,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(0, 0, 0, 0.2),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateBounce(double progress, double delay, double amplitude) {
    final adjustedProgress = (progress + delay) % 1.0;
    return -amplitude * math.sin(adjustedProgress * math.pi * 2).abs();
  }

  bool _isSmallBirdUp(double progress, double delay) {
    final adjustedProgress = (progress + delay) % 1.0;
    final bounceValue = math.sin(adjustedProgress * math.pi * 2).abs();
    return bounceValue > 0.5;
  }

  Widget _buildSmallBird(double size, double progress, double delay) {
    final isUp = _isSmallBirdUp(progress, delay);
    return Image.asset(
      isUp ? 'assets/images-icons/2.png' : 'assets/images-icons/1.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.flutter_dash,
            size: size * 0.6, color: const Color(0xFFE91E63));
      },
    );
  }
}

/// Helper class for showing loading screens
class LoadingHelper {
  static void showLoadingPage(BuildContext context, {String? message}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            LoadingPage(message: message),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static void showLoadingDialog(
    BuildContext context, {
    String? message,
    double width = 400,
    double height = 280,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Center(
        child: LoadingWidget(
          message: message,
          width: width,
          height: height,
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }
}