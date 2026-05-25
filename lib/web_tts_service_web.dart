import 'dart:async';
import 'package:web/web.dart' as web;

/// Web implementation — calls window.speechSynthesis directly.
/// Uses a duration-based wait instead of JS event callbacks to avoid
/// dart:js_interop version compatibility issues across Flutter builds.
class TtsPlatform {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Warm up the voice list. Browsers load voices lazily; calling getVoices()
    // now ensures they are ready before the first speak() call.
    web.window.speechSynthesis.getVoices();
    await Future.delayed(const Duration(milliseconds: 600));
    web.window.speechSynthesis.getVoices(); // second call needed by some browsers
  }

  static Future<void> speak(String text) async {
    // Cancel anything already playing
    web.window.speechSynthesis.cancel();
    await Future.delayed(const Duration(milliseconds: 100));

    final utterance = web.SpeechSynthesisUtterance(text);
    utterance.lang = 'en-US';
    utterance.rate = 0.85;   // clear, natural pace for students
    utterance.pitch = 1.0;
    utterance.volume = 1.0;

    web.window.speechSynthesis.speak(utterance);

    // Wait for speech to finish.
    // At rate 0.85 ~= 2.5 words/second, plus a 1.5s trailing buffer.
    final wordCount = text.trim().split(RegExp(r'\s+')).length;
    final durationMs = ((wordCount / 2.5) * 1000 + 1500).toInt();
    await Future.delayed(Duration(milliseconds: durationMs));
  }

  static Future<void> stop() async {
    web.window.speechSynthesis.cancel();
  }
}