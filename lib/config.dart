import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AppConfig {
  static String? _host;
  static const int _battlePort = 8001;
  static const String _fallbackIp = 'localhost';

  static String get baseUrl {
    // Guard: crash early if accessed before init() completes
    assert(_host != null, 'AppConfig.init() must be awaited before accessing baseUrl');
    return 'http://$_host';
  }

  static String get wsBaseUrl {
    assert(_host != null, 'AppConfig.init() must be awaited before accessing wsBaseUrl');
    return 'ws://$_host:$_battlePort';
  }

  static String? get currentHost => _host;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      _host = html.window.location.hostname;
      // Always overwrite — never trust cached IP on web
      await prefs.setString('server_host', _host!);
      debugPrint('🌐 Web mode — host: $_host');
      return;
    }

    // Mobile: use saved IP, fall back to env var, then fallback constant
    final saved = prefs.getString('server_host');
    final envIp = const String.fromEnvironment('SERVER_IP');
    _host = saved ?? (envIp.isNotEmpty ? envIp : _fallbackIp);

    debugPrint('📱 Mobile mode');
    debugPrint('   host    : $_host');
    debugPrint('   baseUrl : $baseUrl');
  }

  /// Call this from a settings screen when the user manually enters a new IP
  static Future<void> updateHost(String newHost) async {
    final prefs = await SharedPreferences.getInstance();
    _host = newHost;
    await prefs.setString('server_host', newHost);
    debugPrint('🔄 Host updated to: $_host');
  }

  static Future<void> refresh() async => await init();
}