// Star System Helper
// Add this to a new file: lib/helpers/star_system.dart

import 'package:http/http.dart' as http;
import 'dart:convert';

class StarSystem {
  static String get baseUrl => AppConfig.baseUrl;

  // Star rewards based on performance
  static const Map<String, int> difficultyMultipliers = {
    'EASY': 1,
    'AVERAGE': 2,
    'DIFFICULT': 3,
  };

  // Star milestones for prizes
  static const List<StarMilestone> milestones = [
    StarMilestone(stars: 50, prize: "Bronze Badge", icon: "🥉"),
    StarMilestone(stars: 100, prize: "Silver Badge", icon: "🥈"),
    StarMilestone(stars: 250, prize: "Gold Badge", icon: "🥇"),
    StarMilestone(stars: 500, prize: "Platinum Badge", icon: "💎"),
    StarMilestone(stars: 1000, prize: "Diamond Badge", icon: "💠"),
  ];

  /// Calculate stars earned for Memory Match based on time performance
  static int calculateMemoryMatchStars({
    required String difficulty,
    required int timeSeconds,
    required int? globalFastestTime,
  }) {
    final baseStars = difficultyMultipliers[difficulty] ?? 1;

    if (globalFastestTime == null) {
      // First person to complete gets bonus
      return baseStars * 5; // 5, 10, or 15 stars
    }

    // Calculate performance ratio
    final performanceRatio = globalFastestTime / timeSeconds;

    if (performanceRatio >= 1.0) {
      // Beat or matched the record
      return baseStars * 5; // 5, 10, or 15 stars
    } else if (performanceRatio >= 0.8) {
      // Within 20% of record
      return baseStars * 3; // 3, 6, or 9 stars
    } else if (performanceRatio >= 0.6) {
      // Within 40% of record
      return baseStars * 2; // 2, 4, or 6 stars
    } else {
      // Completed but slower
      return baseStars; // 1, 2, or 3 stars
    }
  }

  /// Calculate stars earned for Puzzle based on time performance
  static int calculatePuzzleStars({
    required String difficulty,
    required int timeSeconds,
    required int? globalFastestTime,
  }) {
    final baseStars = difficultyMultipliers[difficulty] ?? 1;

    if (globalFastestTime == null) {
      // First person to complete gets bonus
      return baseStars * 5; // 5, 10, or 15 stars
    }

    // Calculate performance ratio
    final performanceRatio = globalFastestTime / timeSeconds;

    if (performanceRatio >= 1.0) {
      // Beat or matched the record
      return baseStars * 5; // 5, 10, or 15 stars
    } else if (performanceRatio >= 0.8) {
      // Within 20% of record
      return baseStars * 3; // 3, 6, or 9 stars
    } else if (performanceRatio >= 0.6) {
      // Within 40% of record
      return baseStars * 2; // 2, 4, or 6 stars
    } else {
      // Completed but slower
      return baseStars; // 1, 2, or 3 stars
    }
  }

  /// Award stars to a player
  static Future<bool> awardStars({
    required String playerId,
    required int stars,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/player/$playerId/stars'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'stars': stars}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error awarding stars: $e');
      return false;
    }
  }

  /// Get player's current stars
  static Future<int?> getPlayerStars(String playerId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/player/$playerId/stars'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['stars'];
      }
      return null;
    } catch (e) {
      print('Error getting player stars: $e');
      return null;
    }
  }

  /// Get next milestone for player
  static StarMilestone? getNextMilestone(int currentStars) {
    for (final milestone in milestones) {
      if (currentStars < milestone.stars) {
        return milestone;
      }
    }
    return null; // Player has reached all milestones
  }

  /// Get all achieved milestones
  static List<StarMilestone> getAchievedMilestones(int currentStars) {
    return milestones.where((m) => currentStars >= m.stars).toList();
  }

  /// Get stars needed for next milestone
  static int? getStarsToNextMilestone(int currentStars) {
    final next = getNextMilestone(currentStars);
    return next != null ? next.stars - currentStars : null;
  }
}

class StarMilestone {
  final int stars;
  final String prize;
  final String icon;

  const StarMilestone({
    required this.stars,
    required this.prize,
    required this.icon,
  });
}

