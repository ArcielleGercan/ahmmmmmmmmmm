import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'config.dart';

class QuizQuestion {
  final String id;
  final String question;
  final String? questionImage;
  final String answer1;
  final String? answer1Image;
  final String answer2;
  final String? answer2Image;
  final String answer3;
  final String? answer3Image;
  final String answer4;
  final String? answer4Image;
  final String correctAnswer;
  final String category;
  final String difficultyLevel;
  final String? yearLevel;
  final int hasImages;

  QuizQuestion({
    required this.id,
    required this.question,
    this.questionImage,
    required this.answer1,
    this.answer1Image,
    required this.answer2,
    this.answer2Image,
    required this.answer3,
    this.answer3Image,
    required this.answer4,
    this.answer4Image,
    required this.correctAnswer,
    required this.category,
    required this.difficultyLevel,
    this.yearLevel,
    this.hasImages = 0,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      questionImage: json['question_image'],
      answer1: json['choice_a'] ?? '',
      answer1Image: json['choice_a_image'],
      answer2: json['choice_b'] ?? '',
      answer2Image: json['choice_b_image'],
      answer3: json['choice_c'] ?? '',
      answer3Image: json['choice_c_image'],
      answer4: json['choice_d'] ?? '',
      answer4Image: json['choice_d_image'],
      correctAnswer: json['correct_answer'] ?? '',
      category: json['category'] ?? '',
      difficultyLevel: json['difficulty_level'] ?? '',
      yearLevel: json['year_level'] ?? '',
      hasImages: json['has_images'] ?? 0,
    );
  }

  List<String> get options => [answer1, answer2, answer3, answer4];
}

class GameResultResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? gameResult;
  final Map<String, dynamic>? updatedProfile;
  final Map<String, dynamic>? categoryProgress;
  final Map<String, dynamic>? badgeAwarded;

  GameResultResponse({
    required this.success,
    required this.message,
    this.gameResult,
    this.updatedProfile,
    this.categoryProgress,
    this.badgeAwarded,
  });

  factory GameResultResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return GameResultResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      gameResult: data?['game_result'],
      updatedProfile: data?['updated_profile'],
      categoryProgress: data?['category_progress'],
      badgeAwarded: data?['badge_awarded'],
    );
  }

  bool get hasBadge => badgeAwarded != null;
}

class QuizApiService {
  static final http.Client _client = http.Client();

  static Future<List<QuizQuestion>> fetchQuestions(
    String category,
    String difficulty, {
    String? yearLevel,
  }) async {
    try {
      final encodedCategory = Uri.encodeComponent(category);
      final encodedDifficulty = Uri.encodeComponent(difficulty);
      final url = yearLevel != null
          ? Uri.parse(
              '${AppConfig.baseUrl}/quiz/questions/$encodedCategory/$encodedDifficulty/${Uri.encodeComponent(yearLevel)}')
          : Uri.parse(
              '${AppConfig.baseUrl}/quiz/questions/$encodedCategory/$encodedDifficulty');

      if (kDebugMode) {
        debugPrint('Fetching questions from: $url');
      }

      final response = await _client
          .get(url, headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception(
            'Connection timeout. Please check your internet connection.',
          );
        },
      );

      if (kDebugMode) {
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> questionsJson = data['questions'];
          return questionsJson
              .map((json) => QuizQuestion.fromJson(json))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load questions');
        }
      } else if (response.statusCode == 404) {
        throw Exception(
            'No questions found for this category, difficulty, and year level');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching questions: $e');
      }
      rethrow;
    }
  }

  static Future<GameResultResponse> saveChallengeResult({
    required String playerId,
    required String category,
    required String difficultyLevel,
    required int totalQuestions,
    required int correctAnswers,
    required int timeTaken,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/game/save-challenge-result');

      final body = {
        'player_id': playerId,
        'category': category,
        'difficulty_level': difficultyLevel,
        'total_questions': totalQuestions,
        'correct_answers': correctAnswers,
        'time_taken': timeTaken,
      };

      if (kDebugMode) {
        debugPrint('🎯 Saving challenge result to: $url');
        debugPrint('📦 Request body: ${json.encode(body)}');
      }

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout while saving game result');
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Response status: ${response.statusCode}');
        debugPrint('📄 Response body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return GameResultResponse.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to save game result');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving game result: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> saveBattleResult({
    required String playerId,
    required String category,
    required String difficulty,
    required int score,
    required String result,
    required int questionsAnswered,
    required int correctAnswers,
    required String battleId,
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/game/save-battle-result');

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'player_id': playerId,
          'category': category,
          'difficulty_level': difficulty,
          'player_score': score,
          'result': result,
          'battle_id': battleId,
          'questions_answered': questionsAnswered,
          'correct_answers': correctAnswers,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('✅ Battle result saved successfully');
        if (data['badge_awarded'] != null) {
          debugPrint('🎯 Badge info: ${data['badge_awarded']}');
        }
        return data;
      } else {
        debugPrint('⚠️ Failed to save battle result: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error saving battle result: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getPlayerStats(String userId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/game/stats/$userId');

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      throw Exception('Failed to load player stats');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching player stats: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getPlayerBadges(String playerId) async {
    try {
      final url =
          Uri.parse('${AppConfig.baseUrl}/badges/player/$playerId/summary');

      if (kDebugMode) {
        debugPrint('🏆 Fetching badges from: $url');
      }

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      throw Exception('Failed to load badges');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching badges: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getBadgeStatistics(
      String playerId) async {
    try {
      final url = Uri.parse(
          '${AppConfig.baseUrl}/badges/player/$playerId/statistics');

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      throw Exception('Failed to load badge statistics');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching badge statistics: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> fetchStatistics() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/quiz/statistics');

      final response = await _client.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['statistics'];
        }
      }
      throw Exception('Failed to load statistics');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching statistics: $e');
      }
      rethrow;
    }
  }
}