import 'audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class GameTutorialOverlay extends StatefulWidget {
  final String userId;
  final String gameType; // 'memory_match', 'challenge', 'battle', 'puzzle'
  final VoidCallback onComplete;

  const GameTutorialOverlay({
    super.key,
    required this.userId,
    required this.gameType,
    required this.onComplete,
  });

    static String get _baseUrl => '${AppConfig.baseUrl}';

  /// Check if tutorial should be shown for this user and game type.
  /// Checks local cache first (fast), then verifies with backend (source of truth).
  /// This means it shows only ONCE — no matter what device or if app is reinstalled.
  static Future<bool> shouldShowTutorial(String userId, String gameType) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'tutorial_${userId}_$gameType';

    // If local cache says already seen, trust it — no API call needed
    if (prefs.getBool(cacheKey) == true) {
      return false;
    }

    // Otherwise ask the backend (covers reinstall / new device)
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/$userId/game-tutorial-status?game_type=$gameType'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final hasSeenOnServer = data['has_seen_tutorial'] ?? false;

        if (hasSeenOnServer) {
          // Sync to local cache so future checks are instant
          await prefs.setBool(cacheKey, true);
          return false; // Already seen — don't show
        }
        return true; // Never seen on server — show it
      }
    } catch (e) {
      debugPrint('Tutorial status check failed, falling back to local: $e');
    }

    // Fallback: if API fails, show tutorial (better to show once extra than never)
    return true;
  }

  @override
  State<GameTutorialOverlay> createState() => _GameTutorialOverlayState();
}

class _GameTutorialOverlayState extends State<GameTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isVisible = false;

  Map<String, GameTutorial> get _tutorials => {
    'memory_match': GameTutorial(
      title: 'Ready for Whiz Memory Match?',
      icon: Icons.extension,
      iconColor: const Color(0xFF656BE6),
      steps: [
        '1. Choose your difficulty level',
        '2. Flip cards to find matching pairs',
        '3. Match all pairs to complete the game',
        '4. The faster you finish, the more stars you earn!',
      ],
    ),
    'challenge': GameTutorial(
      title: 'Ready for Whiz Challenge?',
      icon: Icons.quiz,
      iconColor: const Color(0xFFFDD000),
      steps: [
        '1. Select your desired level and difficulty',
        '2. Select a category (Math or Science)',
        '3. Answer all questions correctly',
        '4. Earn 3 perfect scores to win a badge!',
      ],
    ),
    'battle': GameTutorial(
      title: 'Ready for Whiz Battle?',
      icon: Icons.sports_esports,
      iconColor: const Color(0xFFC571E2),
      steps: [
        '1. Two ways to play: Create Battle or Join by entering the game code',
        '2. Correct answers + faster submissions = more points',
        '3. Beat your opponent to earn a badge!',
      ],
    ),
    'puzzle': GameTutorial(
      title: 'Ready for Whiz Puzzle?',
      icon: Icons.view_module,
      iconColor: const Color(0xFFE6833A),
      steps: [
        '1. Select your category and difficulty',
        '2. Select your difficulty level (Easy, Average, or Difficult)',
        '3. Drag and drop pieces to complete the puzzle',
        '4. The faster you solve it, the more stars you earn!',
      ],
    ),
  };

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isVisible = true);
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Mark tutorial as complete in BOTH backend (permanent) and local cache (fast).
  Future<void> _markGameTutorialComplete() async {
    final cacheKey = 'tutorial_${widget.userId}_${widget.gameType}';

    // 1. Save to backend — permanent, survives reinstall and new devices
    try {
      await http.post(
        Uri.parse('${GameTutorialOverlay._baseUrl}/user/mark-game-tutorial-complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'game_type': widget.gameType,
        }),
      ).timeout(const Duration(seconds: 5));
      debugPrint('✅ Tutorial marked complete on server: ${widget.gameType}');
    } catch (e) {
      debugPrint('⚠️ Failed to mark tutorial on server: $e');
    }

    // 2. Save to local cache — so next check is instant without an API call
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cacheKey, true);
      debugPrint('✅ Tutorial cached locally: $cacheKey');
    } catch (e) {
      debugPrint('Error saving tutorial to local cache: $e');
    }
  }

  void _onGotIt() async {
    try {
      await AudioService().playClickSound();
    } catch (e) {
      debugPrint('Click sound not found: $e');
    }

    await _animationController.reverse();
    await _markGameTutorialComplete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = _tutorials[widget.gameType];
    if (tutorial == null) {
      widget.onComplete();
      return const SizedBox.shrink();
    }

    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: const Color.fromRGBO(0, 0, 0, 0.75),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 550),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFDD000),
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CustomPaint(
                      painter: DashedBorderPainter(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                tutorial.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF046EB8),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'How to Play:',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ...tutorial.steps.asMap().entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF046EB8),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFFDD000),
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${entry.key + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Poppins',
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            entry.value.substring(3),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontFamily: 'Poppins',
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _onGotIt,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF046EB8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Got it!',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bird mascot
                  Positioned(
                    left: -70,
                    bottom: -60,
                    child: Image.asset(
                      'assets/images-icons/bird.png',
                      width: 200,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 180,
                          height: 180,
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
                            tutorial.icon,
                            size: 90,
                            color: tutorial.iconColor,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B)
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

class GameTutorial {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> steps;

  GameTutorial({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.steps,
  });
}