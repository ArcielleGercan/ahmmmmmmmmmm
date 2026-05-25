import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'register.dart';
import 'homepage.dart';
import 'admin_login.dart';
import 'loading_page.dart';
import 'audio_service.dart';
import 'session_manager.dart';
import 'config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _obscurePassword = true;
  bool usernameError = false;
  bool passwordError = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AudioService _audioService = AudioService();

  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScale;

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _audioService.playHomepageMusic();

    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
          parent: _buttonScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _buttonScaleController.dispose();
    super.dispose();
  }

  void _playClickSound() async {
    await _audioService.playClickSound();
  }

  InputDecoration _inputDecoration(String label, IconData icon,
      {bool hasError = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          color: hasError ? Colors.red : null),
      prefixIcon: Icon(icon, size: 18, color: hasError ? Colors.red : null),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
            color: hasError ? Colors.red : const Color(0xFF046EB8),
            width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
            color: hasError ? Colors.red : Colors.grey,
            width: hasError ? 2 : 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
            color: hasError ? Colors.red : const Color(0xFF046EB8),
            width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
  }

  void _goToRegister() {
    _playClickSound();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  Future<void> _login() async {
    _playClickSound();
    await _buttonScaleController.forward();
    await _buttonScaleController.reverse();

    setState(() {
      usernameError = false;
      passwordError = false;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty && password.isNotEmpty) {
      if (!mounted) return;
      setState(() => usernameError = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Username is required'),
          backgroundColor: Colors.red));
      return;
    }
    if (password.isEmpty && username.isNotEmpty) {
      if (!mounted) return;
      setState(() => passwordError = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password is required'),
          backgroundColor: Colors.red));
      return;
    }
    if (username.isEmpty && password.isEmpty) {
      if (!mounted) return;
      setState(() {
        usernameError = true;
        passwordError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all required fields'),
          backgroundColor: Colors.red));
      return;
    }
    if (username.length < 3) {
      if (!mounted) return;
      setState(() => usernameError = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Username must be at least 3 characters'),
          backgroundColor: Colors.red));
      return;
    }

    if (!mounted) return;
    LoadingHelper.showLoadingPage(context, message: 'Logging in...');

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(
            {'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);
      if (mounted) LoadingHelper.hideLoading(context);
      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final userId = data['user']['id']?.toString() ??
            data['user']['_id']?.toString() ??
            '';
        final prefs = await SharedPreferences.getInstance();
        final tutorialCompletedKey =
            'main_tutorial_completed_$userId';
        final bool tutorialAlreadyCompleted =
            prefs.getBool(tutorialCompletedKey) ?? false;
        final bool isFirstLogin = !tutorialAlreadyCompleted;

        if (!mounted) return;

        final profile = UserProfile(
          id: userId,
          username: data['user']['username'],
          school: data['user']['school'] ?? 'Unknown School',
          age: data['user']['age']?.toString() ?? 'N/A',
          category: data['user']['category'] ?? 'Student',
          sex: data['user']['sex'] ?? 'N/A',
          region: data['user']['region']?.toString() ?? '',
          province: data['user']['province']?.toString() ?? '',
          city: data['user']['city']?.toString() ?? '',
          avatar: data['user']['avatar'] ?? 'default',
        );

        await SessionManager.saveSession(profile);
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomePage(profile: profile, isNewUser: isFirstLogin),
          ),
        );
      } else {
        if (!mounted) return;
        setState(() {
          usernameError = true;
          passwordError = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(data['message'] ?? 'Invalid username or password.'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) LoadingHelper.hideLoading(context);
      if (!mounted) return;
      setState(() {
        usernameError = true;
        passwordError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error connecting to server: $e'),
          backgroundColor: Colors.red));
    }
  }


  // ── Error indicator widget ────────────────────────────────────────────────
  Widget _buildErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // 90% of original form width
    final formWidth = _isMobile
        ? screenWidth * 0.79
        : (screenWidth * 0.38).clamp(306.0, 414.0);

    return AnimatedBuilder(
      animation: _buttonScaleController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF94D2FD),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            toolbarHeight: 48,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset("assets/images-logo/newhomepagelogo.png",
                    height: 38, filterQuality: FilterQuality.high),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () {
                      _playClickSound();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AdminLoginPage()),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            color: const Color(0xFF046EB8),
                            size: _isMobile ? 20 : 16),
                        const SizedBox(width: 4),
                        Text("ADMIN",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: _isMobile ? 15 : 12,
                                color: const Color(0xFF046EB8))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  "assets/images-icons/background1.png",
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo — 90% of original clamp range
                      Image.asset(
                        "assets/images-logo/newloginlogo.png",
                        height: (screenHeight * 0.20).clamp(117.0, 216.0),
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      const SizedBox(height: 14),

                      // Login card
                      Container(
                        width: formWidth,
                        padding: EdgeInsets.all(_isMobile ? 18 : 25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Log In",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: _isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF046EB8))),
                            SizedBox(height: _isMobile ? 14 : 18),

                            // Username field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _usernameController,
                                  onSubmitted: (_) => _login(),
                                  style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 12),
                                  decoration: _inputDecoration(
                                      "Username", Icons.person,
                                      hasError: usernameError),
                                ),
                                if (usernameError) _buildErrorMessage('Required'),
                              ],
                            ),

                            SizedBox(height: _isMobile ? 10 : 13),

                            // Password field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _passwordController,
                                  onSubmitted: (_) => _login(),
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins', fontSize: 12),
                                  decoration: _inputDecoration(
                                          "Password", Icons.lock,
                                          hasError: passwordError)
                                      .copyWith(
                                    suffixIcon: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 18,
                                          color: passwordError
                                              ? Colors.red
                                              : null,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                  ),
                                ),
                                if (passwordError) _buildErrorMessage('Required'),
                              ],
                            ),

                            SizedBox(height: _isMobile ? 20 : 26),

                            Transform.scale(
                              scale: _buttonScale.value,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFFDD000),
                                      foregroundColor:
                                          const Color(0xFF816A03),
                                      padding: EdgeInsets.symmetric(
                                          vertical:
                                              _isMobile ? 11 : 13),
                                      textStyle: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontWeight: FontWeight.w700,
                                          fontSize:
                                              _isMobile ? 13 : 14),
                                    ),
                                    child: const Text("LOG IN"),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 11),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Text("No account yet? ",
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11)),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: InkWell(
                                    onTap: _goToRegister,
                                    child: const Text("Register here",
                                        style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: Colors.blue,
                                            decoration: TextDecoration
                                                .underline)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}