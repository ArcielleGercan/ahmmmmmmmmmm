import 'package:flutter/material.dart';
import 'dart:async';
import 'web_tts_service.dart';
import 'quiz_questions.dart';
import 'quiz_results.dart';
import 'quiz_api.dart';
import 'audio_service.dart';  // Use AudioService instead
import 'loading_page.dart';
import 'difficulty_settings_service.dart';

class QuizScreen extends StatefulWidget {
  final String category;
  final String difficulty;
  final String? yearLevel;  // Made optional
  final String userId;
  final String participationType;

  const QuizScreen({
    super.key,
    required this.category,
    required this.difficulty,
    this.yearLevel,  // Made optional
    required this.userId,
    this.participationType = "Whiz Challenge",
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final AudioService _audioService = AudioService();  // Add AudioService
  List<Question> questions = [];
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  int incorrectAnswers = 0;
  List<double> questionTimes = [];
  List<bool?> questionResults = []; // null=unanswered, true=correct, false=wrong

  Timer? _timer;
  int _secondsRemaining = 15;
  bool _showFeedback = false;
  bool _isCorrect = false;
  String? _selectedAnswer;
  bool _isAnswerLocked = false;
  bool _isMusicEnabled = true;

  // TTS — independent from music mute
  final WebTtsService _tts = WebTtsService();
  bool _isSpeaking = false;

  bool _isLoading = true;
  String? _errorMessage;

  DateTime? _gameStartTime;
  int _totalGameDuration = 0;

  int get _timerDuration =>
      DifficultySettingsService.instance.getTime(widget.difficulty);

  @override
  void initState() {
    super.initState();

    // Don't stop music - let quiz music continue from WhizChallenge
    // Music is already playing from selection screen

    _gameStartTime = DateTime.now();
    _initTts();
    _loadSettingsThenQuestions();
    // No need to initialize audio - music already playing
  }

  Future<void> _initTts() async {
    // WebTtsService handles all setup internally (language, rate, voice warmup)
    await _tts.init();
  }

  Future<void> _speakQuestion(String text) async {
    if (mounted) setState(() => _isSpeaking = true);
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e');
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _pauseBackgroundMusic() async {
    try {
      await _audioService.pauseMusic();
    } catch (e) {
      debugPrint('Error pausing music: $e');
    }
  }

  Future<void> _resumeBackgroundMusic() async {
    try {
      await _audioService.resumeMusic();
    } catch (e) {
      debugPrint('Error resuming music: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _audioService.stopMusic();
    } catch (e) {
      debugPrint('Error stopping music: $e');
    }
  }

  Future<void> _restartBackgroundMusic() async {
    try {
      if (_isMusicEnabled) {
        await _audioService.playQuizMusic();
      }
    } catch (e) {
      debugPrint('Error restarting music: $e');
    }
  }

  void _toggleMusic() {
    setState(() {
      _isMusicEnabled = !_isMusicEnabled;
    });

    if (_isMusicEnabled) {
      _resumeBackgroundMusic();
    } else {
      _pauseBackgroundMusic();
    }
  }

  Future<void> _loadSettingsThenQuestions() async {
    // Fetch latest difficulty settings from admin (non-blocking fallback to cached)
    await DifficultySettingsService.instance.load();
    await _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    // Only set loading state if not already set (avoids double setState on retry)
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Keep difficulty as-is from frontend (Title Case)
      debugPrint(
        'Loading questions for category: ${widget.category}, difficulty: ${widget.difficulty}',
      );

      questions = await QuizData.getQuestions(
        widget.category,
        widget.difficulty,  // Use as-is, don't convert to uppercase
        yearLevel: widget.yearLevel,  // Pass as optional parameter
      );

      debugPrint('Loaded ${questions.length} questions');

      if (questions.isEmpty) {
        setState(() {
          _errorMessage =
          'No questions available for ${widget.category} - ${widget.difficulty}';
          _isLoading = false;
        });
        return;
      }


      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ERROR loading questions: $e');
      setState(() {
        _errorMessage =
        'Failed to load questions. Please check your connection.';
        _isLoading = false;
      });
      return;
    }

    // TTS is OUTSIDE the try-catch so a TTS failure never shows the error screen
    try {
      await _speakQuestion(questions[currentQuestionIndex].question);
    } catch (e) {
      debugPrint('TTS failed, starting timer directly: $e');
    }
    if (mounted) _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = _timerDuration;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _handleTimeout();
          }
        });
      }
    });
  }

  void _resumeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _handleTimeout();
          }
        });
      }
    });
  }

  void _handleTimeout() {
    if (_isAnswerLocked) return;

    _timer?.cancel();
    _isAnswerLocked = true;

    setState(() {
      incorrectAnswers++;
      questionTimes.add(_timerDuration.toDouble());
      questionResults.add(false);
      _showFeedback = true;
      _isCorrect = false;
      _selectedAnswer = null;
    });
  }

  void _handleAnswer(String answer) {
    if (_showFeedback || _isAnswerLocked || _isSpeaking) return;

    _timer?.cancel();
    _isAnswerLocked = true;

    final timeTaken = _timerDuration - _secondsRemaining;
    questionTimes.add(timeTaken.toDouble());

    final isCorrect = answer == questions[currentQuestionIndex].correctAnswer;

    setState(() {
      _selectedAnswer = answer;
    });

    // Play sound effect based on correctness
    if (isCorrect) {
      _audioService.playCorrectAnswerSound();
    } else {
      _audioService.playWrongAnswer2Sound();
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showFeedback = true;
          _isCorrect = isCorrect;
          questionResults.add(isCorrect);

          if (isCorrect) {
            correctAnswers++;
          } else {
            incorrectAnswers++;
          }
        });
      }
    });
  }

  Future<void> _nextQuestion() async {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _showFeedback = false;
        _isCorrect = false;
        _selectedAnswer = null;
        _isAnswerLocked = false;
      });
      // ✅ FIX: await TTS so timer starts only after speaking finishes
      try {
        await _speakQuestion(questions[currentQuestionIndex].question);
      } catch (e) {
        debugPrint('TTS failed, starting timer directly: $e');
      }
      if (mounted) _startTimer();
    } else {
      _saveResultAndNavigate();
    }
  }

  Future<void> _saveResultAndNavigate() async {
    _timer?.cancel();

    if (_gameStartTime != null) {
      _totalGameDuration = DateTime.now().difference(_gameStartTime!).inSeconds;
    }

    final avgTime = questionTimes.isNotEmpty
        ? questionTimes.reduce((a, b) => a + b) / questionTimes.length
        : 0.0;

    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Saving Results...');

    // ✅ Try to save with retry — ALWAYS navigate to results regardless of outcome
    Map<String, dynamic>? badgeAwarded;
    int maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await QuizApiService.saveChallengeResult(
          playerId: widget.userId,
          category: widget.category,
          difficultyLevel: _normalizeDifficulty(widget.difficulty),
          totalQuestions: questions.length,
          correctAnswers: correctAnswers,
          timeTaken: _totalGameDuration,
        );
        if (response.success) {
          badgeAwarded = response.badgeAwarded;
        }
        break; // success — exit retry loop
      } catch (e) {
        debugPrint('Warning: save attempt $attempt failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          category: widget.category,
          difficulty: widget.difficulty,
          yearLevel: widget.yearLevel,
          correctAnswers: correctAnswers,
          incorrectAnswers: incorrectAnswers,
          totalQuestions: questions.length,
          averageTime: avgTime,
          badgeAwarded: badgeAwarded,
          userId: widget.userId,
        ),
      ),
    ).then((result) {
      if (!mounted) return;

      if (result == true) {
        // ✅ Retry — reset all state in one setState (includes _isLoading=true)
        // so there is only ONE rebuild before questions load, no double flash
        setState(() {
          currentQuestionIndex = 0;
          correctAnswers = 0;
          incorrectAnswers = 0;
          questionTimes = [];
          questionResults = [];
          questions = [];
          _showFeedback = false;
          _isCorrect = false;
          _selectedAnswer = null;
          _isAnswerLocked = false;
          _gameStartTime = DateTime.now();
          _totalGameDuration = 0;
          _isLoading = true;       // ← set here so _loadQuestions skips its own setState
          _errorMessage = null;
        });
        _loadSettingsThenQuestions();
      } else if (result is Map) {
        // ✅ Next level — pop quiz screen too, passing result up to WhizChallenge
        Navigator.of(context).pop(result);
      }
      // null = user exited normally, do nothing
    });
  }

  String _normalizeDifficulty(String diff) {
    final normalized = diff.toUpperCase();
    switch (normalized) {
      case "EASY":
        return "Easy";
      case "AVERAGE":
        return "Average";
      case "DIFFICULT":
        return "Difficult";
      default:
        return "Easy";
    }
  }

  void _showErrorAndNavigate(double avgTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Game completed but failed to sync with server'),
        backgroundColor: Colors.orange,
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          category: widget.category,
          difficulty: widget.difficulty,
          yearLevel: widget.yearLevel,
          correctAnswers: correctAnswers,
          incorrectAnswers: incorrectAnswers,
          totalQuestions: questions.length,
          averageTime: avgTime,
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _showPauseDialog() async {
    _timer?.cancel();
    // ✅ Music keeps playing when paused — toggle inside dialog controls it

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
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
                  Text(
                    "PAUSED!",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _getDifficultyColor(),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22, color: Colors.black54),
                    onPressed: () {
                      Navigator.pop(context);
                      _resumeTimer();
                      if (_isMusicEnabled) { _resumeBackgroundMusic(); }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ✅ Music toggle inside pause dialog
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Container(
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(_isMusicEnabled ? Icons.music_note : Icons.music_off,
                              color: _getDifficultyColor(), size: 22),
                          const SizedBox(width: 10),
                          const Text('Music', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
                        ]),
                        Switch(
                          value: _isMusicEnabled,
                          activeTrackColor: _getDifficultyColor(),
                          onChanged: (val) {
                            setState(() => _isMusicEnabled = val);
                            setDialogState(() {});
                            if (val) { _resumeBackgroundMusic(); } else { _pauseBackgroundMusic(); }
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
                  onPressed: () {
                    Navigator.pop(context);
                    _resumeTimer();
                    if (_isMusicEnabled) { _resumeBackgroundMusic(); }
                  },
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text(
                    "RESUME",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getDifficultyColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // RESTART BUTTON (with confirmation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Keep pause dialog open, show confirmation
                    final confirmed = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: 400,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh,
                                color: Color(0xFFF39C12),
                                size: 60,
                              ),
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
                                "Do you really want to restart? Your progress will be lost.",
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
                                      onPressed: () => Navigator.pop(context, false),
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
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF39C12),
                                        foregroundColor: Colors.white,
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    if (confirmed == true) {
                      if (!mounted) return;
                      // Close pause dialog
                      Navigator.pop(context);
                      if (!mounted) return;
                      // Reset all game state completely, then reload fresh questions
                      _timer?.cancel();
                      setState(() {
                        currentQuestionIndex = 0;
                        correctAnswers = 0;
                        incorrectAnswers = 0;
                        questionTimes = [];
                        questionResults = [];
                        questions = [];
                        _showFeedback = false;
                        _isCorrect = false;
                        _selectedAnswer = null;
                        _isAnswerLocked = false;
                        _gameStartTime = DateTime.now();
                        _totalGameDuration = 0;
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _loadSettingsThenQuestions();
                    }
                    // If cancelled, confirmation dialog closes automatically, pause dialog remains open
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    "RESTART",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF39C12),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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
                    // Keep pause dialog open, show confirmation
                    final confirmed = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          width: 400,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.exit_to_app,
                                color: Color(0xFFE74C3C),
                                size: 60,
                              ),
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
                                "Do you want to exit? Your progress will be lost.",
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
                                      onPressed: () => Navigator.pop(context, false),
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
                                        "Cancel",
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
                                      onPressed: () => Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE74C3C),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text(
                                        "Exit",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
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
                      ),
                    );

                    if (confirmed == true) {
                      if (!mounted) return;
                      // Close pause dialog first
                      Navigator.pop(context);
                      if (!mounted) return;
                      // Restart homepage music
                      _audioService.playHomepageMusic();
                      if (!mounted) return;
                      // Pop all the way back to homepage
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                    // If cancelled, confirmation dialog closes automatically, pause dialog remains open
                  },
                  icon: const Icon(Icons.home, size: 20),
                  label: const Text(
                    "EXIT",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black26, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _timer?.cancel();
    // Don't stop music here - let it continue to results screen
    super.dispose();
  }

  Color _getDifficultyColor() {
    switch (widget.difficulty.toUpperCase()) {
      case "EASY":
        return const Color(0xFF1D9358);
      case "AVERAGE":
        return const Color(0xFF046EB8);
      case "DIFFICULT":
        return const Color(0xFFBD442E);
      default:
        return const Color(0xFF1D9358);
    }
  }

  Color _getButtonColor(int index) {
    final colors = [
      const Color(0xFF046EB8),
      const Color(0xFFF39C12),
      const Color(0xFFE67E22),
      const Color(0xFF9B59B6),
    ];
    return colors[index % colors.length];
  }

  String _getDifficultyBackground() {
    switch (widget.difficulty.toUpperCase()) {
      case "EASY":
        return "assets/backgrounds/easybg.png";
      case "AVERAGE":
        return "assets/backgrounds/averagebg.png";
      case "DIFFICULT":
        return "assets/backgrounds/difficultbg.png";
      default:
        return "assets/backgrounds/easybg.png";
    }
  }

  @override
  Widget build(BuildContext context) {
    final difficultyColor = _getDifficultyColor();

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: difficultyColor),
              const SizedBox(height: 20),
              const Text(
                'Loading questions...',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Color(0xFFE74C3C),
                ),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF046EB8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loadQuestions,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D9358),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz, size: 80, color: Color(0xFF046EB8)),
              const SizedBox(height: 20),
              const Text(
                'No questions available',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = questions[currentQuestionIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Play click sound
        await _audioService.playClickSound();

        // Transition to homepage music
        await _audioService.playHomepageMusic(fadeIn: true);

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF87CEEB),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_getDifficultyBackground()),
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(difficultyColor),
              Expanded(
                child: Center(
                  child: _showFeedback
                      ? _buildFeedbackView(difficultyColor)
                      : _buildQuestionView(question, difficultyColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color difficultyColor) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            children: [
              // Left — category · difficulty pill
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: difficultyColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.category}  ·  ${widget.difficulty}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
              // Center spacer for the floating timer circle
              Expanded(child: Container()),
              // Right — pause button
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.pause_circle, size: 42, color: difficultyColor),
                      onPressed: _showPauseDialog,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Timer circle
        Positioned(
          top: 30,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isSpeaking
                  ? Colors.deepPurple
                  : (_secondsRemaining <= 5 ? Colors.red : difficultyColor),
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: [
                BoxShadow(
                  color: (_isSpeaking
                      ? Colors.deepPurple
                      : (_secondsRemaining <= 5 ? Colors.red : difficultyColor))
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isSpeaking
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up, color: Colors.white, size: 28),
                        SizedBox(height: 2),
                        Text(
                          'Listen',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '$_secondsRemaining',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionView(Question question, Color difficultyColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot indicators + label — OUTSIDE the white box, above it
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Question ${currentQuestionIndex + 1}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                color: difficultyColor,
              ),
            ),
            const SizedBox(width: 10),
            ...List.generate(questions.length, (i) {
              Color dotColor;
              if (i < questionResults.length) {
                dotColor = questionResults[i] == true
                    ? const Color(0xFF1D9358)
                    : const Color(0xFFE74C3C);
              } else if (i == currentQuestionIndex) {
                dotColor = difficultyColor;
              } else {
                dotColor = difficultyColor.withValues(alpha: 0.2);
              }
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              );
            }),
            const SizedBox(width: 10),
            Text(
              "of ${questions.length}",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                color: Color(0xFFAAAAAA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // White question box
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 140),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(30, 32, 30, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
          ),
        ),

        // Answer options
        const SizedBox(height: 24),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            margin: const EdgeInsets.symmetric(horizontal: 15),
            child: Builder(
              builder: (context) {
                final hasImageChoices = question.optionImages.any(
                      (img) => img != null && img.isNotEmpty,
                );

                if (hasImageChoices) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: question.options.length,
                    itemBuilder: (context, index) {
                      return _buildAnswerButton(
                        question.options[index],
                        index,
                        imageUrl: question.optionImages.length > index
                            ? question.optionImages[index]
                            : null,
                      );
                    },
                  );
                }

                // Text-only: normal 2x2 grid
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 12,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    return _buildAnswerButton(
                      question.options[index],
                      index,
                      imageUrl: null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerButton(String answer, int index, {String? imageUrl}) {
    final buttonColor = _getButtonColor(index);
    final isSelected = _selectedAnswer == answer && _isAnswerLocked;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _handleAnswer(answer),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? buttonColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: buttonColor, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasImage
              ? Stack(
            fit: StackFit.expand,
            children: [
              // Image fills the entire card
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: isSelected ? Colors.white : buttonColor,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              // Label overlay at bottom if answer text exists
              if (answer.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? buttonColor.withValues(alpha: 0.9)
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      answer,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          )
              : Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Text(
                answer,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontFamily: 'Poppins',
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackView(Color difficultyColor) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isCorrect ? "CORRECT ANSWER!" : "WRONG ANSWER!",
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: _isCorrect
                      ? const Color(0xFF1D9358)
                      : const Color(0xFFE74C3C),
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF046EB8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Next Question",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: difficultyColor, width: 2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Image.asset(
                        "assets/images-icons/lightbulb.png",
                        width: 35,
                        height: 35,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.lightbulb,
                            color: Color(0xFFFFC107),
                            size: 40,
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questions[currentQuestionIndex].question,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: Colors.black87,
                              ),
                              children: [
                                const TextSpan(
                                  text: "Answer: ",
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                TextSpan(
                                  text: questions[currentQuestionIndex]
                                      .correctAnswer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}