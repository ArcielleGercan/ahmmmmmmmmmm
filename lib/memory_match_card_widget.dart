import 'dart:math';
import 'package:flutter/material.dart';
import 'memory_match_models.dart';

/// An individual memory-match card.
///
/// Extracted as its own [StatefulWidget] with a dedicated
/// [AnimationController] so that timer ticks and other parent-level
/// [setState] calls do NOT trigger card rebuilds. Each card only
/// repaints when its own flip state changes.
class MemoryMatchCard extends StatefulWidget {
  final CardItem card;
  final int index;
  final String backImage;
  final Color borderColor;
  final VoidCallback onTap;

  const MemoryMatchCard({
    super.key,
    required this.card,
    required this.index,
    required this.backImage,
    required this.borderColor,
    required this.onTap,
  });

  @override
  State<MemoryMatchCard> createState() => _MemoryMatchCardState();
}

class _MemoryMatchCardState extends State<MemoryMatchCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool _showingFront = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _showingFront = widget.card.isFlipped || widget.card.isMatched;
    if (_showingFront) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(MemoryMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShowFront =
        widget.card.isFlipped || widget.card.isMatched;
    if (shouldShowFront != _showingFront) {
      _showingFront = shouldShowFront;
      if (_showingFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 180,
          height: 270,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.card.isMatching
                  ? Colors.greenAccent
                  : widget.card.isNotMatching
                      ? Colors.red
                      : (_showingFront
                          ? widget.borderColor
                          : Colors.transparent),
              width: widget.card.isMatching || widget.card.isNotMatching
                  ? 4
                  : (_showingFront ? 3 : 0),
            ),
            boxShadow: [
              if (widget.card.isMatching)
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              if (widget.card.isNotMatching)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              final angle = _animation.value * pi;
              final isBack = _animation.value < 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isBack
                      ? Image.asset(
                          widget.backImage,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          cacheHeight: 540,
                        )
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: Image.asset(
                            widget.card.imagePath,
                            fit: BoxFit.cover,
                            cacheWidth: 360,
                            cacheHeight: 540,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}