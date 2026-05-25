import 'package:flutter/material.dart';

/// A full-page results screen shared by **Memory Match** and **Whiz Puzzle**.
///
/// Pass game-specific labels via [subtitleParts] (e.g. 'EASY · Solar System').
/// The milestone widget is shown only when [newMilestone] is non-null.
class GameResultsPage extends StatelessWidget {
  // ── Identity ────────────────────────────────────────────────────────────
  /// Short string shown in the header pill, e.g. "EASY  ·  Solar System".
  final String subtitleParts;
  final Color difficultyColor;

  // ── Stats ────────────────────────────────────────────────────────────────
  final int yourTime;
  final int bestTime;
  final int personalBest;
  final int starsEarned;
  final int totalStars;
  final int moves;

  // ── Flags ────────────────────────────────────────────────────────────────
  final bool isNewBestTime;
  final bool isNewPersonalRecord;

  // ── Milestone (optional) ─────────────────────────────────────────────────
  final Map<String, dynamic>? newMilestone;

  // ── Actions ─────────────────────────────────────────────────────────────
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const GameResultsPage({
    super.key,
    required this.subtitleParts,
    required this.difficultyColor,
    required this.yourTime,
    required this.bestTime,
    required this.personalBest,
    required this.starsEarned,
    required this.totalStars,
    required this.moves,
    required this.isNewBestTime,
    required this.isNewPersonalRecord,
    required this.onPlayAgain,
    required this.onExit,
    this.newMilestone,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _resultMessage {
    if (isNewBestTime) return 'You beat the best time!';
    if (isNewPersonalRecord) return 'You beat your personal best!';
    return 'Well done!';
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Stat box ─────────────────────────────────────────────────────────────

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
              top: -8,
              right: -8,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 1.0, end: 1.1),
                curve: Curves.easeInOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'NEW!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333333),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Sparkle decorations ───────────────────────────────────────────────────

  List<Widget> _buildSparkles() {
    Widget sparkle() {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 1500),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeInOut,
        builder: (_, v, child) => Opacity(
          opacity: v > 0.5 ? 1.0 - v : v * 2,
          child: Transform.scale(
            scale: v > 0.5 ? 2 - v * 2 : v * 2,
            child: child,
          ),
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      );
    }

    return [
      Positioned(top: 20, left: 20, child: sparkle()),
      Positioned(top: 40, right: 30, child: sparkle()),
      Positioned(bottom: 40, right: 20, child: sparkle()),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: difficultyColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      subtitleParts,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),

                        // ── CONGRATULATIONS title ──────────────────────────
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (_, value, child) => Transform.scale(
                            scale: value,
                            child: Opacity(
                                opacity: value.clamp(0.0, 1.0), child: child),
                          ),
                          child: Center(
                            child: Stack(
                              children: [
                                Text(
                                  'CONGRATULATIONS!',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 6
                                      ..color = const Color(0xFFC5A000),
                                    fontFamily: 'Poppins',
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Text(
                                  'CONGRATULATIONS!',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFDD000),
                                    fontFamily: 'Poppins',
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Badge ──────────────────────────────────────────
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (_, value, child) => Transform.scale(
                            scale: value,
                            child: Transform.rotate(
                              angle: (1 - value) * -3.14,
                              child: Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: child),
                            ),
                          ),
                          child: SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ..._buildSparkles(),
                                Center(
                                  child: Image.asset(
                                    'assets/images-badges/whiz-achiever.png',
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Achievement message ───────────────────────────
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (_, value, child) =>
                              Opacity(opacity: value, child: child),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize:
                                  isNewPersonalRecord || isNewBestTime
                                      ? 22
                                      : 20,
                              fontWeight: FontWeight.bold,
                              color: difficultyColor,
                              fontFamily: 'Poppins',
                            ),
                            child: Text(
                              _resultMessage,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Performance stats ─────────────────────────────
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (_, value, child) => Transform.translate(
                            offset: Offset(0, 30 * (1 - value)),
                            child:
                                Opacity(opacity: value, child: child),
                          ),
                          child: Container(
                            constraints:
                                const BoxConstraints(maxWidth: 500),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFFF0F0F0),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.12),
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
                                // Top row: Your Time · Best Time · Personal Best
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(yourTime),
                                        'Your Time',
                                        const Color(0xFF90CAF9),
                                        const Color(0xFF0D47A1),
                                        false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(bestTime),
                                        'Best Time',
                                        const Color(0xFFFFCC80),
                                        const Color(0xFFE65100),
                                        isNewBestTime,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(personalBest),
                                        'Personal Best',
                                        const Color(0xFFA5D6A7),
                                        const Color(0xFF1B5E20),
                                        isNewPersonalRecord,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Bottom row: Stars Earned · Total Stars
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatBox(
                                        '+$starsEarned',
                                        'Stars Earned',
                                        const Color(0xFFFFF59D),
                                        const Color(0xFFF57F17),
                                        false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatBox(
                                        '$totalStars',
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

                        // ── Milestone badge ───────────────────────────────
                        if (newMilestone != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFDD000)
                                      .withValues(alpha: 0.2),
                                  const Color(0xFFFDD000)
                                      .withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFFDD000), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.military_tech,
                                    color: Color(0xFFFDD000), size: 48),
                                const SizedBox(height: 4),
                                Text(
                                  '${newMilestone!['icon']} MILESTONE!',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFDD000),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${newMilestone!['prize']}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ── Action buttons ────────────────────────────────
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (_, value, child) =>
                              Opacity(opacity: value, child: child),
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 400),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onExit,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: difficultyColor,
                                        side: BorderSide(
                                            color: difficultyColor, width: 3),
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
                                      onPressed: onPlayAgain,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: difficultyColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        elevation: 4,
                                        shadowColor: difficultyColor
                                            .withValues(alpha: 0.3),
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
      ),
    );
  }
}