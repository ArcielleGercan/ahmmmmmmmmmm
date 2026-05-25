import 'package:flutter/material.dart';

/// Displays the current game timer as a circular badge.
///
/// Driven by a [ValueNotifier<int>] so only this widget repaints on every
/// tick — the rest of the game board stays untouched.
///
/// Used by both Memory Match and Whiz Puzzle.
class GameTimerDisplay extends StatelessWidget {
  final ValueNotifier<int> timerNotifier;
  final Color color;

  const GameTimerDisplay({
    super.key,
    required this.timerNotifier,
    required this.color,
  });

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: timerNotifier,
      builder: (_, seconds, __) => Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white, width: 5),
        ),
        alignment: Alignment.center,
        child: Text(
          _format(seconds),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}