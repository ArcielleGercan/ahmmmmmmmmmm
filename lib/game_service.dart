import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Holds the outcome of saving the fastest time.
class SaveTimeResult {
  final bool isNewRecord;
  final int? fastestTime;

  const SaveTimeResult({required this.isNewRecord, this.fastestTime});
}

/// Holds star-award results.
class StarAwardResult {
  final int starsEarned;
  final int totalStars;
  final Map<String, dynamic>? newMilestone;
  final Map<String, dynamic>? currentTier;

  const StarAwardResult({
    required this.starsEarned,
    required this.totalStars,
    this.newMilestone,
    this.currentTier,
  });
}

/// Holds both personal and global fastest times.
class FastestTimes {
  final int? personal;
  final int? global;

  const FastestTimes({this.personal, this.global});
}

/// Unified network service for all mini-games (memory match, puzzle, etc.).
///
/// Uses a single persistent [http.Client] to avoid per-request TCP handshakes.
/// Pass [gameType] ('memory_match' | 'puzzle') and an optional [category]
/// for endpoints that need it.
class GameService {
  GameService({String? baseUrl})
      : _baseUrl = baseUrl ?? 'http://localhost:8000';

  final String _baseUrl;
  final http.Client _client = http.Client();
  static const _headers = {'Content-Type': 'application/json'};

  // ── Fastest time ──────────────────────────────────────────────────────────

  /// Saves the fastest time and returns whether it is a new personal record.
  Future<SaveTimeResult> saveFastestTime({
    required String playerId,
    required String gameType,
    required String difficulty,
    required int timeSeconds,
    required int moves,
    String? category,
    int? currentPersonalBest,
  }) async {
    try {
      final body = <String, dynamic>{
        'player_id': playerId,
        'game_type': gameType,
        'difficulty': difficulty,
        'time_seconds': timeSeconds,
        'moves': moves,
      };
      if (category != null) body['category'] = category;

      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/game/fastest-time'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        bool isNewRecord = data['is_new_record'] as bool? ?? false;

        // Race-condition guard: only trust the flag if the time is actually faster.
        if (isNewRecord &&
            currentPersonalBest != null &&
            timeSeconds >= currentPersonalBest) {
          isNewRecord = false;
        }

        return SaveTimeResult(
          isNewRecord: isNewRecord,
          fastestTime: isNewRecord ? timeSeconds : currentPersonalBest,
        );
      }
    } catch (e) {
      debugPrint('GameService.saveFastestTime error: $e');
    }
    return SaveTimeResult(isNewRecord: false, fastestTime: currentPersonalBest);
  }

  /// Awards stars and returns updated totals.
  Future<StarAwardResult> awardStars({
    required String playerId,
    required String gameType,
    required String difficulty,
    required int starsEarned,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${AppConfig.baseUrl}/players/$playerId/stars'),
        headers: _headers,
        body: json.encode({
          'stars': starsEarned,
          'game_type': gameType,
          'difficulty': difficulty,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return StarAwardResult(
          starsEarned: starsEarned,
          totalStars: (data['total_stars'] as num).toInt(),
          newMilestone: data['new_milestone'] as Map<String, dynamic>?,
          currentTier: data['current_tier'] != null
              ? Map<String, dynamic>.from(
                  data['current_tier'] as Map<String, dynamic>)
              : null,
        );
      }
    } catch (e) {
      debugPrint('GameService.awardStars error: $e');
    }
    return StarAwardResult(starsEarned: starsEarned, totalStars: 0);
  }

  /// Loads both personal and global fastest times in parallel.
  Future<FastestTimes> loadFastestTimes({
    required String playerId,
    required String gameType,
    required String difficulty,
    String? category,
  }) async {
    try {
      // Use Uri() with queryParameters so spaces/special chars are encoded correctly.
      final personalParams = <String, String>{};
      if (category != null) personalParams['category'] = category;
      final personalUri = Uri.parse(
        '${AppConfig.baseUrl}/game/fastest-time/$playerId/$gameType/$difficulty',
      ).replace(queryParameters: personalParams.isEmpty ? null : personalParams);

      final leaderboardParams = <String, String>{
        'game_type': gameType,
        'difficulty': difficulty,
      };
      if (category != null) leaderboardParams['category'] = category;
      final leaderboardUri = Uri.parse(
        '${AppConfig.baseUrl}/game/fastest-times/leaderboard',
      ).replace(queryParameters: leaderboardParams);

      final results = await Future.wait([
        _client.get(personalUri),
        _client.get(leaderboardUri),
      ]);

      int? personal;
      int? global;

      final personalResp = results[0];
      if (personalResp.statusCode == 200) {
        final data =
            json.decode(personalResp.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          personal =
              (data['data']['time_seconds'] as num?)?.toInt();
        }
      }

      final leaderboardResp = results[1];
      if (leaderboardResp.statusCode == 200) {
        final data =
            json.decode(leaderboardResp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final times = data['data'] as List<dynamic>? ?? [];
          if (times.isNotEmpty) {
            global = (times[0]['time_seconds'] as num?)?.toInt();
          }
        }
      }

      return FastestTimes(personal: personal, global: global);
    } catch (e) {
      debugPrint('GameService.loadFastestTimes error: $e');
      return const FastestTimes();
    }
  }

  void dispose() => _client.close();
}