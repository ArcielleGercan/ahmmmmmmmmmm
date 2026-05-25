import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'memory_match_models.dart';

/// Full-page results screen shown after completing a game.
class MemoryMatchResultsPage extends StatefulWidget {
  final Difficulty difficulty;
  final int starsEarned;
  final int yourTime;
  final int bestTime;
  final int personalBest;
  final int totalStars;
  final int pairs;
  final int moves;
  final bool isNewBestTime;
  final bool isNewPersonalRecord;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const MemoryMatchResultsPage({
    super.key,
    required this.difficulty,
    required this.starsEarned,
    required this.yourTime,
    required this.bestTime,
    required this.personalBest,
    required this.totalStars,
    required this.pairs,
    required this.moves,
    required this.isNewBestTime,
    required this.isNewPersonalRecord,
    required this.onPlayAgain,
    required this.onExit,
  });

  @override
  State<MemoryMatchResultsPage> createState() => _MemoryMatchResultsPageState();
}

class _MemoryMatchResultsPageState extends State<MemoryMatchResultsPage> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3))..play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _getResultMessage() {
    if (widget.isNewBestTime) return 'You beat the best time!';
    if (widget.isNewPersonalRecord) return 'You beat your personal best!';
    return 'Well done!';
  }

  Widget _buildStatBox(
    String value,
    String label,
    Color bgColor,
    Color textColor,
    bool showNewBadge,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontFamily: 'Poppins',
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (showNewBadge)
            Positioned(
              top: -10,
              right: -8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'NEW!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = widget.difficulty.color;
    final incorrectMoves = (widget.moves - widget.pairs)
        .clamp(0, widget.moves);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 10,
              gravity: 0.3,
              colors: const [
                Color(0xFFFDD000),
                Color(0xFF5F6FDB),
                Color(0xFF046EB8),
                Colors.red,
                Colors.green,
                Colors.orange,
                Colors.pink,
                Colors.purple,
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      // Trophy / Icon
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: diffColor.withValues(alpha: 0.15),
                            border: Border.all(color: diffColor, width: 3),
                          ),
                          child: Icon(
                            widget.isNewBestTime
                                ? Icons.emoji_events
                                : widget.isNewPersonalRecord
                                    ? Icons.star
                                    : Icons.check_circle,
                            size: 52,
                            color: diffColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (_, v, child) =>
                            Opacity(opacity: v, child: child),
                        child: Text(
                          widget.isNewBestTime
                              ? 'NEW RECORD!'
                              : widget.isNewPersonalRecord
                                  ? 'PERSONAL BEST!'
                                  : 'GAME COMPLETE!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: diffColor,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getResultMessage(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Quick stats banner
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOut,
                        builder: (_, v, child) =>
                            Opacity(opacity: v, child: child),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDD000),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'PERFORMANCE STATS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF816A03),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Correct
                                  Expanded(
                                    child: _miniStatBox(
                                      '${widget.pairs}',
                                      'Correct',
                                      const Color(0xFFB8E6B8),
                                      const Color(0xFF2E7D32),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Incorrect
                                  Expanded(
                                    child: _miniStatBox(
                                      '$incorrectMoves',
                                      'Incorrect',
                                      const Color(0xFFFFCDD2),
                                      const Color(0xFFC62828),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Avg time per pair
                                  Expanded(
                                    child: _miniStatBox(
                                      '${(widget.yourTime / widget.pairs).toStringAsFixed(1)}s',
                                      'Avg. Time/Pair',
                                      const Color(0xFFD1C4E9),
                                      const Color(0xFF5E35B1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Performance stats boxes
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOut,
                        builder: (_, v, child) => Transform.translate(
                          offset: Offset(0, 30 * (1 - v)),
                          child: Opacity(opacity: v, child: child),
                        ),
                        child: Container(
                          constraints:
                              const BoxConstraints(maxWidth: 500),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFF0F0F0), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'PERFORMANCE STATS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                  fontFamily: 'Poppins',
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatBox(
                                      _formatTime(widget.yourTime),
                                      'Your Time',
                                      const Color(0xFF90CAF9),
                                      const Color(0xFF0D47A1),
                                      false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatBox(
                                      _formatTime(widget.bestTime),
                                      'Best Time',
                                      const Color(0xFFFFCC80),
                                      const Color(0xFFE65100),
                                      widget.isNewBestTime,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatBox(
                                      _formatTime(widget.personalBest),
                                      'Personal Best',
                                      const Color(0xFFA5D6A7),
                                      const Color(0xFF1B5E20),
                                      widget.isNewPersonalRecord,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatBox(
                                      '+${widget.starsEarned}',
                                      'Stars Earned',
                                      const Color(0xFFFFF59D),
                                      const Color(0xFFF57F17),
                                      false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildStatBox(
                                      '${widget.totalStars}',
                                      'Total Stars',
                                      const Color(0xFFCE93D8),
                                      const Color(0xFF4A148C),
                                      false,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Buttons
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween(begin: 0.0, end: 1.0),
                        builder: (_, v, child) =>
                            Opacity(opacity: v, child: child),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onExit,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: diffColor,
                                  side: BorderSide(
                                      color: diffColor, width: 3),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'EXIT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: widget.onPlayAgain,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: diffColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                  shadowColor: diffColor.withValues(
                                      alpha: 0.3),
                                ),
                                child: const Text(
                                  'PLAY AGAIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatBox(
      String value, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: fg,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}