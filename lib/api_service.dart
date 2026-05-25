import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// Centralised API service for all Admin calls.
/// Update [baseUrl] to match your Laravel server address.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Change this to your server URL ──────────────────────────────────────
  static String baseUrl = AppConfig.baseUrl;
  // ────────────────────────────────────────────────────────────────────────

  static const String _tokenKey = 'admin_session_token';

  // In-memory token cache — survives Flutter Web hot reload / origin issues
  static String? _cachedToken;

  // ─── Token helpers ───────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    _cachedToken = token;
    return token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = null;
    await prefs.remove(_tokenKey);
  }

  // ─── HTTP helpers ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> permanentDeleteQuestion(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/questions/$id/permanent'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Invalid server response.'};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════════════════════════

  /// Login — returns token on success.
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: await _headers(auth: false),
        body: jsonEncode({'username': username, 'password': password}),
      );
      final data = _decode(res);
      if (data['success'] == true && data['token'] != null) {
        await saveToken(data['token'] as String);
      }
      return data;
    } catch (e) {
      debugPrint('login error: $e');
      return {'success': false, 'message': 'Cannot reach server. Check your connection.'};
    }
  }

  /// Logout — clears stored token.
  Future<void> logout() async {
    try {
      final headers = await _headers();
      await http.post(Uri.parse('$baseUrl/admin/logout'), headers: headers);
    } catch (_) {}
    await clearToken();
  }

  /// Get admin profile.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/profile'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  QUESTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch paginated questions with optional filters.
  Future<Map<String, dynamic>> getQuestions({
    String? category,
    String? difficulty,
    String? yearLevel,
    int? status,
    String? search,
    String sortBy = 'id',
    String sortDir = 'asc',
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (category != null) params['category'] = category;
    if (difficulty != null) params['difficulty'] = difficulty;
    if (yearLevel != null) params['year_level'] = yearLevel;
    if (status != null) params['status'] = status.toString();
    if (search != null && search.isNotEmpty) params['search'] = search;

    try {
      final uri = Uri.parse('$baseUrl/admin/questions').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _headers());
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Add a new question.
  Future<Map<String, dynamic>> addQuestion(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/questions'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update an existing question.
  Future<Map<String, dynamic>> updateQuestion(String id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/questions/$id'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Soft-delete (deactivate) a question.
  Future<Map<String, dynamic>> deleteQuestion(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/questions/$id'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Restore a soft-deleted question.
  Future<Map<String, dynamic>> restoreQuestion(String id) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/admin/questions/$id/restore'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DIFFICULTY SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all difficulty settings (public — no auth needed).
  Future<Map<String, dynamic>> getDifficultySettings() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/difficulty-settings'),
        headers: {'Accept': 'application/json'},
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update difficulty settings for a specific level.
  Future<Map<String, dynamic>> updateDifficultySettings(
      String level, {
        required int numQuestions,
        required int timePerQn,
      }) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/difficulty-settings/$level'),
        headers: await _headers(),
        body: jsonEncode({
          'num_questions': numQuestions,
          'time_per_qn': timePerQn,
        }),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PLAYERS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all players with optional search/filter/sort/pagination.
  Future<Map<String, dynamic>> getPlayers({
    String? category,
    String? sex,
    String? search,
    String sortBy = 'username',
    String sortDir = 'asc',
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'sort_by': sortBy,
      'sort_dir': sortDir,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (sex != null && sex.isNotEmpty) params['sex'] = sex;
    if (search != null && search.isNotEmpty) params['search'] = search;

    try {
      final uri = Uri.parse('$baseUrl/admin/players').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _headers());
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Add a new player.
  Future<Map<String, dynamic>> addPlayer(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/players'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update a player's profile.
  Future<Map<String, dynamic>> updatePlayer(String id, Map<String, dynamic> data) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/admin/players/$id'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Permanently delete a player.
  Future<Map<String, dynamic>> deletePlayer(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/players/$id'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ADMINS MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all admins.
  Future<Map<String, dynamic>> getAdmins({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;

    try {
      final uri = Uri.parse('$baseUrl/admin/admins').replace(queryParameters: params);
      final res = await http.get(uri, headers: await _headers());
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Add a new admin account with optional real photo upload.
  Future<Map<String, dynamic>> addAdmin({
    required String username,
    required String password,
    String? sex,
    String? avatar,
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    try {
      final body = <String, dynamic>{
        'username': username,
        'password': password,
        if (sex != null) 'sex': sex,
        if (avatar != null) 'avatar': avatar,
        if (imageBytes != null) 'image_base64': base64Encode(imageBytes),
      };
      final res = await http.post(
        Uri.parse('$baseUrl/admin/admins'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update an admin's username, sex, or photo.
  Future<Map<String, dynamic>> updateAdmin(String id, Map<String, dynamic> data, {Uint8List? imageBytes}) async {
    try {
      final body = Map<String, dynamic>.from(data);
      if (imageBytes != null) body['image_base64'] = base64Encode(imageBytes);
      final res = await http.put(
        Uri.parse('$baseUrl/admin/admins/$id'),
        headers: await _headers(),
        body: jsonEncode(body),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Delete an admin account.
  Future<Map<String, dynamic>> deleteAdmin(String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/admin/admins/$id'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Change an admin's password (requires old password verification).
  Future<Map<String, dynamic>> changeAdminPassword(
      String id, {
        required String oldPassword,
        required String newPassword,
      }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/admins/$id/change-password'),
        headers: await _headers(),
        body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }


















  /// Reset a player's password (admin action — no old password required).
  Future<Map<String, dynamic>> changePlayerPassword(
      String id, {
        required String newPassword,
      }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/players/$id/change-password'),
        headers: await _headers(),
        body: jsonEncode({'new_password': newPassword}),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LEADERBOARD
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch badge (challenge) leaderboard — sorted by total badges descending.
  Future<Map<String, dynamic>> getChallengLeaderboard() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/leaderboard/challenge'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Fetch battle (stars) leaderboard — sorted by total stars descending.
  Future<Map<String, dynamic>> getBattleLeaderboard() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/leaderboard/battle'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ANALYTICS / DASHBOARD STATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Fetch all analytics data in one call.
  /// Returns data.total_players, data.average_rating, data.gender_distribution,
  /// data.age_distribution, data.players_by_region, data.gender_by_game_mode,
  /// data.badges_by_gender_level, data.game_mode_by_age.
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin/analytics'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BADGE SYSTEM (admin)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get a player's badge summary (progress + official badges + unclaimed).
  Future<Map<String, dynamic>> getPlayerBadgeSummary(String playerId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/badges/player/$playerId/summary'),
        headers: await _headers(),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GAME RESULTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Save challenge (Whiz Challenge) result.
  /// [timeTaken] = total seconds spent across all questions (int).
  Future<Map<String, dynamic>> saveChallengeResult({
    required String playerId,
    required String category,
    required String difficultyLevel,
    required int totalQuestions,
    required int correctAnswers,
    required int timeTaken,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/game/save-challenge-result'),
        headers: await _headers(auth: false),
        body: jsonEncode({
          'player_id':        playerId,
          'category':         category,
          'difficulty_level': difficultyLevel,
          'total_questions':  totalQuestions,
          'correct_answers':  correctAnswers,
          'time_taken':       timeTaken,
        }),
      ).timeout(const Duration(seconds: 15));
      return _decode(res);
    } catch (e) {
      debugPrint('saveChallengeResult error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Save battle result.
  Future<Map<String, dynamic>> saveBattleResult({
    required String playerId,
    String? opponentId,
    String? opponentUsername,
    int? opponentScore,
    required String category,
    required String difficultyLevel,
    required int playerScore,
    required String result, // 'won' or 'lost'
    required String battleId,
    required int questionsAnswered,
    required int correctAnswers,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/game/save-battle-result'),
        headers: await _headers(auth: false),
        body: jsonEncode({
          'player_id':          playerId,
          if (opponentId != null) 'opponent_id': opponentId,
          if (opponentUsername != null) 'opponent_username': opponentUsername,
          if (opponentScore != null) 'opponent_score': opponentScore,
          'category':           category,
          'difficulty_level':   difficultyLevel,
          'player_score':       playerScore,
          'result':             result,
          'battle_id':          battleId,
          'questions_answered': questionsAnswered,
          'correct_answers':    correctAnswers,
        }),
      ).timeout(const Duration(seconds: 15));
      return _decode(res);
    } catch (e) {
      debugPrint('saveBattleResult error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Admin confirms physical reward was given for a difficulty.
  /// This marks all unclaimed rewards as admin-awarded and resets badge progress.
  Future<Map<String, dynamic>> adminAwardBadge(
      String playerId, {
        required String difficulty,
      }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin/players/$playerId/award-badge'),
        headers: await _headers(),
        body: jsonEncode({'difficulty': difficulty}),
      );
      return _decode(res);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}