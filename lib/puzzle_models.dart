import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty
// ─────────────────────────────────────────────────────────────────────────────

/// Difficulty levels for Whiz Puzzle.
enum PuzzleDifficulty { easy, average, difficult }

extension PuzzleDifficultyX on PuzzleDifficulty {
  String get value {
    switch (this) {
      case PuzzleDifficulty.easy:      return 'EASY';
      case PuzzleDifficulty.average:   return 'AVERAGE';
      case PuzzleDifficulty.difficult: return 'DIFFICULT';
    }
  }

  String get displayLabel {
    switch (this) {
      case PuzzleDifficulty.easy:      return 'Easy';
      case PuzzleDifficulty.average:   return 'Average';
      case PuzzleDifficulty.difficult: return 'Difficult';
    }
  }

  String get gridLabel {
    switch (this) {
      case PuzzleDifficulty.easy:      return '3x3 grid';
      case PuzzleDifficulty.average:   return '4x4 grid';
      case PuzzleDifficulty.difficult: return '5x5 grid';
    }
  }

  int get gridSize {
    switch (this) {
      case PuzzleDifficulty.easy:      return 3;
      case PuzzleDifficulty.average:   return 4;
      case PuzzleDifficulty.difficult: return 5;
    }
  }

  double get cellSize {
    switch (this) {
      case PuzzleDifficulty.easy:      return 165.0;
      case PuzzleDifficulty.average:   return 125.0;
      case PuzzleDifficulty.difficult: return 105.0;
    }
  }

  Color get color {
    switch (this) {
      case PuzzleDifficulty.easy:      return const Color(0xFF1D9358);
      case PuzzleDifficulty.average:   return const Color(0xFF046EB8);
      case PuzzleDifficulty.difficult: return const Color(0xFFBD442E);
    }
  }

  /// Parse from a raw string ("EASY", "AVERAGE", "DIFFICULT").
  static PuzzleDifficulty fromString(String s) {
    switch (s.toUpperCase()) {
      case 'AVERAGE':   return PuzzleDifficulty.average;
      case 'DIFFICULT': return PuzzleDifficulty.difficult;
      default:          return PuzzleDifficulty.easy;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PuzzlePiece
// ─────────────────────────────────────────────────────────────────────────────

/// A single draggable tile in the Whiz Puzzle grid.
class PuzzlePiece {
  final int id;
  final int correctRow;
  final int correctCol;
  double trayX;
  double trayY;
  bool isLocked;
  bool isInTray;
  Offset? floatingPosition;

  PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.trayX,
    required this.trayY,
    required this.isLocked,
    this.isInTray = true,
    this.floatingPosition,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Categories
// ─────────────────────────────────────────────────────────────────────────────

/// Available puzzle image categories.
const List<Map<String, String>> puzzleCategories = [
  {'name': 'Solar System',  'image': 'assets/puzzle/solar_system.png'},
  {'name': 'Scientists',    'image': 'assets/puzzle/scientists.jpg'},
  {'name': 'Human Body',    'image': 'assets/puzzle/human_body.png'},
  {'name': 'Animals',       'image': 'assets/puzzle/animals.jpg'},
  {'name': 'Geometry',      'image': 'assets/puzzle/geometry.jpg'},
  {'name': 'Starbooks',     'image': 'assets/puzzle/starbookswhiz.jpeg'},
];

String categoryImage(String categoryName) {
  final match = puzzleCategories.firstWhere(
    (c) => c['name'] == categoryName,
    orElse: () => puzzleCategories.first,
  );
  return match['image']!;
}