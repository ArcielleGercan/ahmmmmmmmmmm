import 'audio_service.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final String userId;
  final VoidCallback onComplete;
  final Map<String, GlobalKey> elementKeys;

  /// Called whenever a step becomes active (forward AND backward navigation).
  /// Use this to trigger side-effects like opening a drawer so that the
  /// highlighted element for that step becomes visible on screen.
  ///
  /// Example — open the nav drawer when the Leaderboard step is reached:
  /// ```dart
  /// onStepActivate: (step) {
  ///   if (step.highlightKey == 'leaderboard') {
  ///     scaffoldKey.currentState?.openDrawer();
  ///   }
  /// },
  /// ```
  final void Function(TutorialStep step)? onStepActivate;

  const TutorialOverlay({
    super.key,
    required this.userId,
    required this.onComplete,
    required this.elementKeys,
    this.onStepActivate,
  });

  /// Check if the main tutorial should be shown for this user
  // ignore: unused_element
  static Future<bool> shouldShowTutorial(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'main_tutorial_completed_$userId';
      final hasCompleted = prefs.getBool(key) ?? false;
      return !hasCompleted; // Show if they haven't completed it
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      return false; // Don't show on error
    }
  }

  /// Reset tutorial for testing purposes
  // ignore: unused_element
  static Future<void> resetTutorial(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('main_tutorial_completed_$userId');
      debugPrint('Tutorial reset for user: $userId');
    } catch (e) {
      debugPrint('Error resetting tutorial: $e');
    }
  }

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "Welcome to Starbooks Whiz!",
      description:
      "We're excited to have you here! Let's take a quick tour to help you get started on your learning adventure.",
      highlightKey: null,
      position: TutorialPosition.center,
      icon: Icons.waving_hand,
      iconColor: const Color(0xFFFDD000),
      expandHighlight: 0,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Collect Stars!",
      description:
      "Complete games quickly and accurately. Your total stars are shown at the top. Collect more stars to unlock special milestones!",
      highlightKey: "star_count",
      position: TutorialPosition.bottomCenter,
      icon: Icons.star,
      iconColor: const Color(0xFFFDD000),
      expandHighlight: 20,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Your Badges",
      description:
      "Complete challenges to earn badges. Click here to view your collection. See what you can unlock next!",
      highlightKey: "badges_button",
      position: TutorialPosition.bottomCenter,
      icon: Icons.emoji_events,
      iconColor: const Color(0xFFFDD000),
      expandHighlight: 0,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Whiz Memory Match",
      description:
      "Match pairs of cards as quickly as you can. The faster you complete it, the more stars you earn. Great for improving memory and focus!",
      highlightKey: "memory_match",
      position: TutorialPosition.topRight,
      mobilePosition: TutorialPosition.bottomCenter,
      icon: Icons.extension,
      iconColor: const Color(0xFF656BE6),
      expandHighlight: 10,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Whiz Challenge",
      description:
      "Answer quiz questions to test your knowledge. Get perfect scores to earn special badges. Choose from Science or Math categories.",
      highlightKey: "whiz_challenge",
      position: TutorialPosition.topRight,
      mobilePosition: TutorialPosition.bottomCenter,
      icon: Icons.quiz,
      iconColor: const Color(0xFFFDD000),
      expandHighlight: 10,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Whiz Battle",
      description:
      "Challenge other players in real-time quiz battles. Create or join rooms to compete. Win battles to earn badges and climb the leaderboard!",
      highlightKey: "whiz_battle",
      position: TutorialPosition.topLeft,
      mobilePosition: TutorialPosition.topCenter,
      icon: Icons.sports_esports,
      iconColor: const Color(0xFFC571E2),
      expandHighlight: 10,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Whiz Puzzle",
      description:
      "Solve jigsaw puzzles by dragging pieces. Choose from different categories and levels. The faster you solve, the more stars you earn!",
      highlightKey: "whiz_puzzle",
      position: TutorialPosition.topLeft,
      mobilePosition: TutorialPosition.topCenter,
      icon: Icons.view_module,
      iconColor: const Color(0xFFE6833A),
      expandHighlight: 10,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Leaderboard",
      description:
      "See how you rank against other players. Compete in Whiz Challenge and Whiz Battle. Can you reach the top?",
      highlightKey: "leaderboard",
      position: TutorialPosition.center,
      mobilePosition: TutorialPosition.topCenter,
      icon: Icons.leaderboard,
      iconColor: const Color(0xFF046EB8),
      expandHighlight: 20,
      overlayOpacity: 0.7,
    ),
    TutorialStep(
      title: "Ready to Play!",
      description:
      "You're all set! Pick any game to start your learning journey. Have fun and remember: the more you play, the more you learn!",
      highlightKey: null,
      position: TutorialPosition.center,
      icon: Icons.rocket_launch,
      iconColor: const Color(0xFFFDD000),
      expandHighlight: 0,
      overlayOpacity: 0.7,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _startTextAnimation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startTextAnimation() {
    _fadeController.reset();
    _fadeController.forward();
    // Notify parent so it can reveal off-screen elements (e.g. open a drawer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onStepActivate?.call(_steps[_currentStep]);
    });
  }

  Future<void> _markTutorialComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('main_tutorial_completed_${widget.userId}', true);
      debugPrint('Tutorial marked as completed for user: ${widget.userId}');
    } catch (e) {
      debugPrint('Error marking tutorial complete: $e');
    }
  }

  void _nextStep() async {
    try {
      await AudioService().playClickSound();
    } catch (e) {
      debugPrint('Click sound not found: $e');
    }

    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
      _startTextAnimation();
    } else {
      await _markTutorialComplete();
      widget.onComplete();
    }
  }

  void _previousStep() async {
    try {
      await AudioService().playClickSound();
    } catch (e) {
      debugPrint('Click sound not found: $e');
    }

    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _startTextAnimation();
    }
  }

  void _skipTutorial() async {
    // Show confirmation dialog
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: const Color(0xFFFDD000), // Yellow outer border
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.4),
                  blurRadius: 25,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CustomPaint(
                painter: DashedBorderPainter(),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4), // Light yellow background
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Skip Tutorial?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF046EB8),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Are you sure you want to skip the tutorial?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black87,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF046EB8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(
                                  color: Color(0xFF046EB8),
                                  width: 2,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF046EB8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
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

    if (shouldSkip == true) {
      try {
        await AudioService().playClickSound();
      } catch (e) {
        debugPrint('Click sound not found: $e');
      }

      await _markTutorialComplete();
      widget.onComplete();
    }
  }

  Rect? _getHighlightRect(TutorialStep step) {
    if (step.highlightKey == null) return null;

    final key = widget.elementKeys[step.highlightKey];
    if (key?.currentContext == null) return null;

    final RenderBox? renderBox =
    key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final highlightRect = _getHighlightRect(step);

    return Stack(
      children: [
        // Dark overlay with hole for highlighted element
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                painter: HighlightPainter(
                  elementRect: highlightRect,
                  pulseValue: _pulseController.value,
                  expandBy: step.expandHighlight,
                  useCircle: step.useCircle,
                  overlayOpacity: step.overlayOpacity,
                ),
              );
            },
          ),
        ),
        // Tutorial content card
        _buildTutorialCard(step),
      ],
    );
  }

  Widget _buildTutorialCard(TutorialStep step) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // ── Responsive sizing ──────────────────────────────────────────────────
    final cardMargin = isMobile
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.all(20);
    final innerPadding = isMobile ? 12.0 : 30.0;
    final titleFontSize = isMobile ? 17.0 : 26.0;
    final descFontSize = isMobile ? 12.0 : 15.0;
    final descHPadding = isMobile ? 4.0 : 20.0;
    final birdSize = isMobile ? 150.0 : 200.0;
    final birdLeft = isMobile ? -40.0 : -70.0;
    // On mobile push bird below the card so it never covers the Back button.
    // bottom: -(birdSize - peek) means only `peek` px of bird top shows above the card edge.
    final birdBottom = isMobile ? -(birdSize - 65) : -60.0;

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 550),
      margin: cardMargin,
      decoration: BoxDecoration(
        color: const Color(0xFFFDD000), // Yellow outer border
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.4),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main content with dashed border
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomPaint(
              painter: DashedBorderPainter(),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4), // Light yellow background
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: EdgeInsets.all(innerPadding),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title - fades in first
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
                            ),
                          ),
                          child: Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                              color: const Color(0xFF046EB8),
                              letterSpacing: -0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 16),

                        // Description text - fades in third
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: descHPadding),
                            child: Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: descFontSize,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                                height: 1.6,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isMobile ? 10 : 28),

                        // Navigation buttons - fade in last
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentStep > 0) ...[
                                ElevatedButton(
                                  onPressed: _previousStep,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF046EB8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                        color: Color(0xFF046EB8),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Back',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              ElevatedButton(
                                onPressed: _nextStep,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF046EB8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 28,
                                    vertical: 12,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _currentStep < _steps.length - 1
                                          ? 'Next'
                                          : 'Got it!',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 4 : 12),

                        // Skip tutorial button
                        FadeTransition(
                          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _fadeController,
                              curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                            ),
                          ),
                          child: TextButton(
                            onPressed: _skipTutorial,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text(
                              'Skip Tutorial',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF666666),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bird mascot - positioned OUTSIDE bottom left
          Positioned(
            left: birdLeft,
            bottom: birdBottom,
            child: Image.asset(
              'assets/images-icons/bird.png',
              width: birdSize,
              height: birdSize,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: isMobile ? 130 : 180,
                  height: isMobile ? 130 : 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF046EB8),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    step.icon,
                    size: isMobile ? 65 : 90,
                    color: step.iconColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    // ── Mobile: resolve per-step mobile position override ─────────────────
    if (isMobile) {
      final mobilePos = step.mobilePosition ?? step.position;
      switch (mobilePos) {
        case TutorialPosition.topCenter:
          // Card sits near the top — highlighted element stays visible below
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: card,
            ),
          );
        case TutorialPosition.bottomCenter:
          // Card sits near the bottom — highlighted element stays visible above
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: card,
            ),
          );
        case TutorialPosition.center:
        case TutorialPosition.topRight:
        case TutorialPosition.topLeft:
          return Center(child: card);
      }
    }

    // ── Desktop positions (unchanged) ──────────────────────────────────────
    switch (step.position) {
      case TutorialPosition.center:
        return Center(child: card);
      case TutorialPosition.topCenter:
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: card,
          ),
        );
      case TutorialPosition.bottomCenter:
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: card,
          ),
        );
      case TutorialPosition.topRight:
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 40),
            child: card,
          ),
        );
      case TutorialPosition.topLeft:
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 40),
            child: card,
          ),
        );
    }
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B) // Darker gold color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const dashWidth = 10.0;
    const dashSpace = 8.0;
    const radius = 22.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = _createDashedPath(path, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source, double dashWidth, double dashSpace) {
    final dashedPath = Path();
    final metricsIterator = source.computeMetrics().iterator;

    while (metricsIterator.moveNext()) {
      final metric = metricsIterator.current;
      double distance = 0.0;

      while (distance < metric.length) {
        final length = dashWidth.clamp(0.0, metric.length - distance);
        dashedPath.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    return dashedPath;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TutorialStep {
  final String title;
  final String description;
  final String? highlightKey;
  final TutorialPosition position;
  /// Override position used on mobile (width < 600). Falls back to [position] if null.
  final TutorialPosition? mobilePosition;
  final IconData icon;
  final Color iconColor;
  final double expandHighlight;
  final bool useCircle;
  final double overlayOpacity;

  TutorialStep({
    required this.title,
    required this.description,
    this.highlightKey,
    required this.position,
    this.mobilePosition,
    required this.icon,
    required this.iconColor,
    this.expandHighlight = 0,
    this.useCircle = false,
    this.overlayOpacity = 0.7,
  });
}

enum TutorialPosition {
  center,
  topCenter,
  bottomCenter,
  topRight,
  topLeft,
}

class HighlightPainter extends CustomPainter {
  final Rect? elementRect;
  final double pulseValue;
  final double expandBy;
  final bool useCircle;
  final double overlayOpacity;

  HighlightPainter({
    required this.elementRect,
    required this.pulseValue,
    this.expandBy = 0,
    this.useCircle = false,
    this.overlayOpacity = 0.85,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (elementRect == null) {
      final overlayPaint = Paint()
        ..color = Color.fromRGBO(0, 0, 0, overlayOpacity);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        overlayPaint,
      );
      return;
    }

    final rect = elementRect!;
    final expandedRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width + expandBy,
      height: rect.height + expandBy,
    );

    final holePath = Path();
    if (useCircle) {
      final radius = (expandedRect.width + expandedRect.height) / 4;
      holePath.addOval(Rect.fromCenter(
        center: expandedRect.center,
        width: radius * 2,
        height: radius * 2,
      ));
    } else {
      holePath.addRRect(RRect.fromRectAndRadius(
        expandedRect,
        const Radius.circular(25),
      ));
    }

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    final overlayPaint = Paint()
      ..color = Color.fromRGBO(0, 0, 0, overlayOpacity);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      overlayPaint,
    );

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    canvas.drawPath(holePath, clearPaint);

    canvas.restore();

    final borderPaint = Paint()
      ..color = const Color(0xFFFDD000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    if (useCircle) {
      final radius = (expandedRect.width + expandedRect.height) / 4;
      canvas.drawCircle(expandedRect.center, radius, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(expandedRect, const Radius.circular(25)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(HighlightPainter oldDelegate) => true;
}