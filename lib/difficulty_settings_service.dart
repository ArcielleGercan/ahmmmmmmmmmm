import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'config.dart';

/// Singleton that fetches difficulty settings from the admin API
/// and caches them so quiz_game.dart reads dynamic time/points/questions.
class DifficultySettingsService {
  DifficultySettingsService._();
  static final DifficultySettingsService instance = DifficultySettingsService._();

  // ✅ FIX: Replace localhost with your server's actual local IP address.
  // Must match the IP you set in quiz_api.dart.
  // Example: 'http://192.168.1.5:8000/api'

  static String get _baseUrl => '${AppConfig.baseUrl}';


  // Cached settings — defaults match admin panel defaults
  Map<String, Map<String, int>> _settings = {
    'Easy':      {'questions': 10, 'time': 15},
    'Average':   {'questions': 10, 'time': 20},
    'Difficult': {'questions': 10, 'time': 25},
  };

  bool _loaded = false;

  // ── Public getters ─────────────────────────────────────────────
  int getTime(String difficulty)      => _settings[difficulty]?['time']      ?? 15;
  int getQuestions(String difficulty) => _settings[difficulty]?['questions'] ?? 10;
  Map<String, Map<String, int>> get all => Map.unmodifiable(_settings);

  // ── Fetch from API ─────────────────────────────────────────────
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/admin/difficulty-settings'),
          headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true) {
          final raw = body['settings'] as Map<String, dynamic>;
          for (final level in ['Easy', 'Average', 'Difficult']) {
            if (raw.containsKey(level)) {
              final s = raw[level] as Map<String, dynamic>;
              _settings[level] = {
                'questions': (s['num_questions'] as num?)?.toInt() ?? _settings[level]!['questions']!,
                'time':      (s['time_per_qn']   as num?)?.toInt() ?? _settings[level]!['time']!,
              };
            }
          }
          _loaded = true;
          if (kDebugMode) debugPrint('✅ DifficultySettings loaded: $_settings');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ DifficultySettings load failed, using defaults: $e');
    }
  }

  /// Called by admin panel after saving so quiz picks up changes immediately
  void update(String difficulty, {required int questions, required int time}) {
    _settings[difficulty] = {'questions': questions, 'time': time};
    if (kDebugMode) debugPrint('✅ DifficultySettings updated [$difficulty]: time=$time q=$questions');
  }

  void invalidate() => _loaded = false;
}