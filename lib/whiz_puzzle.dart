// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'audio_service.dart';
import 'game_dialogs.dart';        // ← shared: GameSettingsDialog, handleGameLogout
import 'game_results_page.dart';   // ← shared: GameResultsPage
import 'game_service.dart';        // ← shared: GameService, SaveTimeResult, StarAwardResult
import 'game_timer_widget.dart';   // ← shared: GameTimerDisplay
import 'game_tutorial_overlay.dart';
import 'loading_page.dart';
import 'puzzle_models.dart';       // ← PuzzlePiece, PuzzleDifficulty, puzzleCategories

class WhizPuzzle extends StatefulWidget {
  final String userAvatar;
  final String playerId;

  const WhizPuzzle({
    super.key,
    this.userAvatar = 'assets/images-avatars/Adventurer.png',
    required this.playerId,
  });

  @override
  State<WhizPuzzle> createState() => _WhizPuzzleState();
}

class _WhizPuzzleState extends State<WhizPuzzle> {
  // ── Difficulty / category selection ────────────────────────────────────────
  PuzzleDifficulty _difficulty = PuzzleDifficulty.easy;
  String? _category;

  // ── Game state ─────────────────────────────────────────────────────────────
  bool _gameStarted = false;
  int _moves = 0;
  bool _isPaused = false;
  bool _isCompleted = false;
  bool _isMusicEnabled = true;

  // ── Results ────────────────────────────────────────────────────────────────
  bool _isNewPersonalRecord = false;
  bool _isNewBestTime = false;
  int _starsEarned = 0;
  int _totalStars = 0;
  Map<String, dynamic>? _newMilestone;

  // ── Timer ──────────────────────────────────────────────────────────────────
  /// Drives [GameTimerDisplay] — only that widget repaints on each tick.
  final ValueNotifier<int> _timerNotifier = ValueNotifier(0);
  Timer? _gameTimer;

  // ── Personal / global best ─────────────────────────────────────────────────
  int? _fastestTime;
  int? _globalFastestTime;

  // ── Tutorial ───────────────────────────────────────────────────────────────
  bool _showGameTutorial = false;
  bool _checkingTutorialStatus = true;

  // ── Puzzle board ───────────────────────────────────────────────────────────
  List<PuzzlePiece> _pieces = [];
  String? _imageUrl;

  // ── Services ───────────────────────────────────────────────────────────────
  late final GameService _service;
  late final ConfettiController _confettiController;

  // ── Init / dispose ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _service = GameService();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGameTutorialStatus();
      AudioService().playPuzzleMusic();
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _timerNotifier.dispose();
    _confettiController.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── Tutorial ───────────────────────────────────────────────────────────────

  Future<void> _checkGameTutorialStatus() async {
    try {
      final shouldShow = await GameTutorialOverlay.shouldShowTutorial(
        widget.playerId,
        'puzzle',
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
        if (mounted) setState(() => _checkingTutorialStatus = false);
      }
    } catch (e) {
      debugPrint('Error checking tutorial status: $e');
      if (mounted) setState(() => _checkingTutorialStatus = false);
    }
  }

  // ── Game lifecycle ─────────────────────────────────────────────────────────

  void _startGame() {
    AudioService().playPuzzleMusic();
    if (_category == null) {
      _showWarningDialog();
      return;
    }

    _timerNotifier.value = 0;
    setState(() {
      _gameStarted = true;
      _moves = 0;
      _isPaused = false;
      _isCompleted = false;
      _isNewPersonalRecord = false;
      _isNewBestTime = false;
      _starsEarned = 0;
      _totalStars = 0;
      _newMilestone = null;
      _initializePuzzle();
    });

    _loadFastestTimes();

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused && !_isCompleted) {
        _timerNotifier.value++;
      }
    });
  }

  void _initializePuzzle() {
    final gridSize = _difficulty.gridSize;
    _imageUrl = categoryImage(_category!);

    final random = Random();
    const trayWidth = 260.0;
    const trayHeight = 400.0;

    _pieces = List.generate(gridSize * gridSize, (i) {
      return PuzzlePiece(
        id: i,
        correctRow: i ~/ gridSize,
        correctCol: i % gridSize,
        trayX: random.nextDouble() * (trayWidth - 60),
        trayY: random.nextDouble() * (trayHeight - 60),
        isLocked: false,
        isInTray: true,
      );
    });
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  Future<void> _loadFastestTimes() async {
    final times = await _service.loadFastestTimes(
      playerId: widget.playerId,
      gameType: 'puzzle',
      difficulty: _difficulty.value,
      category: _category,
    );
    if (mounted) {
      setState(() {
        _fastestTime = times.personal;
        _globalFastestTime = times.global;
      });
    }
  }

  Future<void> _checkCompletion() async {
    if (!_pieces.every((p) => p.isLocked)) return;

    _gameTimer?.cancel();
    setState(() => _isCompleted = true);

    if (mounted) {
      LoadingHelper.showLoadingDialog(
        context,
        message: 'Calculating results...',
        width: 350,
        height: 250,
      );
    }

    final currentTime = _timerNotifier.value;
    final bool newBestTime =
        _globalFastestTime != null && currentTime < _globalFastestTime!;
    setState(() => _isNewBestTime = newBestTime);

    await Future.wait([
      _saveFastestTime(currentTime),
      _awardStars(currentTime),
    ]);

    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        LoadingHelper.hideLoading(context);
        if (mounted) _showResultsPage(currentTime);
      }
    }
  }

  Future<void> _saveFastestTime(int currentTime) async {
    final result = await _service.saveFastestTime(
      playerId: widget.playerId,
      gameType: 'puzzle',
      difficulty: _difficulty.value,
      timeSeconds: currentTime,
      moves: _moves,
      category: _category,
      currentPersonalBest: _fastestTime,
    );
    if (mounted) {
      setState(() {
        _isNewPersonalRecord = result.isNewRecord;
        if (_fastestTime == null || currentTime < _fastestTime!) {
          _fastestTime = currentTime;
        }
        // ✅ ADD THIS
        if (_globalFastestTime == null || currentTime < _globalFastestTime!) {
          _globalFastestTime = currentTime;
        }
      });
    }
  }

  Future<void> _awardStars(int currentTime) async {
    final earned = _calculateStars(currentTime);
    final result = await _service.awardStars(
      playerId: widget.playerId,
      gameType: 'puzzle',
      difficulty: _difficulty.value,
      starsEarned: earned,
    );
    if (mounted) {
      setState(() {
        _starsEarned = result.starsEarned;
        _totalStars = result.totalStars;
        _newMilestone = result.newMilestone;
      });
    }
  }

  int _calculateStars(int currentTime) {
    final base = _difficulty == PuzzleDifficulty.easy
        ? 1
        : _difficulty == PuzzleDifficulty.average
            ? 2
            : 3;

    if (_globalFastestTime == null) return base * 5;
    final ratio = _globalFastestTime! / currentTime;
    if (ratio >= 1.0) return base * 5;
    if (ratio >= 0.8) return base * 3;
    if (ratio >= 0.6) return base * 2;
    return base;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _showResultsPage(int currentTime) {
    _confettiController.play();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameResultsPage(
          subtitleParts:
              '${_difficulty.value}  ·  ${_category ?? ''}',
          difficultyColor: _difficulty.color,
          yourTime: currentTime,
          bestTime: _globalFastestTime ?? currentTime,
          personalBest: _fastestTime ?? currentTime,
          starsEarned: _starsEarned,
          totalStars: _totalStars,
          moves: _moves,
          isNewBestTime: _isNewBestTime,
          isNewPersonalRecord: _isNewPersonalRecord,
          newMilestone: _newMilestone,
          onPlayAgain: () {
            Navigator.pop(context);
            _startGame();
          },
          onExit: () {
            Navigator.pop(context);
            AudioService().playHomepageMusic();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showWarningDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber,
                  size: 60, color: Color(0xFFE6833A)),
              const SizedBox(height: 15),
              const Text(
                'Incomplete Selection',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please select a category before starting the game.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AudioService().playClickSound();
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6833A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPauseDialog() {
    setState(() => _isPaused = true);
    _gameTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
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
                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      'PAUSED!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _difficulty.color,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 22, color: Colors.black54),
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (_) {}
                        Navigator.pop(context);
                        _resumeGame();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Music toggle
                StatefulBuilder(
                  builder: (ctx, setLocal) => Container(
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(
                            _isMusicEnabled
                                ? Icons.music_note
                                : Icons.music_off,
                            color: _difficulty.color,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text('Music',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ]),
                        Switch(
                          value: _isMusicEnabled,
                          activeColor: _difficulty.color,
                          onChanged: (val) {
                            setState(() => _isMusicEnabled = val);
                            setLocal(() {});
                            if (val) {
                              AudioService()
                                  .resumeMusic()
                                  .catchError((_) =>
                                      AudioService().playPuzzleMusic());
                            } else {
                              AudioService().pauseMusic();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Resume
                _pauseButton(
                  label: 'RESUME',
                  icon: Icons.play_arrow,
                  bgColor: _difficulty.color,
                  fgColor: Colors.white,
                  onTap: () async {
                    try {
                      await AudioService().playClickSound();
                    } catch (_) {}
                    Navigator.pop(context);
                    _resumeGame();
                  },
                ),
                const SizedBox(height: 14),

                // Restart
                _pauseButton(
                  label: 'RESTART',
                  icon: Icons.refresh,
                  bgColor: const Color(0xFFFDD000),
                  fgColor: const Color(0xFF816A03),
                  onTap: () async {
                    try {
                      await AudioService().playClickSound();
                    } catch (_) {}
                    Navigator.pop(context);
                    final confirmed = await _showConfirm(
                      icon: const Icon(Icons.refresh,
                          color: Color(0xFFE6833A), size: 60),
                      title: 'Restart Game',
                      message:
                          'Do you really want to restart? Your current progress will be lost.',
                      confirmLabel: 'Yes',
                      confirmColor: const Color(0xFFE6833A),
                    );
                    if (confirmed == true && mounted) {
                      _startGame();
                    } else if (mounted) {
                      _resumeGame();
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Exit
                _pauseOutlineButton(
                  label: 'EXIT',
                  icon: Icons.home,
                  onTap: () async {
                    try {
                      await AudioService().playClickSound();
                    } catch (_) {}
                    Navigator.pop(context);
                    final confirmed = await _showConfirm(
                      icon: const Icon(Icons.exit_to_app,
                          color: Colors.red, size: 60),
                      title: 'Exit Game',
                      message:
                          'Do you want to exit? Your current progress will be lost.',
                      confirmLabel: 'Yes',
                      confirmColor: Colors.red,
                    );
                    if (confirmed == true && mounted) {
                      AudioService().playHomepageMusic();
                      Navigator.pop(context);
                    } else if (mounted) {
                      _resumeGame();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resumeGame() {
    setState(() => _isPaused = false);
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused && !_isCompleted) {
        _timerNotifier.value++;
      }
    });
  }

  Future<bool?> _showConfirm({
    required Widget icon,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 15),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 14)),
              const SizedBox(height: 25),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      try {
                        await AudioService().playClickSound();
                      } catch (_) {}
                      Navigator.pop(context, false);
                    },
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: confirmColor, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text('No',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: confirmColor)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await AudioService().playClickSound();
                      } catch (_) {}
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => GameSettingsDialog(
        userId: widget.playerId,
        onLogout: () => handleGameLogout(context),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: _checkingTutorialStatus
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFE6833A)),
                )
              : _gameStarted
                  ? _buildGameBoard()
                  : Column(
                      children: [
                        _buildTopBar(),
                        Expanded(child: _buildSelectionScreen()),
                      ],
                    ),
        ),
        if (_showGameTutorial)
          GameTutorialOverlay(
            userId: widget.playerId,
            gameType: 'puzzle',
            onComplete: () =>
                setState(() => _showGameTutorial = false),
          ),
      ],
    );
  }

  // ── Selection screen ───────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Image.asset(
                'assets/images-logo/newhomepagelogo.png',
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
                      border: Border.all(
                          color: const Color(0xFFE6833A), width: 3),
                    ),
                    child: ClipOval(
                      child: Image.asset(widget.userAvatar,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFE6833A),
            boxShadow: [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 3,
                  offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 20),
                onPressed: () async {
                  try {
                    await AudioService().playClickSound();
                  } catch (_) {}
                  AudioService().playHomepageMusic();
                  Navigator.pop(context);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Expanded(child: SizedBox()),
              const Text(
                'Whiz Puzzle',
                textAlign: TextAlign.center,
                style: TextStyle(
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
          padding: const EdgeInsets.symmetric(
              horizontal: 40, vertical: 30),
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
                _buildCategoryGrid(),
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
    return Row(
      children: PuzzleDifficulty.values.map((d) {
        final isSelected = _difficulty == d;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  try {
                    await AudioService().playClickSound();
                  } catch (_) {}
                  setState(() => _difficulty = d);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? d.color : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? d.color : Colors.black87,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: d.color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Text(
                        d.displayLabel.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.gridLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: puzzleCategories.length,
      itemBuilder: (_, index) {
        final cat = puzzleCategories[index];
        final isSelected = _category == cat['name'];
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () async {
              try {
                await AudioService().playClickSound();
              } catch (_) {}
              setState(() => _category = cat['name']);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE6833A)
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE6833A)
                              .withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      cat['image']!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE6833A),
                              Color(0xFFD4621A)
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFE6833A)
                                .withValues(alpha: 0.7),
                            const Color(0xFFD4621A)
                                .withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          cat['name']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 1),
                                  blurRadius: 2)
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
        );
      },
    );
  }

  Widget _buildPlayButton() {
    final canPlay = _category != null;
    return MouseRegion(
      cursor: canPlay
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canPlay
            ? () async {
                try {
                  await AudioService().playClickSound();
                } catch (_) {}
                _startGame();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: canPlay
                ? const Color(0xFFE6833A)
                : Colors.grey[300],
            borderRadius: BorderRadius.circular(50),
            boxShadow: canPlay
                ? [
                    BoxShadow(
                      color: const Color(0xFFE6833A)
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Text(
            'PLAY',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: canPlay ? Colors.white : Colors.grey[600],
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Game board ─────────────────────────────────────────────────────────────

  Widget _buildGameBoard() {
    final cellSize = _difficulty.cellSize;
    final gridSize = _difficulty.gridSize;

    return Container(
      color: const Color(0xFFE6833A),
      child: Stack(
        children: [
          Column(
            children: [
              _buildGameStats(),
              const SizedBox(height: 70),
              Text(
                _category ?? '',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Grid
                    Container(
                      width: cellSize * gridSize,
                      height: cellSize * gridSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        border: Border.all(
                            color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GridView.builder(
                        physics:
                            const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                        ),
                        itemCount: gridSize * gridSize,
                        itemBuilder: (_, index) {
                          final row = index ~/ gridSize;
                          final col = index % gridSize;
                          final piece = _pieces.firstWhere(
                            (p) =>
                                p.isLocked &&
                                p.correctRow == row &&
                                p.correctCol == col,
                            orElse: () => PuzzlePiece(
                              id: -1,
                              correctRow: -1,
                              correctCol: -1,
                              trayX: 0,
                              trayY: 0,
                              isLocked: false,
                            ),
                          );

                          return DragTarget<int>(
                            onWillAcceptWithDetails: (_) =>
                                !_isPaused,
                            onAcceptWithDetails: (details) {
                              final dragged = _pieces.firstWhere(
                                  (p) => p.id == details.data);
                              setState(() {
                                if (dragged.correctRow == row &&
                                    dragged.correctCol == col) {
                                  dragged.isLocked = true;
                                  _checkCompletion();
                                }
                                _moves++;
                              });
                            },
                            builder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                color: piece.id != -1
                                    ? Colors.white
                                        .withValues(alpha: 0.2)
                                    : Colors.transparent,
                              ),
                              child: piece.id != -1
                                  ? _buildPieceImage(
                                      piece, cellSize)
                                  : const SizedBox.shrink(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Tray
                    Container(
                      width: 280,
                      height: cellSize * gridSize,
                      decoration: BoxDecoration(
                        color:
                            Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                            color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: _pieces
                            .where((p) =>
                                !p.isLocked && p.isInTray)
                            .map((p) =>
                                _buildDraggablePiece(p, cellSize))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
          // Floating pieces
          ..._pieces
              .where((p) =>
                  !p.isLocked &&
                  !p.isInTray &&
                  p.floatingPosition != null)
              .map((p) => _buildFloatingPiece(p, cellSize)),
        ],
      ),
    );
  }

  Widget _buildGameStats() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 18),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              // Difficulty · Category pill
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6833A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_difficulty.value}  ·  ${_category ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
              // Centre — spacer for floating timer
              const Expanded(child: SizedBox()),
              // Moves + Pause
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _timerNotifier,
                      builder: (_, __, ___) => Text(
                        'Moves: $_moves',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE6833A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.pause_circle,
                          size: 42, color: Color(0xFFE6833A)),
                      onPressed: () async {
                        try {
                          await AudioService().playClickSound();
                        } catch (_) {}
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
        // Floating timer circle
        Positioned(
          top: 30,
          child: GameTimerDisplay(
            timerNotifier: _timerNotifier,
            color: const Color(0xFFE6833A),
          ),
        ),
      ],
    );
  }

  // ── Puzzle piece widgets ───────────────────────────────────────────────────

  Widget _buildDraggablePiece(PuzzlePiece piece, double cellSize) {
    return Positioned(
      left: piece.trayX,
      top: piece.trayY,
      child: Draggable<int>(
        data: piece.id,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.8,
            child: _buildPieceImage(piece, cellSize * 0.8),
          ),
        ),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          if (!piece.isLocked) {
            setState(() {
              piece.isInTray = false;
              piece.floatingPosition = details.offset;
            });
          }
        },
        child: _buildPieceImage(piece, cellSize * 0.8),
      ),
    );
  }

  Widget _buildFloatingPiece(PuzzlePiece piece, double cellSize) {
    return Positioned(
      left: piece.floatingPosition!.dx,
      top: piece.floatingPosition!.dy,
      child: Draggable<int>(
        data: piece.id,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.8,
            child: _buildPieceImage(piece, cellSize * 0.8),
          ),
        ),
        childWhenDragging: Container(),
        onDragEnd: (details) {
          if (!piece.isLocked) {
            setState(() => piece.floatingPosition = details.offset);
          }
        },
        child: _buildPieceImage(piece, cellSize * 0.8),
      ),
    );
  }

  Widget _buildPieceImage(PuzzlePiece piece, double size) {
    final gridSize = _difficulty.gridSize;
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(border: Border.all(color: Colors.white, width: 2)),
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.none,
          alignment: Alignment(
            gridSize == 1
                ? 0.0
                : (piece.correctCol / (gridSize - 1)) * 2 - 1,
            gridSize == 1
                ? 0.0
                : (piece.correctRow / (gridSize - 1)) * 2 - 1,
          ),
          child: SizedBox(
            width: size * gridSize,
            height: size * gridSize,
            child: Image.asset(
              _imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey,
                child: Center(
                  child: Icon(Icons.image,
                      size: size * 0.5, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pause dialog helpers ───────────────────────────────────────────────────

  Widget _pauseButton({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _pauseOutlineButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black54,
          side: const BorderSide(color: Colors.black26, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}