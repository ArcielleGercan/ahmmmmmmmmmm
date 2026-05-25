import 'package:flutter/material.dart';

/// Difficulty levels for the memory match game.
enum Difficulty { easy, average, difficult }

extension DifficultyX on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'EASY';
      case Difficulty.average:
        return 'AVERAGE';
      case Difficulty.difficult:
        return 'DIFFICULT';
    }
  }

  int get pairs {
    switch (this) {
      case Difficulty.easy:
        return 5;
      case Difficulty.average:
        return 6;
      case Difficulty.difficult:
        return 7;
    }
  }

  Color get color {
    switch (this) {
      case Difficulty.easy:
        return const Color(0xFF2E7D32);
      case Difficulty.average:
        return const Color(0xFF1976D2);
      case Difficulty.difficult:
        return const Color(0xFFD32F2F);
    }
  }

  String get assetPrefix => label.toLowerCase();

  String get backImage => 'assets/memorymatch/$assetPrefix.png';

  String frontImage(int index) =>
      'assets/memorymatch/$assetPrefix$index.png';

  /// Parse from legacy string ("EASY", "AVERAGE", "DIFFICULT").
  static Difficulty fromString(String s) {
    switch (s.toUpperCase()) {
      case 'AVERAGE':
        return Difficulty.average;
      case 'DIFFICULT':
        return Difficulty.difficult;
      default:
        return Difficulty.easy;
    }
  }
}

/// A single card in the memory match grid.
class CardItem {
  final int id;
  final String imagePath;
  bool isFlipped;
  bool isMatched;
  bool isMatching;
  bool isNotMatching;

  CardItem({
    required this.id,
    required this.imagePath,
    this.isFlipped = false,
    this.isMatched = false,
    this.isMatching = false,
    this.isNotMatching = false,
  });
}