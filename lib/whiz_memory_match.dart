import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'game_tutorial_overlay.dart';
import 'loading_page.dart'; // ✅ ADDED: Loading screen
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'audio_service.dart';

class WhizMemoryMatch extends StatefulWidget {
  final String userAvatar;
  final String playerId;
  final String username;

  const WhizMemoryMatch({
    super.key,
    this.userAvatar = "assets/images-avatars/Adventurer.png",
    required this.playerId,
    required this.username,
  });

  @override
  State<WhizMemoryMatch> createState() => _WhizMemoryMatchState();
}

class _WhizMemoryMatchState extends State<WhizMemoryMatch>
    with TickerProviderStateMixin {
  String _difficulty = "EASY";
  bool _gameStarted = false;
  int _timer = 0;
  int _moves = 0;
  Timer? _gameTimer;

  int? _globalFastestTime;
  int? _fastestTime;
  bool _showGameTutorial = false;
  bool _checkingTutorialStatus = true;

  List<CardItem> _cards = [];
  List<int> _flippedIndices = [];
  bool _isChecking = false;

  // ✅ FIX: Prevent double-tap and lag issues
  final Set<int> _tappedCards = {};
  bool _gameCompleted = false;

  late final ConfettiController _confettiController;
  final AudioService _audioService = AudioService();
  bool _isMusicEnabled = true; // ✅ Music toggle state

  // Track win state
  bool _isNewPersonalRecord = false;
  bool _isNewBestTime = false;
  int _starsEarned = 0;
  int _totalStars = 0;
  Map<String, dynamic>? _newMilestone;

  // Preview card flip animations
  final List<AnimationController> _previewControllers = [];
  final List<Animation<double>> _previewAnimations = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initPreviewControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGameTutorialStatus();
      _triggerPreviewFlip();
      AudioService().playMemoryMatchMusic(); // ✅ Start music on selection screen
    });
  }

  void _initPreviewControllers() {
    // Init controllers for max difficulty (7 cards)
    for (int i = 0; i < 7; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );
      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
      _previewControllers.add(controller);
      _previewAnimations.add(animation);
    }
  }

  void _triggerPreviewFlip() async {
    if (!mounted) return;

    // Reset all controllers
    for (final c in _previewControllers) {
      c.value = 0.0;
    }

    // Determine how many to flip based on current difficulty
    final pairs = _difficulty == 'EASY' ? 5 : (_difficulty == 'AVERAGE' ? 6 : 7);

    // Stagger flip only for the cards shown
    for (int i = 0; i < pairs; i++) {
      await Future.delayed(Duration(milliseconds: 80 * i));
      if (!mounted) return;
      _previewControllers[i].forward();
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _confettiController.dispose();
    for (final c in _previewControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    AudioService().playMemoryMatchMusic(); // ✅ Start memory match music
    setState(() {
      _gameStarted = true;
      _timer = 0;
      _isNewPersonalRecord = false;
      _isNewBestTime = false;
      _starsEarned = 0;
      _totalStars = 0;
      _moves = 0;
      _newMilestone = null;
      // ✅ FIX: Reset tap lock and game state
      _gameCompleted = false;
      _tappedCards.clear();
      _flippedIndices.clear();
      _generateCards();
    });

    _loadFastestTime();

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _timer++);
      }
    });
  }

  Future<void> _saveFastestTime() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/game/fastest-time'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'player_id': widget.playerId,
          'game_type': 'memory_match',
          'difficulty': _difficulty,
          'time_seconds': _timer,
          'moves': _moves,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool isNewRecord = data['is_new_record'] ?? false;

        if (isNewRecord && _fastestTime != null && _timer >= _fastestTime!) {
          isNewRecord = false;
        }

        setState(() {
          _isNewPersonalRecord = isNewRecord;
          if (_fastestTime == null || _timer < _fastestTime!) {
            _fastestTime = _timer;
          }
          // ✅ ADD THIS — update global best if this run was faster
          if (_globalFastestTime == null || _timer < _globalFastestTime!) {
            _globalFastestTime = _timer;
          }
        });
      }
    } catch (e) {
      debugPrint('Error saving fastest time: $e');
    }
  }

  Future<void> _awardStars() async {
    try {
      int starsEarned = _calculateStars();

      debugPrint('Awarding $starsEarned stars for difficulty: $_difficulty');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/players/${widget.playerId}/stars'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'stars': starsEarned,
          'game_type': 'memory_match',
          'difficulty': _difficulty,
        }),
      );

      debugPrint('Stars API response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _starsEarned = starsEarned;
          _totalStars = data['total_stars'];
          _newMilestone = data['new_milestone'];
        });
      } else {
        debugPrint('Failed to award stars: ${response.statusCode}');
        setState(() {
          _starsEarned = starsEarned;
        });
      }
    } catch (e) {
      debugPrint('Error awarding stars: $e');
      setState(() {
        _starsEarned = _calculateStars();
      });
    }
  }

  int _calculateStars() {
    final baseStars = _difficulty == "EASY" ? 1 : (_difficulty == "AVERAGE" ? 2 : 3);

    if (_globalFastestTime == null) {
      return baseStars * 5;
    }

    final performanceRatio = _globalFastestTime! / _timer;

    if (performanceRatio >= 1.0) {
      return baseStars * 5;
    } else if (performanceRatio >= 0.8) {
      return baseStars * 3;
    } else if (performanceRatio >= 0.6) {
      return baseStars * 2;
    } else {
      return baseStars;
    }
  }

  Future<void> _loadFastestTime() async {
    try {
      debugPrint('Loading fastest times for difficulty: $_difficulty');

      // ✅ FIX: Load personal + global times in parallel
      final results = await Future.wait([
        http.get(Uri.parse('${AppConfig.baseUrl}/game/fastest-time/${widget.playerId}/memory_match/$_difficulty')),
        http.get(Uri.parse('${AppConfig.baseUrl}/game/fastest-times/leaderboard?game_type=memory_match&difficulty=$_difficulty')),
      ]);

      final response = results[0];
      final leaderboardResponse = results[1];

      debugPrint('Personal fastest time response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] && data['data'] != null) {
          setState(() => _fastestTime = data['data']['time_seconds']);
          debugPrint('Loaded personal fastest time: $_fastestTime');
        } else {
          setState(() => _fastestTime = null);
          debugPrint('No personal fastest time found');
        }
      }

      debugPrint('Global leaderboard response: ${leaderboardResponse.statusCode}');

      if (leaderboardResponse.statusCode == 200) {
        final leaderboardData = json.decode(leaderboardResponse.body);
        if (leaderboardData['success'] == true) {
          final List<dynamic> times = leaderboardData['data'] ?? [];
          if (times.isNotEmpty) {
            setState(() => _globalFastestTime = times[0]['time_seconds']);
            debugPrint('Loaded global fastest time: $_globalFastestTime');
          } else {
            setState(() => _globalFastestTime = null);
            debugPrint('No global fastest time found');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading fastest times: $e');
    }
  }

  void _generateCards() {
    final pairs = _difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7);
    final prefix = _difficulty.toLowerCase();

    final cards = <CardItem>[];
    for (int i = 1; i <= pairs; i++) {
      final image = "assets/memorymatch/$prefix$i.png";
      cards.add(CardItem(id: i, imagePath: image));
      cards.add(CardItem(id: i, imagePath: image));
    }
    cards.shuffle(Random());
    setState(() {
      _cards = cards;
      _flippedIndices = [];
      _isChecking = false;
    });
  }

  void _onCardTap(int index) {
    // ✅ OPTIMIZATION: Enhanced tap protection
    if (_isChecking ||
        _gameCompleted ||
        _tappedCards.contains(index) ||
        _cards[index].isMatched ||
        _cards[index].isFlipped ||
        _flippedIndices.length >= 2) {
      return;
    }

    // ✅ OPTIMIZATION: Lock this card immediately to prevent double-tap
    _tappedCards.add(index);

    // ✅ OPTIMIZATION: Play sound without waiting (fire and forget for instant response)
    AudioService().playClickSound().catchError((e) {
      debugPrint('Click sound not found: $e');
    });

    // ✅ OPTIMIZATION: Single setState combining all state changes
    setState(() {
      _cards[index].isFlipped = true;
      _flippedIndices.add(index);

      // If two cards flipped, increment moves immediately in same setState
      if (_flippedIndices.length == 2) {
        _moves++;
      }
    });

    // Check match after setState completes
    if (_flippedIndices.length == 2) {
      _checkMatch();
    }
  }

  Future<void> _checkGameTutorialStatus() async {
    try {
      final shouldShow = await GameTutorialOverlay.shouldShowTutorial(
        widget.playerId,
        'memory_match',
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
          setState(() => _checkingTutorialStatus = false);
        }
      }
    } catch (e) {
      debugPrint('Error checking game tutorial status: $e');
      if (mounted) {
        setState(() => _checkingTutorialStatus = false);
      }
    }
  }

  Future<void> _checkMatch() async {
    _isChecking = true;
    final int firstIndex = _flippedIndices[0];
    final int secondIndex = _flippedIndices[1];

    final bool isMatch = _cards[firstIndex].id == _cards[secondIndex].id;

    // ✅ OPTIMIZATION: Play sounds immediately without waiting (fire and forget)
    if (isMatch) {
      _audioService.playCorrectAnswerSound().catchError((e) {
        debugPrint('Correct answer sound error: $e');
      });
    } else {
      _audioService.playWrongAnswer2Sound().catchError((e) {
        debugPrint('Wrong answer sound error: $e');
      });
    }

    // ✅ OPTIMIZATION: Single setState for visual feedback
    if (mounted) {
      setState(() {
        _cards[firstIndex].isMatching = isMatch;
        _cards[secondIndex].isMatching = isMatch;
        _cards[firstIndex].isNotMatching = !isMatch;
        _cards[secondIndex].isNotMatching = !isMatch;
      });
    }

    // ✅ OPTIMIZATION: Reduced delay to 500ms for faster gameplay
    await Future.delayed(const Duration(milliseconds: 500));

    // ✅ OPTIMIZATION: Single setState for final state
    if (mounted) {
      setState(() {
        if (isMatch) {
          _cards[firstIndex].isMatched = true;
          _cards[secondIndex].isMatched = true;
        } else {
          _cards[firstIndex].isFlipped = false;
          _cards[secondIndex].isFlipped = false;
        }

        _cards[firstIndex].isMatching = false;
        _cards[secondIndex].isMatching = false;
        _cards[firstIndex].isNotMatching = false;
        _cards[secondIndex].isNotMatching = false;

        _flippedIndices.clear();
        _tappedCards.clear();
        _isChecking = false;
      });
    }

    _checkWin();
  }

  void _checkWin() async {
    if (_cards.isNotEmpty && _cards.every((card) => card.isMatched)) {
      _gameTimer?.cancel();
      // ✅ OPTIMIZATION: Mark game as completed immediately
      _gameCompleted = true;

      // ✅ OPTIMIZATION: Show loading dialog IMMEDIATELY
      if (mounted) {
        LoadingHelper.showLoadingDialog(
          context,
          message: 'Calculating results...',
          width: 350,
          height: 250,
        );
      }

      // Store OLD global best time BEFORE saving
      final oldGlobalBest = _globalFastestTime;

      // ✅ OPTIMIZATION: Run save operations in parallel for faster completion
      await Future.wait([
        _saveFastestTime(),
        _awardStars(),
      ]);

      // Check if player beat the old global record
      if (mounted) {
        setState(() {
          if (oldGlobalBest != null && _timer < oldGlobalBest) {
            _isNewBestTime = true;
          } else {
            _isNewBestTime = false;
          }
        });
      }

      // ✅ OPTIMIZATION: Minimal delay for smooth transition
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));

        // Hide loading
        if (mounted) {
          LoadingHelper.hideLoading(context);

          // Immediate transition - no delay
          // Show results page
          if (mounted) {
            _showResultsPage();
          }
        }
      }
    }
  }

  // ignore: unused_element
  void _showCombinedWinDialog() {
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Confetti animation
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(10, (index) {
                    return ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirection: pi / 2,
                      emissionFrequency: 0.05,
                      numberOfParticles: 10,
                      maxBlastForce: 15,
                      minBlastForce: 8,
                      gravity: 0.3,
                      colors: const [
                        Color(0xFFFDD000),
                        Color(0xFF5F6FDB),
                        Color(0xFF046EB8),
                        Colors.red,
                        Colors.green,
                        Colors.orange,
                        Colors.pink,
                        Colors.purple,
                      ],
                    );
                  }),
                ),
              ),
            ),
            Center(
              child: Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: 450,
                  constraints: const BoxConstraints(maxHeight: 650),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Trophy Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isNewBestTime
                                  ? const Color(0xFFFDD000).withValues(alpha: 0.2)
                                  : _isNewPersonalRecord
                                  ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                                  : const Color(0xFF046EB8).withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              _isNewBestTime
                                  ? Icons.emoji_events
                                  : _isNewPersonalRecord
                                  ? Icons.star
                                  : Icons.check_circle,
                              size: 45,
                              color: _isNewBestTime
                                  ? const Color(0xFFFDD000)
                                  : _isNewPersonalRecord
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF046EB8),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _isNewBestTime
                                ? 'NEW RECORD!'
                                : _isNewPersonalRecord
                                ? 'PERSONAL BEST!'
                                : 'GAME COMPLETE!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _isNewBestTime
                                  ? const Color(0xFFFDD000)
                                  : _isNewPersonalRecord
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF046EB8),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            _isNewBestTime
                                ? 'You beat the best time!'
                                : _isNewPersonalRecord
                                ? 'You beat your personal best!'
                                : 'Well done!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ✅ NEW FORMAT: Performance Stats matching reference image
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDD000),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "PERFORMANCE STATS",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF816A03),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Correct box (green/mint)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB8E6B8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              "${(_difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7))}",
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            ),
                                            const Text(
                                              "Correct",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: Color(0xFF2E7D32),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Incorrect box (pink/red)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFCDD2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              "${_moves > (_difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7)) ? _moves - (_difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7)) : 0}",
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFC62828),
                                              ),
                                            ),
                                            const Text(
                                              "Incorrect",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 12,
                                                color: Color(0xFFC62828),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Time box (purple/lavender)
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD1C4E9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              "${(_timer / (_difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7))).toStringAsFixed(1)}s",
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF5E35B1),
                                              ),
                                            ),
                                            const Text(
                                              "Avg. Time / Question",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                color: Color(0xFF5E35B1),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Additional Stats (Optional - stars, best time, etc.)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                // Stars Earned Row
                                _buildStatRow(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFFDD000),
                                  label: 'Stars Earned',
                                  value: '+$_starsEarned',
                                  valueColor: const Color(0xFFFDD000),
                                  animate: true,
                                ),
                                const Divider(height: 24),

                                // Your Time Row
                                _buildStatRow(
                                  icon: Icons.timer,
                                  iconColor: const Color(0xFF5F6FDB),
                                  label: 'Your Time',
                                  value: _formatTime(_timer),
                                  valueColor: const Color(0xFF5F6FDB),
                                  animate: true,
                                  animateValue: _timer,
                                ),
                                const Divider(height: 24),

                                // Best Time Row
                                _buildStatRow(
                                  icon: Icons.emoji_events,
                                  iconColor: const Color(0xFFFDD000),
                                  label: 'Best Time',
                                  value: _formatTime(_globalFastestTime ?? _timer),
                                  valueColor: _isNewBestTime ? const Color(0xFFFDD000) : Colors.black87,
                                ),
                                const Divider(height: 24),

                                // Personal Best Row
                                _buildStatRow(
                                  icon: Icons.person,
                                  iconColor: const Color(0xFF046EB8),
                                  label: 'Personal Best',
                                  value: _formatTime(_fastestTime ?? _timer),
                                  valueColor: const Color(0xFF046EB8),
                                ),
                                const Divider(height: 24),

                                // Total Stars Row
                                _buildStatRow(
                                  icon: Icons.stars,
                                  iconColor: const Color(0xFFFDD000),
                                  label: 'Total Stars',
                                  value: '$_totalStars',
                                  valueColor: const Color(0xFFFDD000),
                                ),
                              ],
                            ),
                          ),

                          // Milestone Badge (if exists)
                          if (_newMilestone != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFDD000).withValues(alpha: 0.2),
                                    const Color(0xFFFDD000).withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFDD000), width: 2),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${_newMilestone!['icon']} MILESTONE!',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFDD000),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _newMilestone!['prize'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await AudioService().playClickSound();
                                    } catch (e) {
                                      debugPrint('Click sound not found: $e');
                                    }
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    Navigator.pop(context, true);
                                  },
                                  icon: const Icon(Icons.exit_to_app, size: 20),
                                  label: const Text(
                                    'EXIT',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF5F6FDB),
                                    side: const BorderSide(color: Color(0xFF5F6FDB), width: 2),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await AudioService().playClickSound();
                                    } catch (e) {
                                      debugPrint('Click sound not found: $e');
                                    }
                                    if (!mounted) return;
                                    Navigator.pop(context);
                                    _startGame();
                                  },
                                  icon: const Icon(Icons.replay, size: 20),
                                  label: const Text(
                                    'PLAY AGAIN',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF5F6FDB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ✅ NEW: Navigate to full-page results screen instead of dialog
  void _showResultsPage() {
    _confettiController.play();
    // Music keeps playing through the results page

    // ✅ Show loading screen before results page
    LoadingHelper.showLoadingPage(context, message: 'Loading results...');

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      LoadingHelper.hideLoading(context);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => _MemoryMatchResultsPage(
            difficulty: _difficulty,
            starsEarned: _starsEarned,
            yourTime: _timer,
            bestTime: _globalFastestTime ?? _timer,
            personalBest: _fastestTime ?? _timer,
            totalStars: _totalStars,
            pairs: _difficulty == "EASY" ? 5 : (_difficulty == "AVERAGE" ? 6 : 7),
            moves: _moves,
            isNewBestTime: _isNewBestTime,
            isNewPersonalRecord: _isNewPersonalRecord,
            onPlayAgain: () {
              Navigator.pop(context); // Close results page
              _startGame(); // _startGame() will call playMemoryMatchMusic()
            },
            onExit: () {
              Navigator.pop(context); // Close results page
              AudioService().playHomepageMusic(); // ✅ Restore homepage music
              Navigator.pop(context, true); // Exit to homepage
            },
          ),
        ),
      );
    });
  }

  Widget _buildStatRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    bool animate = false,
    int? animateValue,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        if (animate && animateValue != null)
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 1200),
            tween: IntTween(begin: 0, end: animateValue),
            builder: (context, val, child) {
              return Text(
                label == 'Your Time' ? _formatTime(val) : (label == 'Stars Earned' ? '+$val' : '$val'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              );
            },
          )
        else if (animate)
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 1000),
            tween: IntTween(begin: 0, end: int.parse(value.replaceAll('+', ''))),
            builder: (context, val, child) {
              return Text(
                label == 'Stars Earned' ? '+$val' : '$val',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              );
            },
          )
        else
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
      ],
    );
  }
  void _showPauseDialog() {
    _gameTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      const Text(
                        "PAUSED!",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5F6FDB),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22, color: Colors.black54),
                        onPressed: () async {
                          try {
                            await AudioService().playClickSound();
                          } catch (e) {
                            debugPrint('Click sound not found: $e');
                          }
                          Navigator.pop(context);
                          _resumeGame();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ✅ Music mute/unmute toggle
                  StatefulBuilder(
                    builder: (context, setDialogState) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isMusicEnabled ? Icons.music_note : Icons.music_off,
                                  color: const Color(0xFF5F6FDB),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Text('Music',
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isMusicEnabled,
                              activeColor: const Color(0xFF5F6FDB),
                              onChanged: (val) {
                                setState(() => _isMusicEnabled = val);
                                setDialogState(() {});
                                if (val) {
                                  _audioService.resumeMusic().catchError((_) => _audioService.playMemoryMatchMusic());
                                } else {
                                  _audioService.pauseMusic();
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // RESUME BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (e) {
                          debugPrint('Click sound not found: $e');
                        }
                        Navigator.pop(context);
                        _resumeGame();
                      },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text(
                        "RESUME",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5F6FDB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // RESTART BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (e) {
                          debugPrint('Click sound not found: $e');
                        }
                        Navigator.pop(context);

                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              width: 400,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh, color: Color(0xFFFDD000), size: 60),
                                  const SizedBox(height: 15),
                                  const Text(
                                    "Restart Game",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Do you really want to restart? Your current progress will be lost.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                                  ),
                                  const SizedBox(height: 25),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () async {
                                            try {
                                              await AudioService().playClickSound();
                                            } catch (e) {
                                              debugPrint('Click sound not found: $e');
                                            }
                                            Navigator.pop(context, false);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: const BorderSide(color: Color(0xFF5F6FDB), width: 1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          ),
                                          child: const Text(
                                            "No",
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: Color(0xFF5F6FDB),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await AudioService().playClickSound();
                                            } catch (e) {
                                              debugPrint('Click sound not found: $e');
                                            }
                                            Navigator.pop(context, true);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFDD000),
                                            foregroundColor: const Color(0xFF816A03),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                        if (confirmed == true && mounted) {
                          _startGame();
                        } else if (mounted) {
                          _resumeGame();
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text(
                        "RESTART",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // EXIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (e) {
                          debugPrint('Click sound not found: $e');
                        }
                        Navigator.pop(context);

                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              width: 400,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.exit_to_app, color: Colors.red, size: 60),
                                  const SizedBox(height: 15),
                                  const Text(
                                    "Exit Game",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Do you want to exit? Your current progress will be lost.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                                  ),
                                  const SizedBox(height: 25),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: () async {
                                            try {
                                              await AudioService().playClickSound();
                                            } catch (e) {
                                              debugPrint('Click sound not found: $e');
                                            }
                                            Navigator.pop(context, false);
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            side: const BorderSide(color: Color(0xFF5F6FDB), width: 1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          ),
                                          child: const Text(
                                            "No",
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: Color(0xFF5F6FDB),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            try {
                                              await AudioService().playClickSound();
                                            } catch (e) {
                                              debugPrint('Click sound not found: $e');
                                            }
                                            Navigator.pop(context, true);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

                        if (confirmed == true && mounted) {
                          Navigator.pop(context);
                        } else if (mounted) {
                          _resumeGame();
                        }
                      },
                      icon: const Icon(Icons.home, size: 20),
                      label: const Text(
                        "EXIT",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Colors.black26, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _resumeGame() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _timer++);
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Color _getDifficultyBackgroundColor() {
    switch (_difficulty) {
      case "EASY":
        return const Color(0xFF2E7D32);
      case "AVERAGE":
        return const Color(0xFF1976D2);
      case "DIFFICULT":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Color _getDifficultyBorderColor() {
    switch (_difficulty) {
      case "EASY":
        return const Color(0xFF2E7D32);
      case "AVERAGE":
        return const Color(0xFF1976D2);
      case "DIFFICULT":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  Future<void> _showSettingsDialog() async {
    showDialog(
      context: context,
      builder: (context) => _SettingsDialog(
        userId: widget.playerId,
        onLogout: _handleLogout,
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Show loading screen
    LoadingHelper.showLoadingPage(context, message: 'Logging out...');

    // Small delay to show loading screen
    await Future.delayed(const Duration(milliseconds: 500));

    // Clear user data
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing preferences: $e');
    }

    if (mounted) {
      // Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _showExitConfirmation() async {
    _gameTimer?.cancel(); // Pause the game

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 60),
              const SizedBox(height: 15),
              const Text(
                "Exit Game",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Are you sure you want to exit? Your progress will be lost.",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false), // No - stay in game
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF5F6FDB), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text(
                        "No",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF5F6FDB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true), // Yes - exit
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    if (confirmed == true && mounted) {
      Navigator.pop(context); // Exit to homepage
    } else {
      _resumeGame(); // Resume if they clicked No
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: _checkingTutorialStatus
              ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF656BE6)),
          )
              : Column(
            children: [
              if (!_gameStarted) _buildTopBar(),
              Expanded(
                child: _gameStarted ? _buildGameBoard() : _buildSelectionScreen(),
              ),
            ],
          ),
        ),

        // Game Tutorial Overlay
        if (_showGameTutorial)
          GameTutorialOverlay(
            userId: widget.playerId,
            gameType: 'memory_match',
            onComplete: () {
              setState(() => _showGameTutorial = false);
            },
          ),
      ],
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
              // Logo on the left
              Image.asset(
                "assets/images-logo/newhomepagelogo.png",
                width: 150,
                height: 50,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              // Avatar on the right
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showSettingsDialog,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1976D2), width: 3),
                    ),
                    child: ClipOval(
                      child: Image.asset(widget.userAvatar, fit: BoxFit.cover),
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
            color: Color(0xFF656BE6),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              // Back arrow button
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                onPressed: _gameStarted
                    ? _showExitConfirmation
                    : () async {
                  try {
                    await AudioService().playClickSound();
                  } catch (e) {
                    debugPrint('Click sound not found: $e');
                  }
                  AudioService().playHomepageMusic(); // ✅ Restore homepage music on back
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Expanded(child: SizedBox()),
              Text(
                "Whiz Memory Match",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Expanded(child: SizedBox()),
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
            constraints: const BoxConstraints(maxWidth: 700),
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
                _buildCardPreviewStrip(),
                const SizedBox(height: 40),
                Center(child: _buildPlayButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyRow() {
    // ✅ FIX: Better centered using Row with MainAxisAlignment.center
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // EASY Button
        SizedBox(
          width: 180,
          child: _buildDifficultyButton(
            value: 'EASY',
            display: 'EASY',
            pairs: '5 pairs',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        // AVERAGE Button
        SizedBox(
          width: 180,
          child: _buildDifficultyButton(
            value: 'AVERAGE',
            display: 'AVERAGE',
            pairs: '6 pairs',
            color: const Color(0xFF1976D2),
          ),
        ),
        const SizedBox(width: 12),
        // DIFFICULT Button
        SizedBox(
          width: 180,
          child: _buildDifficultyButton(
            value: 'DIFFICULT',
            display: 'DIFFICULT',
            pairs: '7 pairs',
            color: const Color(0xFFD32F2F),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyButton({
    required String value,
    required String display,
    required String pairs,
    required Color color,
  }) {
    final isSelected = _difficulty == value;
    // ✅ FIX: Removed Expanded, now using fixed width from parent
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            try {
              await AudioService().playClickSound();
            } catch (e) {
              debugPrint('Click sound error: $e');
            }
            setState(() => _difficulty = value);
            _triggerPreviewFlip();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected ? color : Colors.black87,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
                  : [],
            ),
            child: Column(
              children: [
                Text(
                  display,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pairs,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardPreviewStrip() {
    final pairs = _difficulty == 'EASY' ? 5 : (_difficulty == 'AVERAGE' ? 6 : 7);
    final backImage = 'assets/memorymatch/${_difficulty.toLowerCase()}.png';

    // Get border color based on difficulty
    final Color borderColor = _difficulty == 'EASY'
        ? const Color(0xFF2E7D32)
        : _difficulty == 'AVERAGE'
        ? const Color(0xFF1976D2)
        : const Color(0xFFD32F2F);

    // Show individual unique cards (not pairs) - just the unique card faces
    final previewCount = pairs;

    return Center(
      child: SizedBox(
        height: 160,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(previewCount, (i) {
            final frontImage = 'assets/memorymatch/${_difficulty.toLowerCase()}${i + 1}.png';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedBuilder(
                animation: _previewAnimations[i],
                builder: (context, _) {
                  final value = _previewAnimations[i].value;
                  final angle = value * pi;
                  final isShowingBack = value < 0.5;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 100,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: borderColor,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: isShowingBack
                            ? Image.asset(
                          backImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: borderColor,
                            child: const Center(
                              child: Icon(Icons.style, color: Colors.white, size: 24),
                            ),
                          ),
                        )
                            : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: Image.asset(
                            frontImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: borderColor,
                              child: Center(
                                child: Text(
                                  '${(i ~/ 2) + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try {
            await AudioService().playClickSound();
          } catch (e) {
            debugPrint('Click sound not found: $e');
          }
          _startGame();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF656BE6),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF656BE6).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Text(
            'PLAY',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    final totalCards = _cards.length;
    final cardsPerRow = (totalCards / 2).ceil();
    return Container(
      color: _getDifficultyBackgroundColor(),
      child: Column(
        children: [
          _buildGameStats(),
          const SizedBox(height: 70),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      cardsPerRow > _cards.length ? _cards.length : cardsPerRow,
                          (index) => _buildCard(index),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: List.generate(
                      _cards.length - cardsPerRow,
                          (index) => _buildCard(index + cardsPerRow),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGameStats() {
    // Get difficulty display text and color
    final String difficultyText = _difficulty;
    final Color difficultyColor = _getDifficultyBackgroundColor();

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Left side - Difficulty label
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: difficultyColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      difficultyText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // Center space for timer circle
              Expanded(child: Container()),

              // Right side - Moves and Pause button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Moves: $_moves",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getDifficultyBackgroundColor(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.pause_circle, size: 42, color: _getDifficultyBackgroundColor()),
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (e) {
                          debugPrint('Click sound not found: $e');
                        }
                        _showPauseDialog();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 30,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getDifficultyBackgroundColor(),
              border: Border.all(color: Colors.white, width: 5),
            ),
            child: Center(
              child: Text(
                _formatTime(_timer),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final showFront = card.isFlipped || card.isMatched;
    final backImage = "assets/memorymatch/${_difficulty.toLowerCase()}.png";
    // ✅ FIX: Wrap in RepaintBoundary to reduce rebuilds and improve performance
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          if (!_isChecking && !card.isMatched) _onCardTap(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 180,
          height: 270,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: card.isMatching
                  ? Colors.greenAccent
                  : card.isNotMatching
                  ? Colors.red
                  : (showFront ? _getDifficultyBorderColor() : Colors.transparent),
              width: card.isMatching || card.isNotMatching ? 4 : (showFront ? 3 : 0),
            ),
            boxShadow: [
              if (card.isMatching)
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              if (card.isNotMatching)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.8),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('${card.id}_${card.isFlipped}_$index'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut, // ✅ FIX: Add easing for smoother animation
            tween: Tween<double>(begin: showFront ? 0 : 1, end: showFront ? 1 : 0),
            builder: (context, value, _) {
              final angle = value * pi;
              final isBack = value < 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isBack
                      ? Image.asset(
                    backImage,
                    fit: BoxFit.cover,
                    // ✅ FIX: Cache images to reduce lag
                    cacheWidth: 360,
                    cacheHeight: 540,
                  )
                      : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: Image.asset(
                      card.imagePath,
                      fit: BoxFit.cover,
                      // ✅ FIX: Cache images to reduce lag
                      cacheWidth: 360,
                      cacheHeight: 540,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CardItem {
  final int id;
  final String imagePath;
  bool isFlipped;
  bool isMatched;
  bool isMatching;
  bool isNotMatching;

  CardItem({
    required this.id,
    required this.imagePath,
    this.isFlipped = false,
    this.isMatched = false,
    this.isMatching = false,
    this.isNotMatching = false,
  });
}

// ✅ Settings Dialog Widget
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

    // Apply to AudioService
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
    // Show confirmation dialog
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

    if (confirmed != true) {
      // User clicked "No" - stay in settings
      return;
    }

    // User clicked "Yes" - close settings and logout
    if (!mounted) return;
    Navigator.of(context).pop();

    // Call the logout handler
    widget.onLogout();
  }

  Future<void> _handleRateGame() async {
    // Check if user has already rated
    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool('has_rated_${widget.userId}') ?? false;

    if (hasRated) {
      // User already rated - show message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already rated this game. Thank you!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Close settings dialog first
    if (!mounted) return;
    Navigator.of(context).pop();

    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 150));

    // Show rating dialog
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
            // Header with close button
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

            // Volume Control
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

            // SFX Volume Control
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

            // Divider
            const Divider(),
            const SizedBox(height: 16),

            // Rate Game Button
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

            // Logout Button
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
// ✅ Rating Dialog Widget
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
      // Store rating locally using SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save rating data
      await prefs.setInt('rating_${widget.userId}', _rating);
      await prefs.setString('feedback_${widget.userId}', _feedback);
      await prefs.setString('rating_timestamp_${widget.userId}', DateTime.now().toIso8601String());

      debugPrint('⭐ Rating saved locally:');
      debugPrint('User ID: ${widget.userId}');
      debugPrint('Rating: $_rating stars');
      debugPrint('Feedback: $_feedback');
      debugPrint('Timestamp: ${DateTime.now()}');

      if (mounted) {
        // Call the callback to mark user as rated
        widget.onRatingSubmitted?.call();

        // Pop dialog first
        Navigator.pop(context, true);

        // Small delay to ensure context is valid
        await Future.delayed(const Duration(milliseconds: 100));

        // Show snackbar
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

            // Star Rating
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

            // Feedback TextField
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

            // Buttons
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
// ✅ NEW: Full-page results screen matching quiz_results.dart format
class _MemoryMatchResultsPage extends StatelessWidget {
  final String difficulty;
  final int starsEarned;
  final int yourTime;
  final int bestTime;
  final int personalBest;
  final int totalStars;
  final int pairs;
  final int moves;
  final bool isNewBestTime;
  final bool isNewPersonalRecord;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const _MemoryMatchResultsPage({
    required this.difficulty,
    required this.starsEarned,
    required this.yourTime,
    required this.bestTime,
    required this.personalBest,
    required this.totalStars,
    required this.pairs,
    required this.moves,
    required this.isNewBestTime,
    required this.isNewPersonalRecord,
    required this.onPlayAgain,
    required this.onExit,
  });

  Color _getDifficultyColor() {
    switch (difficulty.toUpperCase()) {
      case "EASY":
        return const Color(0xFF2E7D32);
      case "AVERAGE":
        return const Color(0xFF1976D2);
      case "DIFFICULT":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  // String _getResultTitle() {
  //   if (isNewBestTime) {
  //     return "NEW RECORD!";
  //   } else if (isNewPersonalRecord) {
  //     return "PERSONAL BEST!";
  //   } else {
  //     return "GAME COMPLETE!";
  //   }
  // }

  String _getResultMessage() {
    if (isNewBestTime) {
      return "You beat the best time!";
    } else if (isNewPersonalRecord) {
      return "You beat your personal best!";
    } else {
      return "Well done!";
    }
  }

  // Color _getResultColor() {
  //   if (isNewBestTime) {
  //     return const Color(0xFFFDD000);
  //   } else if (isNewPersonalRecord) {
  //     return const Color(0xFF4CAF50);
  //   } else {
  //     return const Color(0xFF046EB8);
  //   }
  // }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildStatBox(String value, String label, Color bgColor, Color textColor, bool showNewBadge) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontFamily: 'Poppins',
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          // NEW Badge
          if (showNewBadge)
            Positioned(
              top: -8,
              right: -8,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 1.0, end: 1.1),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'NEW!',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF333333),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSparkles() {
    return [
      Positioned(
        top: 20,
        left: 20,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value > 0.5 ? 1.0 - value : value * 2,
              child: Transform.scale(
                scale: value > 0.5 ? 2 - value * 2 : value * 2,
                child: child,
              ),
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: 40,
        right: 30,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value > 0.5 ? 1.0 - value : value * 2,
              child: Transform.scale(
                scale: value > 0.5 ? 2 - value * 2 : value * 2,
                child: child,
              ),
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 30,
        left: 40,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value > 0.5 ? 1.0 - value : value * 2,
              child: Transform.scale(
                scale: value > 0.5 ? 2 - value * 2 : value * 2,
                child: child,
              ),
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 40,
        right: 20,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1500),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value > 0.5 ? 1.0 - value : value * 2,
              child: Transform.scale(
                scale: value > 0.5 ? 2 - value * 2 : value * 2,
                child: child,
              ),
            );
          },
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final difficultyColor = _getDifficultyColor();
    // final correctAnswers = pairs;
    // final incorrectAnswers = moves > pairs ? moves - pairs : 0;
    // final avgTime = (yourTime / pairs).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: difficultyColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      difficulty.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),

                        // CONGRATULATIONS Title with yellow outline - BIGGER with animation
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Center(
                            child: Stack(
                              children: [
                                Text(
                                  'CONGRATULATIONS!',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 6
                                      ..color = const Color(0xFFC5A000),
                                    fontFamily: 'Poppins',
                                    letterSpacing: 2,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFFFDD000).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Text(
                                  'CONGRATULATIONS!',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFDD000),
                                    fontFamily: 'Poppins',
                                    letterSpacing: 2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Bird Badge with bounce animation - No circle, larger
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Transform.rotate(
                                angle: (1 - value) * -3.14,
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Sparkles
                                ..._buildSparkles(),
                                // Bird image
                                Center(
                                  child: Image.asset(
                                    'assets/images-badges/whiz-achiever.png',
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Achievement Message (changes based on record) - Enhanced
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: child,
                            );
                          },
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              fontSize: isNewPersonalRecord || isNewBestTime ? 22 : 20,
                              fontWeight: isNewPersonalRecord || isNewBestTime ? FontWeight.w800 : FontWeight.w700,
                              color: isNewBestTime
                                  ? const Color(0xFFFF6B00)
                                  : isNewPersonalRecord
                                  ? const Color(0xFF4CAF50)
                                  : Colors.black87,
                              fontFamily: 'Poppins',
                              shadows: isNewPersonalRecord || isNewBestTime
                                  ? [
                                Shadow(
                                  color: (isNewBestTime
                                      ? const Color(0xFFFF6B00)
                                      : const Color(0xFF4CAF50)).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ]
                                  : null,
                            ),
                            child: Text(
                              _getResultMessage(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // PERFORMANCE STATS Box - Enhanced with animation
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF0F0F0), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Title
                                const Text(
                                  'PERFORMANCE STATS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                    fontFamily: 'Poppins',
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Top Row: 3 boxes
                                Row(
                                  children: [
                                    // Your Time - Blue
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(yourTime),
                                        'Your Time',
                                        const Color(0xFF90CAF9),
                                        const Color(0xFF0D47A1),
                                        false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Best Time - Orange
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(bestTime),
                                        'Best Time',
                                        const Color(0xFFFFCC80),
                                        const Color(0xFFE65100),
                                        isNewBestTime,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Personal Best - Green
                                    Expanded(
                                      child: _buildStatBox(
                                        _formatTime(personalBest),
                                        'Personal Best',
                                        const Color(0xFFA5D6A7),
                                        const Color(0xFF1B5E20),
                                        isNewPersonalRecord,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Bottom Row: 2 boxes
                                Row(
                                  children: [
                                    // Stars Earned - Yellow
                                    Expanded(
                                      child: _buildStatBox(
                                        '+$starsEarned',
                                        'Stars Earned',
                                        const Color(0xFFFFF59D),
                                        const Color(0xFFF57F17),
                                        false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Total Stars - Purple
                                    Expanded(
                                      child: _buildStatBox(
                                        '$totalStars',
                                        'Total Stars',
                                        const Color(0xFFCE93D8),
                                        const Color(0xFF4A148C),
                                        false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons - Enhanced
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: child,
                            );
                          },
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onExit,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: difficultyColor,
                                        side: BorderSide(color: difficultyColor, width: 3),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: const Text(
                                        'EXIT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: onPlayAgain,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: difficultyColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        elevation: 4,
                                        shadowColor: difficultyColor.withValues(alpha: 0.3),
                                      ),
                                      child: const Text(
                                        'PLAY AGAIN',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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