import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'login.dart';
import 'edit_profile.dart';
import 'player_badges.dart';
import 'whiz_battle.dart';
import 'whiz_challenge.dart';
import 'whiz_puzzle.dart';
import 'whiz_memory_match.dart';
import 'leaderboard.dart';
import 'config.dart';
import 'tutorial_overlay.dart';
import 'loading_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';
import 'session_manager.dart';
import 'whiz_battle.dart';

// ✅ USER PROFILE MODEL
class UserProfile {
  String id;
  String username;
  String school;
  String age;
  String category;
  String? studentCategory;
  String sex;
  String region;
  String province;
  String city;
  String avatar;
  int stars;

  UserProfile({
    required this.id,
    required this.username,
    required this.school,
    required this.age,
    required this.category,
    this.studentCategory,
    required this.sex,
    required this.region,
    required this.province,
    required this.city,
    required this.avatar,
    this.stars = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var idValue = json['id'] ?? json['_id'] ?? '';
    if (idValue is Map && idValue.containsKey('\$oid')) {
      idValue = idValue['\$oid'];
    }

    return UserProfile(
      id: idValue.toString(),
      username: json['username'] ?? '',
      school: json['school'] ?? '',
      age: json['age']?.toString() ?? '',
      category: json['category'] ?? '',
      studentCategory: json['student_category'],
      sex: json['sex'] ?? '',
      region: json['region']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      avatar: json['avatar'] ?? "assets/images-avatars/Adventurer.png",
      stars: json['stars'] ?? 0,
    );
  }

  UserProfile copyWith({
    String? username,
    String? school,
    String? age,
    String? category,
    String? studentCategory,
    String? sex,
    String? region,
    String? province,
    String? city,
    String? avatar,
    int? stars,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      school: school ?? this.school,
      age: age ?? this.age,
      category: category ?? this.category,
      studentCategory: studentCategory ?? this.studentCategory,
      sex: sex ?? this.sex,
      region: region ?? this.region,
      province: province ?? this.province,
      city: city ?? this.city,
      avatar: avatar ?? this.avatar,
      stars: stars ?? this.stars,
    );
  }
}

// ✅ HOME PAGE
class HomePage extends StatefulWidget {
  final UserProfile profile;
  final String initialTab;
  final bool isNewUser;

  const HomePage({
    super.key,
    required this.profile,
    this.initialTab = "Home",
    this.isNewUser = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final GlobalKey _profileCardKey = GlobalKey();
  final GlobalKey _memoryMatchKey = GlobalKey();
  final GlobalKey _whizChallengeKey = GlobalKey();
  final GlobalKey _whizBattleKey = GlobalKey();
  final GlobalKey _whizPuzzleKey = GlobalKey();
  final GlobalKey _profileAvatarKey = GlobalKey();
  final GlobalKey _starCountKey = GlobalKey();
  final GlobalKey _badgesButtonKey = GlobalKey();
  final GlobalKey _leaderboardKey = GlobalKey();

  late UserProfile _currentProfile;
  late String _selectedTab;
  bool _loadingProfile = true;
  bool _showStarTooltip = false;
  bool _showTutorial = false;

  late AnimationController _flashController;
  bool _isFlashing = false;
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _selectedTab = widget.initialTab;

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _audioService.playHomepageMusic(fadeIn: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserWithLocationNames().then((_) {
        if (mounted) {
          SessionManager.saveSession(_currentProfile);
          _checkAndShowTutorial();
        }
      });
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  Future<void> _checkAndShowTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tutorialCompleted =
          prefs.getBool('main_tutorial_completed_${_currentProfile.id}') ?? false;
      if (tutorialCompleted) return;
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) setState(() => _showTutorial = true);
      }
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
    }
  }

  Future<void> _loadUserWithLocationNames({bool loadLocationData = true}) async {
    setState(() => _loadingProfile = true);
    try {
      final res = await http.get(Uri.parse("${AppConfig.baseUrl}/homepage/${_currentProfile.id}"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true) {
          final user = data['user'];
          if (mounted) {
            setState(() {
              if (loadLocationData) {
                _currentProfile = _currentProfile.copyWith(
                  region: user['region'] ?? '',
                  province: user['province'] ?? '',
                  city: user['city'] ?? '',
                  stars: user['stars'] ?? 0,
                  category: user['category'] ?? _currentProfile.category,
                  studentCategory: user['student_category'],
                );
              } else {
                _currentProfile = _currentProfile.copyWith(stars: user['stars'] ?? 0);
              }
              _loadingProfile = false;
            });
          }
        }
      } else {
        if (mounted) setState(() => _loadingProfile = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _updateStarsOnly() async {
    try {
      final res = await http.get(
        Uri.parse("${AppConfig.baseUrl}/players/${_currentProfile.id}/stars"),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _currentProfile = _currentProfile.copyWith(
              stars: data['data']?['total_stars'] ?? _currentProfile.stars,
            );
          });
          await SessionManager.saveSession(_currentProfile);
        }
      }
    } catch (e) {
      debugPrint('Error updating stars: $e');
    }
  }

  String get cityName =>
      _currentProfile.city.isNotEmpty ? _currentProfile.city : "Unknown City";

  Future<void> _logout() async {
    try {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LoadingPage()),
        );
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await SessionManager.clearSession();
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (key.startsWith('main_tutorial_completed_') ||
            key.startsWith('game_tutorial_completed_') ||
            key.startsWith('session_')) {
          continue;
        }
        await prefs.remove(key);
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error logging out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final updatedProfile = await showDialog<UserProfile>(
      context: context,
      builder: (_) => EditProfileDialog(profile: _currentProfile),
    );
    if (updatedProfile != null && mounted) {
      setState(() => _currentProfile = updatedProfile);
      await _loadUserWithLocationNames(loadLocationData: true);
    }
  }

  Future<void> _showRatingDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _RatingDialog(
          userId: _currentProfile.id,
          baseUrl: AppConfig.baseUrl,
          onRatingSubmitted: _markUserAsRated,
        );
      },
    );
  }

  void _showSettingsDialog() {
    final isNarrow = _isNarrow(context);
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(
        userId: _currentProfile.id,
        baseUrl: AppConfig.baseUrl,
        onLogout: _logout,
        onEditProfile: _editProfile,
        showLeaderboardButton: isNarrow,
        leaderboardKey: isNarrow ? _leaderboardKey : null,
        onLeaderboard: () {
          setState(() => _selectedTab = "Leaderboard");
        },
      ),
    );
  }

  // ── Responsive helper ───────────────────────────────────────────────────
  bool _isNarrow(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.height >= size.width;
  }

  Widget _buildTopNavButton(String label, IconData icon) {
    final isActive = _selectedTab == label;
    return InkWell(
      onTap: () async {
        try {
          await _audioService.playClickSound();
        } catch (_) {}
        setState(() => _selectedTab = label);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: isActive ? const Color(0xFFFFD13B) : Colors.grey[700],
                size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: isActive ? const Color(0xFFFFD13B) : Colors.black,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                )),
          ]),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isActive ? (label == 'Home' ? 60 : 120) : 0,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFFFD13B) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerFlashAndNavigate(Widget page) async {
    if (_isFlashing) return;
    setState(() => _isFlashing = true);

    await _flashController.forward();

    if (mounted) {
      LoadingHelper.showLoadingPage(context, message: 'Loading game...');
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        LoadingHelper.hideLoading(context);
        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          await Navigator.push(
            context,
            PageRouteBuilder(
              opaque: true,
              barrierColor: const Color(0xFF87CEEB),
              pageBuilder: (_, _, _) => page,
              transitionDuration: const Duration(milliseconds: 600),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );

          if (mounted) {
            _updateStarsOnly();
            _incrementGameCounterAndCheckRating();
          }
        }
      }
    }

    if (mounted) {
      await _flashController.reverse();
      setState(() => _isFlashing = false);
    }
  }

  Color _getStarColor() {
    if (_currentProfile.stars >= 1000) return const Color(0xFFB9F2FF);
    if (_currentProfile.stars >= 500) return const Color(0xFFE5E4E2);
    if (_currentProfile.stars >= 250) return const Color(0xFFFFD700);
    if (_currentProfile.stars >= 100) return const Color(0xFFC0C0C0);
    if (_currentProfile.stars >= 50) return const Color(0xFFCD7F32);
    return Colors.white;
  }

  Future<void> _incrementGameCounterAndCheckRating() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = 'games_played_${_currentProfile.id}';
      final hasRatedKey = 'has_rated_${_currentProfile.id}';
      final lastPromptKey = 'last_rating_prompt_${_currentProfile.id}';
      final gamesPlayed = (prefs.getInt(userKey) ?? 0) + 1;
      final hasRated = prefs.getBool(hasRatedKey) ?? false;
      final lastPromptTime = prefs.getInt(lastPromptKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const dayInMs = 86400000;
      await prefs.setInt(userKey, gamesPlayed);
      final shouldPrompt = !hasRated &&
          (now - lastPromptTime) > (dayInMs * 3) &&
          (gamesPlayed == 5 || gamesPlayed == 15 || gamesPlayed == 30);
      if (shouldPrompt && mounted) {
        await prefs.setInt(lastPromptKey, now);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _showRatingDialog();
      }
    } catch (e) {
      debugPrint('Error checking rating prompt: $e');
    }
  }

  Future<void> _markUserAsRated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_rated_${_currentProfile.id}', true);
    } catch (e) {
      debugPrint('Error marking user as rated: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainContent = _selectedTab == "Leaderboard"
        ? Leaderboard(
            currentUserId: _currentProfile.id,
            userAvatar: _currentProfile.avatar,
            username: _currentProfile.username,
          )
        : _buildHomeContent();

    return Stack(
      children: [
        Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF046EB8),
              body: _loadingProfile
                  ? const LoadingPage(message: 'Loading your profile...')
                  : Column(children: [
                      _buildTopBar(),
                      Expanded(child: mainContent),
                    ]),
            ),
            AnimatedBuilder(
              animation: _flashController,
              builder: (context, child) {
                return IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: _flashController.value,
                    child: Container(color: const Color(0xFF87CEEB)),
                  ),
                );
              },
            ),
          ],
        ),
        if (_showTutorial)
          TutorialOverlay(
            userId: _currentProfile.id,
            onComplete: () async {
              if (mounted) setState(() => _showTutorial = false);
            },
            elementKeys: {
              'profile_avatar': _profileAvatarKey,
              'star_count': _starCountKey,
              'badges_button': _badgesButtonKey,
              'memory_match': _memoryMatchKey,
              'whiz_challenge': _whizChallengeKey,
              'whiz_battle': _whizBattleKey,
              'whiz_puzzle': _whizPuzzleKey,
              'leaderboard': _leaderboardKey,
            },
            onStepActivate: (step) {
              // On mobile (narrow/portrait) the Leaderboard nav tab is hidden.
              // Auto-open the Settings dialog so its Leaderboard button —
              // which carries _leaderboardKey — is rendered and highlightable.
              if (step.highlightKey == 'leaderboard' && _isNarrow(context)) {
                _showSettingsDialog();
              }
            },
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    final isNarrow = _isNarrow(context);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Image.asset("assets/images-logo/newhomepagelogo.png",
              width: 130, height: 46, fit: BoxFit.contain),
          // On narrow/mobile screens, hide the nav tabs (they move into the settings dialog)
          if (!isNarrow)
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _buildTopNavButton("Home", Icons.home),
                  const SizedBox(width: 28),
                  Container(
                    key: _leaderboardKey,
                    child: _buildTopNavButton("Leaderboard", Icons.leaderboard),
                  ),
                ]),
              ),
            )
          else if (isNarrow && _selectedTab == "Leaderboard")
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF046EB8)),
              tooltip: 'Back to Home',
              onPressed: () => setState(() => _selectedTab = "Home"),
            )
          else
            const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showSettingsDialog,
              child: Container(
                key: _profileAvatarKey,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF046EB8), width: 3)),
                child: ClipOval(
                    child: Image.asset(_currentProfile.avatar, fit: BoxFit.cover)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width so it doesn't stretch too wide on large screens
    final cardWidth = min(screenWidth - 40, 700.0);

    return Container(
      key: _profileCardKey,
      width: cardWidth,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF4A90BE),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFFFD700), width: 3),
            ),
            child: ClipOval(
              child: Image.asset(_currentProfile.avatar, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _currentProfile.username,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await _audioService.playClickSound();
                          } catch (_) {}
                          _editProfile();
                        },
                        child: const Icon(Icons.edit,
                            size: 13, color: Color(0xFF046EB8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_currentProfile.category,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text("$cityName, ${_currentProfile.region}",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stars
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _showStarTooltip = true),
            onExit: (_) => setState(() => _showStarTooltip = false),
            child: Stack(
              key: _starCountKey,
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: _getStarColor(), size: 22),
                    const SizedBox(width: 4),
                    Text('${_currentProfile.stars}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                if (_showStarTooltip)
                  Positioned(
                    left: -20,
                    top: -70,
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: Colors.black87,
                              height: 1.4),
                          children: [
                            TextSpan(text: 'Your total stars! Earn more by completing '),
                            TextSpan(
                                text: 'Memory Match',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF656BE6))),
                            TextSpan(text: ' and '),
                            TextSpan(
                                text: 'Puzzle',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE6833A))),
                            TextSpan(text: ' games quickly.'),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Badges button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                try {
                  await _audioService.playClickSound();
                } catch (_) {}
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (_) =>
                      PlayerBadgesDialog(playerId: _currentProfile.id, baseUrl: AppConfig.baseUrl),
                );
              },
              child: Container(
                key: _badgesButtonKey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDD000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDD000), width: 2),
                ),
                child: const Text(
                  'Badges',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB8860B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isPortrait = screenHeight >= screenWidth;

    // Landscape: single row of 4; Portrait: 2x2 grid
    final crossAxisCount = isPortrait ? 2 : 4;

    // Landscape/web: cards fill most of the screen width, big and bold
    final maxGridWidth = isPortrait ? 500.0 : min(screenWidth - 40, 1280.0);

    // Lower ratio = taller/bigger cards
    final childAspect = isPortrait ? 0.72 : 0.68;
    final hPad = isPortrait ? 16.0 : 20.0;
    final crossSpacing = isPortrait ? 14.0 : 16.0;
    final mainSpacing = isPortrait ? 14.0 : 16.0;

    final gameGrid = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxGridWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 0),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: crossSpacing,
            mainAxisSpacing: mainSpacing,
            childAspectRatio: childAspect,
            children: [
              _GameBox(
                key: _memoryMatchKey,
                title: "Whiz Memory Match",
                imagePath: "assets/images-gamecards/whizmemorymatch.png",
                backgroundColor: const Color(0xFF656BE6),
                onTapNavigate: () => _triggerFlashAndNavigate(
                  WhizMemoryMatch(
                    userAvatar: _currentProfile.avatar,
                    playerId: _currentProfile.id,
                    username: _currentProfile.username,
                  ),
                ),
              ),
              _GameBox(
                key: _whizChallengeKey,
                title: "Whiz Challenge",
                imagePath: "assets/images-gamecards/whizchallenge.png",
                backgroundColor: const Color(0xFFFDD000),
                onTapNavigate: () => _triggerFlashAndNavigate(
                  WhizChallenge(
                    userAvatar: _currentProfile.avatar,
                    userId: _currentProfile.id,
                    username: _currentProfile.username,
                  ),
                ),
              ),
              _GameBox(
                key: _whizBattleKey,
                title: "Whiz Battle",
                imagePath: "assets/images-gamecards/whizbattle.png",
                backgroundColor: const Color(0xFFC571E2),
                onTapNavigate: () => _triggerFlashAndNavigate(
                  WhizBattle(
                    userAvatar: _currentProfile.avatar,
                    userId: _currentProfile.id,
                    username: _currentProfile.username,
                  ),
                ),
              ),
              _GameBox(
                key: _whizPuzzleKey,
                title: "Whiz Puzzle",
                imagePath: "assets/images-gamecards/whizpuzzle.png",
                backgroundColor: const Color(0xFFE6833A),
                onTapNavigate: () => _triggerFlashAndNavigate(
                  WhizPuzzle(
                    userAvatar: _currentProfile.avatar,
                    playerId: _currentProfile.id,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Use LayoutBuilder so we know exactly how tall the available area is,
    // then vertically center the profile card + game grid inside it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;

        final inner = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileCard(),
            SizedBox(height: isPortrait ? 14 : 56),
            gameGrid,
          ],
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Align(
              alignment: const Alignment(0, -0.35),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isPortrait ? 12 : 0),
                child: inner,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ✅ GameBox widget (unchanged logic, just responsive sizing)
class _GameBox extends StatefulWidget {
  final String title;
  final String imagePath;
  final Color backgroundColor;
  final VoidCallback onTapNavigate;

  const _GameBox({
    super.key,
    required this.title,
    required this.imagePath,
    required this.backgroundColor,
    required this.onTapNavigate,
  });

  @override
  State<_GameBox> createState() => _GameBoxState();
}

class _GameBoxState extends State<_GameBox> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _floatController;
  late AnimationController _fadeOutController;
  late AnimationController _bounceController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _liftAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _bounceAnimation;

  bool _hovering = false;
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _floatController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2));
    _fadeOutController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _bounceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
        CurvedAnimation(parent: _hoverController, curve: Curves.easeOutBack));
    _liftAnimation = Tween<double>(begin: 0, end: -40).animate(
        CurvedAnimation(parent: _hoverController, curve: Curves.easeOutBack));
    _shadowAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
        CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _hoverController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn));
    _bounceAnimation = Tween<double>(begin: 0, end: 10).animate(
        CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _floatController.dispose();
    _fadeOutController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent details) {
    setState(() => _hovering = true);
    _bounceController.reset();
    _hoverController.forward();
    _floatController.repeat(reverse: true);
  }

  Future<void> _onExit(PointerEvent details) async {
    setState(() => _hovering = false);
    _floatController.stop();
    _floatController.reset();
    await _hoverController.reverse();
    _bounceController.forward();
    await Future.delayed(const Duration(milliseconds: 120));
    _bounceController.reverse();
  }

  Future<void> _onTap() async {
    try {
      await _audioService.playClickSound();
    } catch (_) {}

    _floatController.stop();
    setState(() => _hovering = false);

    _hoverController.duration = const Duration(milliseconds: 150);
    await _hoverController.reverse();
    await _fadeOutController.forward();

    widget.onTapNavigate();

    if (mounted) {
      _fadeOutController.reset();
      _hoverController.duration = const Duration(milliseconds: 800);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait = size.height >= size.width;
    // Portrait (2-col): fill width of grid cell; Landscape (4-col): fill width too
    // Both use double.infinity so the GridView cell dictates the size
    const titleSize = 15.0;

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _hoverController,
            _floatController,
            _fadeOutController,
            _bounceController
          ]),
          builder: (context, child) {
            final floatOffset =
                _hovering ? sin(_floatController.value * 2 * pi) * 6 : 0;
            final totalOffset =
                _liftAnimation.value + floatOffset + _bounceAnimation.value;

            return Opacity(
              opacity: _fadeAnimation.value,
              // Wrap in Padding to give shadow room so it is never clipped
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 10),
                child: Transform.translate(
                  offset: Offset(0, totalOffset),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (_hovering)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.yellow.withValues(
                                    alpha: 0.4 * _glowAnimation.value),
                                blurRadius: 40,
                                spreadRadius: 15,
                              ),
                            ],
                          ),
                        ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(
                              _hovering ? _rotationAnimation.value : 0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: 0.30),
                                blurRadius: 18,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: widget.backgroundColor
                                    .withValues(alpha: 0.45),
                                blurRadius: 14,
                                spreadRadius: 0,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                  child: Image.asset(
                                    widget.imagePath,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(
                                    vertical: isPortrait ? 14 : 10),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: widget.backgroundColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ✅ Settings Dialog (unchanged from original)
class _SettingsDialog extends StatefulWidget {
  final String userId;
  final String baseUrl;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final bool showLeaderboardButton;
  final VoidCallback? onLeaderboard;
  /// When provided, this key is assigned to the Leaderboard button so the
  /// tutorial overlay can highlight it on mobile.
  final GlobalKey? leaderboardKey;

  const _SettingsDialog({
    required this.userId,
    required this.baseUrl,
    required this.onLogout,
    required this.onEditProfile,
    this.showLeaderboardButton = false,
    this.onLeaderboard,
    this.leaderboardKey,
  });

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  double _volumeLevel = 50;
  double _sfxLevel = 50;
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _volumeLevel = prefs.getDouble('music_volume_${widget.userId}') ?? 50.0;
      _sfxLevel = prefs.getDouble('sfx_volume_${widget.userId}') ?? 50.0;
    });
    await _audioService.setMusicVolume(_volumeLevel / 100.0);
    await _audioService.setSfxVolume(_sfxLevel / 100.0);
    bool shouldEnableMusic = _volumeLevel > 0;
    if (!shouldEnableMusic && _audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    } else if (shouldEnableMusic && !_audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume_${widget.userId}', _volumeLevel);
    await prefs.setDouble('sfx_volume_${widget.userId}', _sfxLevel);
  }

  void _onVolumeChanged(double value) {
    setState(() => _volumeLevel = value);
    _audioService.setMusicVolume(value / 100.0);
    if (value == 0 && _audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    } else if (value > 0 && !_audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    }
    _saveSettings();
  }

  void _onSfxVolumeChanged(double value) {
    setState(() => _sfxLevel = value);
    _audioService.setSfxVolume(value / 100.0);
    _saveSettings();
  }

  Future<void> _handleRateGame() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool('has_rated_${widget.userId}') ?? false;
    if (!hasRated && mounted) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _RatingDialog(
          userId: widget.userId,
          baseUrl: widget.baseUrl,
          onRatingSubmitted: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_rated_${widget.userId}', true);
          },
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already rated this game. Thank you!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset("assets/images-icons/sadlogout.png",
                  width: 80, height: 80),
              const SizedBox(height: 15),
              const Text("Logout Confirmation",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              const SizedBox(height: 10),
              const Text("Are you sure you want to log out?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
              const SizedBox(height: 25),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("No",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Color(0xFF046EB8))),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDD000),
                      foregroundColor: const Color(0xFF816A03),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Yes",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ])
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    debugPrint('✅ Logging out');
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: _buildSettingsContent(),
    );
  }

  Widget _buildSettingsContent() {
    return Container(
      key: const ValueKey('settings'),
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [
              Icon(Icons.settings, color: Color(0xFF046EB8), size: 28),
              SizedBox(width: 12),
              Text('Settings',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8))),
            ]),
            IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF046EB8)),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 24),
          const Row(children: [
            Icon(Icons.music_note, color: Color(0xFF046EB8), size: 20),
            SizedBox(width: 8),
            Text('Music Volume',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Slider(
                value: _volumeLevel,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFF046EB8),
                inactiveColor: Colors.grey[300],
                onChanged: _onVolumeChanged,
              ),
            ),
            SizedBox(
              width: 35,
              child: Text('${_volumeLevel.round()}',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 16),
          const Row(children: [
            Icon(Icons.graphic_eq, color: Color(0xFF046EB8), size: 20),
            SizedBox(width: 8),
            Text('Sound Effects Volume',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Slider(
                value: _sfxLevel,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFF046EB8),
                inactiveColor: Colors.grey[300],
                onChanged: _onSfxVolumeChanged,
              ),
            ),
            SizedBox(
              width: 35,
              child: Text('${_sfxLevel.round()}',
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ]),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // On mobile/portrait, show Leaderboard button here since the top nav is hidden
          if (widget.showLeaderboardButton) ...[
            SizedBox(
              key: widget.leaderboardKey,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onLeaderboard?.call();
                },
                icon: const Icon(Icons.leaderboard, size: 20),
                label: const Text('Leaderboard',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF046EB8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleRateGame,
              icon: const Icon(Icons.star_rounded, size: 20),
              label: const Text('Rate Game',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDD000),
                foregroundColor: const Color(0xFF816A03),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEditProfile();
              },
              icon: const Icon(Icons.edit, size: 20),
              label: const Text('Edit Profile',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF046EB8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Logout',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF046EB8),
                side: const BorderSide(color: Color(0xFF046EB8), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Rating Dialog (unchanged)
class _RatingDialog extends StatefulWidget {
  final String userId;
  final String baseUrl;
  final VoidCallback? onRatingSubmitted;

  const _RatingDialog({
    required this.userId,
    required this.baseUrl,
    this.onRatingSubmitted,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  String _feedback = '';
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a rating')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rating_${widget.userId}', _rating);
      await prefs.setString('feedback_${widget.userId}', _feedback);
      await prefs.setString('rating_timestamp_${widget.userId}',
          DateTime.now().toIso8601String());
      if (mounted) {
        widget.onRatingSubmitted?.call();
        Navigator.pop(context, true);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Thank you for your rating!'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving rating: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded,
                color: Color(0xFFFDD000), size: 60),
            const SizedBox(height: 16),
            const Text('Rate Our Game!',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF046EB8))),
            const SizedBox(height: 8),
            const Text('Your feedback helps us improve',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFDD000),
                        size: 40),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Poppins'),
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts (optional)',
                  hintStyle: TextStyle(fontFamily: 'Poppins'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (value) => _feedback = value,
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context, false),
                  child: const Text('Later',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDD000),
                    foregroundColor: const Color(0xFF816A03),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF816A03))))
                      : const Text('Submit',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}