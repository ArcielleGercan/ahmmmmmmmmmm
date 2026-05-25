import 'dart:async';

/// Non-web stub — does nothing.
/// Flutter on Android/iOS uses this so the app still compiles.
class TtsPlatform {
  static Future<void> init() async {}
  static Future<void> speak(String text) async {}
  static Future<void> stop() async {}
}