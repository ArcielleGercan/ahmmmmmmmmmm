import 'package:flutter/material.dart';
import 'quiz_game.dart';
import 'difficulty_settings_service.dart';
import 'audio_service.dart';  // Use AudioService instead of flame_audio
import 'game_tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loading_page.dart';
import 'login.dart';
import 'config.dart';

class WhizChallenge extends StatefulWidget {
  final String userId;
  final String userAvatar;
  final String username;
  final String? preselectedDifficulty;
  final String? preselectedCategory;

  const WhizChallenge({
    super.key,
    required this.userId,
    required this.userAvatar,
    required this.username,
    this.preselectedDifficulty,
    this.preselectedCategory,
  });

  @override
  State<WhizChallenge> createState() => _WhizChallengeState();
}

class _WhizChallengeState extends State<WhizChallenge> {
  final AudioService _audioService = AudioService();
  String selectedDifficulty = 'Easy';
  String? selectedMainCategory;

  // Tutorial state
  bool _showGameTutorial = false;
  bool _checkingTutorialStatus = true;

  // Difficulty options
  final List<Map<String, String>> difficultyLevels = [
    {'value': 'Easy', 'display': 'Easy'},
    {'value': 'Average', 'display': 'Average'},
    {'value': 'Difficult', 'display': 'Difficult'},
  ];

  final Map<String, List<String>> mathSubcategories = {
    'Easy': [
      'Addition & Subtraction',
      'Multiplication',
      'Division',
      'Counting & Numbers',
      'Basic Shapes',
      'Comparing Numbers',
      'Number Patterns',
      'Telling Time',
    ],
    'Average': [
      'Fractions & Decimals',
      'Algebra Basics',
      'Geometry',
      'Ratios & Proportions',
      'Percentages',
      'Area & Perimeter',
      'Integers',
      'Word Problems',
    ],
    'Difficult': [
      'Calculus',
      'Statistics & Probability',
      'Advanced Algebra',
      'Trigonometry',
      'Linear Equations',
      'Polynomials',
      'Logarithms',
      'Matrices',
    ],
  };

  final Map<String, List<String>> scienceSubcategories = {
    'Easy': [
      'Plants & Animals',
      'Human Body',
      'Weather & Seasons',
      'Day & Night',
      'Rocks & Soil',
      'Food Chains',
      'Simple Machines',
      'Senses',
    ],
    'Average': [
      'Ecosystems',
      'Cells & Organisms',
      'Matter & States',
      'Forces & Motion',
      'Solar System',
      'Energy Types',
      'Water Cycle',
      'Photosynthesis',
    ],
    'Difficult': [
      'Molecular Biology',
      'Advanced Chemistry',
      'Quantum Physics',
      'Genetics & DNA',
      'Thermodynamics',
      'Electromagnetism',
      'Chemical Reactions',
      'Atomic Structure',
    ],
  };

  @override
  void initState() {
    super.initState();
    DifficultySettingsService.instance.load();

    if (widget.preselectedDifficulty != null) {
      selectedDifficulty = widget.preselectedDifficulty!;
    }
    if (widget.preselectedCategory != null) {
      selectedMainCategory = widget.preselectedCategory;
    }

    _initializeMusic();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGameTutorialStatus();
    });
  }

  Future<void> _initializeMusic() async {
    try {
      await _audioService.playQuizMusic(fadeIn: true);
    } catch (e) {
      debugPrint('Error initializing music: $e');
    }
  }

  Future<void> _checkGameTutorialStatus() async {
    try {
      final shouldShow = await GameTutorialOverlay.shouldShowTutorial(
        widget.userId,
        'challenge',
      );

      if (shouldShow && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _showGameTutorial = true;
            _checkingTutorialStatus = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _checkingTutorialStatus = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      if (mounted) {
        setState(() {
          _checkingTutorialStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        await _audioService.playClickSound();
        await _audioService.stopMusic();
        await _audioService.playHomepageMusic(fadeIn: true);

        if (!mounted) return;
        Navigator.of(context).pop();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            body: _checkingTutorialStatus
                ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFDD000)),
            )
                : Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _buildSelectionScreen(),
                ),
              ],
            ),
          ),

          if (_showGameTutorial)
            GameTutorialOverlay(
              userId: widget.userId,
              gameType: 'challenge',
              onComplete: () {
                setState(() => _showGameTutorial = false);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Image.asset(
                "assets/images-logo/newhomepagelogo.png",
                width: 150,
                height: 50,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showSettingsDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDD000), width: 3),
                    ),
                    child: ClipOval(
                      child: widget.userAvatar.isNotEmpty
                          ? Image.asset(
                        widget.userAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _AvatarFallback(),
                      )
                          : const _AvatarFallback(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFFDD000),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: () async {
                  try {
                    await _audioService.playClickSound();
                  } catch (e) {
                    debugPrint('Click sound not found: $e');
                  }

                  await _audioService.stopMusic();
                  await _audioService.playHomepageMusic(fadeIn: true);

                  if (!mounted) return;
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Text(
                  "Whiz Challenge",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 28),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionScreen() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DIFFICULTY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDifficultyRow(),
                const SizedBox(height: 28),

                const Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                _buildExpandableCategorySection('Math', Icons.calculate),
                const SizedBox(height: 14),

                _buildExpandableCategorySection('Science', Icons.science),
                const SizedBox(height: 40),

                Center(child: _buildPlayButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _difficultyColor(String value) {
    switch (value) {
      case 'Easy':      return const Color(0xFF1D9358);
      case 'Average':   return const Color(0xFF046EB8);
      case 'Difficult': return const Color(0xFFBD442E);
      default:          return const Color(0xFF1D9358);
    }
  }

  Widget _buildDifficultyRow() {
    return Row(
      children: difficultyLevels.map((difficulty) {
        final isSelected = selectedDifficulty == difficulty['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  try {
                    await _audioService.playClickSound();
                  } catch (e) {
                    debugPrint('Click sound error: $e');
                  }
                  setState(() {
                    selectedDifficulty = difficulty['value']!;
                    selectedMainCategory = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? _difficultyColor(difficulty['value']!) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? _difficultyColor(difficulty['value']!) : Colors.black87,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                      color: _difficultyColor(difficulty['value']!).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )]
                        : [],
                  ),
                  child: Text(
                    difficulty['display']!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpandableCategorySection(String category, IconData icon) {
    final isExpanded = selectedMainCategory?.toLowerCase() == category.toLowerCase();
    final topics = category.toLowerCase() == 'math'
        ? mathSubcategories[selectedDifficulty] ?? []
        : scienceSubcategories[selectedDifficulty] ?? [];
    final diffColor = _difficultyColor(selectedDifficulty);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try {
            await _audioService.playClickSound();
          } catch (e) {
            debugPrint('Click sound error: $e');
          }
          setState(() {
            if (isExpanded) {
              selectedMainCategory = null;
            } else {
              // ✅ FIX: Use Title Case (e.g. "Math") instead of UPPERCASE ("MATH")
              // so it matches the database values and the backend normalization.
              selectedMainCategory = category[0].toUpperCase() + category.substring(1).toLowerCase();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded ? diffColor : Colors.black87,
              width: 2,
            ),
            boxShadow: isExpanded
                ? [
              BoxShadow(
                color: const Color(0xFFFDD000).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  color: isExpanded ? diffColor : Colors.white,
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: isExpanded ? Colors.white : Colors.black87, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isExpanded ? Colors.white : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.remove : Icons.add,
                          color: isExpanded ? Colors.white : Colors.black87,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOPICS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.black45,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: topics.map((topic) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1.5),
                            ),
                            child: Text(
                              topic,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    final isEnabled = selectedMainCategory != null;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isEnabled
            ? () async {
          try {
            await _audioService.playClickSound();
          } catch (e) {
            debugPrint('Click sound error: $e');
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuizScreen(
                userId: widget.userId,
                category: selectedMainCategory!, // Already Title Case e.g. "Math"
                difficulty: selectedDifficulty,
              ),
            ),
          ).then((result) {
            if (result is Map && mounted) {
              setState(() {
                if (result['nextDifficulty'] != null) {
                  selectedDifficulty = result['nextDifficulty'] as String;
                }
                if (result['category'] != null) {
                  // ✅ FIX: Keep Title Case when coming back from quiz result
                  final cat = result['category'] as String;
                  selectedMainCategory = cat[0].toUpperCase() + cat.substring(1).toLowerCase();
                }
              });
            }
          });
        }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          decoration: BoxDecoration(
            gradient: isEnabled
                ? const LinearGradient(
              colors: [Color(0xFFFDD000), Color(0xFFFFC700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isEnabled ? null : Colors.grey[300],
            borderRadius: BorderRadius.circular(30),
            boxShadow: isEnabled
                ? [
              const BoxShadow(
                color: Color(0x40FDD000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Text(
            'PLAY',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isEnabled ? Colors.black87 : Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(
        userId: widget.userId,
        onLogout: _handleLogout,
      ),
    );
  }

  Future<void> _handleLogout() async {
    LoadingHelper.showLoadingPage(context, message: 'Logging out...');
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }
}

// Private fallback widget for when avatar is empty or fails to load
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDD000).withValues(alpha: 0.2),
      child: const Icon(
        Icons.person,
        size: 28,
        color: Color(0xFFFDD000),
      ),
    );
  }
}

// Settings Dialog Widget
class _SettingsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;

  const _SettingsDialog({
    required this.userId,
    required this.onLogout,
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

    bool shouldEnableMusic = _volumeLevel > 0;
    bool shouldEnableSfx = _sfxLevel > 0;

    if (!shouldEnableMusic && _audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    } else if (shouldEnableMusic && !_audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    }

    if (!shouldEnableSfx && _audioService.isSfxEnabled) {
      _audioService.toggleSfx();
    } else if (shouldEnableSfx && !_audioService.isSfxEnabled) {
      _audioService.toggleSfx();
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

    bool shouldEnableMusic = value > 0;
    if (!shouldEnableMusic && _audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    } else if (shouldEnableMusic && !_audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    }

    _saveSettings();
  }

  void _onSfxVolumeChanged(double value) {
    setState(() => _sfxLevel = value);

    bool shouldEnableSfx = value > 0;
    if (!shouldEnableSfx && _audioService.isSfxEnabled) {
      _audioService.toggleSfx();
    } else if (shouldEnableSfx && !_audioService.isSfxEnabled) {
      _audioService.toggleSfx();
    }

    _saveSettings();
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                "assets/images-icons/sadlogout.png",
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 15),
              const Text(
                "Logout Confirmation",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Are you sure you want to log out?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF046EB8),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "No",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF046EB8),
                        ),
                      ),
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Yes",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onLogout();
  }

  Future<void> _handleRateGame() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool('has_rated_${widget.userId}') ?? false;

    if (hasRated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already rated this game. Thank you!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _RatingDialog(
        userId: widget.userId,
        onRatingSubmitted: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('has_rated_${widget.userId}', true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF046EB8), size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF046EB8),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF046EB8)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Row(
              children: [
                Icon(Icons.music_note, color: Color(0xFF046EB8), size: 20),
                SizedBox(width: 8),
                Text(
                  'Music Volume',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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
                  child: Text(
                    '${_volumeLevel.round()}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Row(
              children: [
                Icon(Icons.graphic_eq, color: Color(0xFF046EB8), size: 20),
                SizedBox(width: 8),
                Text(
                  'Sound Effects Volume',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
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
                  child: Text(
                    '${_sfxLevel.round()}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleRateGame,
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text(
                  'Rate Game',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDD000),
                  foregroundColor: const Color(0xFF816A03),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF046EB8),
                  side: const BorderSide(color: Color(0xFF046EB8), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Rating Dialog Widget
class _RatingDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onRatingSubmitted;

  const _RatingDialog({
    required this.userId,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('rating_${widget.userId}', _rating);
      await prefs.setString('feedback_${widget.userId}', _feedback);
      await prefs.setString('rating_timestamp_${widget.userId}', DateTime.now().toIso8601String());

      debugPrint('⭐ Rating saved locally:');
      debugPrint('User ID: ${widget.userId}');
      debugPrint('Rating: $_rating stars');
      debugPrint('Feedback: $_feedback');
      debugPrint('Timestamp: ${DateTime.now()}');

      if (mounted) {
        widget.onRatingSubmitted?.call();
        Navigator.pop(context, true);

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for your rating!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving rating: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star_rounded,
              color: Color(0xFFFDD000),
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Rate Our Game!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF046EB8),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your feedback helps us improve',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
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
                      size: 40,
                    ),
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

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () {
                      Navigator.pop(context, false);
                    },
                    child: const Text(
                      'Later',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
                    ),
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
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF816A03)),
                      ),
                    )
                        : const Text(
                      'Submit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}