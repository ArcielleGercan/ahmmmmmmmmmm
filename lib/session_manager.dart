import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'homepage.dart';

/// Manages persisting and restoring the user session across page refreshes.
///
/// Rules:
/// • Session keys (session_*) → written on login, cleared on logout
/// • Tutorial keys            → NEVER touched here
/// • has_seen_app             → removed, no longer needed
///
/// Routing logic (handled in main.dart):
///   Session exists  →  HomePage      (refresh while logged in)
///   No session      →  SplashScreen  (first open, after logout, new tab)
class SessionManager {
  SessionManager._();

  static const _keyUserId          = 'session_user_id';
  static const _keyUsername        = 'session_username';
  static const _keySchool          = 'session_school';
  static const _keyAge             = 'session_age';
  static const _keyCategory        = 'session_category';
  static const _keyStudentCategory = 'session_student_category';
  static const _keySex             = 'session_sex';
  static const _keyRegion          = 'session_region';
  static const _keyProvince        = 'session_province';
  static const _keyCity            = 'session_city';
  static const _keyAvatar          = 'session_avatar';
  static const _keyStars           = 'session_stars';

  // ── Save session after successful login ───────────────────────────────────
  static Future<void> saveSession(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId,   profile.id);
      await prefs.setString(_keyUsername, profile.username);
      await prefs.setString(_keySchool,   profile.school);
      await prefs.setString(_keyAge,      profile.age);
      await prefs.setString(_keyCategory, profile.category);
      await prefs.setString(_keySex,      profile.sex);
      await prefs.setString(_keyRegion,   profile.region);
      await prefs.setString(_keyProvince, profile.province);
      await prefs.setString(_keyCity,     profile.city);
      await prefs.setString(_keyAvatar,   profile.avatar);
      await prefs.setInt(_keyStars,       profile.stars);
      if (profile.studentCategory != null) {
        await prefs.setString(_keyStudentCategory, profile.studentCategory!);
      } else {
        await prefs.remove(_keyStudentCategory);
      }
      debugPrint('SessionManager: session saved for ${profile.username}');
    } catch (e) {
      debugPrint('SessionManager: saveSession failed: $e');
    }
  }

  // ── Restore session on app start ──────────────────────────────────────────
  static Future<UserProfile?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);
      if (userId == null || userId.isEmpty) return null;

      return UserProfile(
        id:              userId,
        username:        prefs.getString(_keyUsername) ?? '',
        school:          prefs.getString(_keySchool)   ?? '',
        age:             prefs.getString(_keyAge)      ?? '',
        category:        prefs.getString(_keyCategory) ?? '',
        studentCategory: prefs.getString(_keyStudentCategory),
        sex:             prefs.getString(_keySex)      ?? '',
        region:          prefs.getString(_keyRegion)   ?? '',
        province:        prefs.getString(_keyProvince) ?? '',
        city:            prefs.getString(_keyCity)     ?? '',
        avatar:          prefs.getString(_keyAvatar)   ?? 'assets/images-avatars/Adventurer.png',
        stars:           prefs.getInt(_keyStars)       ?? 0,
      );
    } catch (e) {
      debugPrint('SessionManager: restoreSession failed: $e');
      return null;
    }
  }

  // ── Clear session on logout ────────────────────────────────────────────────
  /// Removes ONLY session_* keys. Never touches tutorial or rating keys.
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keySchool);
      await prefs.remove(_keyAge);
      await prefs.remove(_keyCategory);
      await prefs.remove(_keyStudentCategory);
      await prefs.remove(_keySex);
      await prefs.remove(_keyRegion);
      await prefs.remove(_keyProvince);
      await prefs.remove(_keyCity);
      await prefs.remove(_keyAvatar);
      await prefs.remove(_keyStars);
      debugPrint('SessionManager: session cleared');
    } catch (e) {
      debugPrint('SessionManager: clearSession failed: $e');
    }
  }

  static Future<bool> hasSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_keyUserId);
      return userId != null && userId.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}