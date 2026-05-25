import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'audio_service.dart';
import 'session_manager.dart';
import 'homepage.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.init(); // host is set before anything else runs

  try {
    await AudioService().initialize();
  } catch (e) {
    debugPrint('AudioService init error: $e');
  }

  UserProfile? savedProfile;
  try {
    savedProfile = await SessionManager.restoreSession();
  } catch (e) {
    debugPrint('SessionManager restore error: $e');
    savedProfile = null;
  }

  debugPrint('Restored profile: $savedProfile');

  runApp(MyApp(initialProfile: savedProfile));
}

class MyApp extends StatelessWidget {
  final UserProfile? initialProfile;

  const MyApp({super.key, this.initialProfile});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        textTheme: const TextTheme().apply(
          fontSizeFactor: 1.0,
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
      home: initialProfile != null
          ? HomePage(profile: initialProfile!)
          : const SplashScreen(),
    );
  }
}