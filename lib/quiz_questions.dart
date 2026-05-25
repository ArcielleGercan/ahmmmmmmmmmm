import 'package:flutter/foundation.dart' show debugPrint;
import 'quiz_api.dart';

class Question {
  final String question;
  final String? questionImage;
  final List<String> options;
  final List<String?> optionImages; // images for each choice (null if text-only)
  final String correctAnswer;

  Question({
    required this.question,
    this.questionImage,
    required this.options,
    required this.optionImages,
    required this.correctAnswer,
  });

  // Convert API QuizQuestion to local Question model
  factory Question.fromApiQuestion(QuizQuestion apiQuestion) {
    return Question(
      question: apiQuestion.question,
      questionImage: apiQuestion.questionImage,
      options: apiQuestion.options,
      optionImages: [
        apiQuestion.answer1Image,
        apiQuestion.answer2Image,
        apiQuestion.answer3Image,
        apiQuestion.answer4Image,
      ],
      correctAnswer: apiQuestion.correctAnswer,
    );
  }
}

class QuizData {
  // UPDATED: yearLevel is now optional
  static Future<List<Question>> getQuestions(
      String category,
      String difficulty,
      {String? yearLevel}  // Made optional
      ) async {
    try {
      final apiQuestions = await QuizApiService.fetchQuestions(
        category,
        difficulty,
        yearLevel: yearLevel,  // Pass as named parameter
      );

      return apiQuestions
          .map((apiQ) => Question.fromApiQuestion(apiQ))
          .toList();
    } catch (e) {
      // ✅ Rethrow so quiz_game.dart shows "Failed to load" instead of
      // "No questions available" — makes the real error visible in debug logs
      debugPrint('Error loading questions from API: $e');
      rethrow;
    }
  }
}