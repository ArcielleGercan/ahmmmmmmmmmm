import 'dart:async';
import 'package:flutter/foundation.dart';

// ✅ Uses the browser's native Web Speech API directly via JS interop.
// More reliable on Flutter Web than flutter_tts, and requires no extra package
// — just `web: ^1.1.0` which is already in your pubspec.yaml.
//
// For non-web platforms (Android/iOS) it falls back silently so the app
// still compiles and runs — it just won't speak on those platforms.
// If you need Android/iOS TTS too, keep flutter_tts alongside this and
// check kIsWeb to decide which one to call.

import 'web_tts_service_web.dart'
    if (dart.library.io) 'web_tts_service_stub.dart';

/// Public API — same shape as the old flutter_tts calls in quiz_game.dart.
class WebTtsService {
  static final WebTtsService _instance = WebTtsService._();
  factory WebTtsService() => _instance;
  WebTtsService._();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  /// Call once in initState before the first speak.
  Future<void> init() async {
    await TtsPlatform.init();
  }

  /// Stops any current speech, then reads [text] aloud.
  /// Returns only after speaking finishes (or times out).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    _isSpeaking = true;
    try {
      await TtsPlatform.speak(text);
    } catch (e) {
      debugPrint('WebTtsService error: $e');
    } finally {
      _isSpeaking = false;
    }
  }

  /// Immediately stops any ongoing speech.
  Future<void> stop() async {
    _isSpeaking = false;
    await TtsPlatform.stop();
  }
}