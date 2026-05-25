import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'quiz_questions.dart';
import 'services/battle_websocket_service.dart';
import 'quiz_api.dart';
import 'audio_service.dart';
import 'game_tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loading_page.dart';
import 'login.dart';
import 'config.dart';

// ============================================================================
// AVATAR HELPER
// ============================================================================
ImageProvider _avatarProvider(String avatar) {
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return NetworkImage(avatar);
  }
  return AssetImage(avatar);
}

// ============================================================================
// DATA MODELS
// ============================================================================
class BattleRoom {
  final String gameCode;
  final String category;
  final String difficulty;

  BattleRoom({
    required this.gameCode,
    required this.category,
    required this.difficulty,
  });
}

// ============================================================================
// MAIN BATTLE SCREEN (Room Creation/Join)
// ============================================================================
class WhizBattle extends StatefulWidget {
  final String userAvatar;
  final String userId;
  final String username;

  const WhizBattle({
    super.key,
    required this.userAvatar,
    required this.userId,
    required this.username,
  });

  @override
  State<WhizBattle> createState() => _WhizBattleState();
}

class _WhizBattleState extends State<WhizBattle> {
  int _currentPage = 0;

  final TextEditingController _roomCodeController = TextEditingController();
  bool _isLoading = false;

  String _selectedDifficulty = 'EASY';
  String? _selectedMainCategory;

  bool _showGameTutorial = false;
  bool _checkingTutorialStatus = true;

  final List<Map<String, String>> _difficultyLevels = [
    {'value': 'EASY',      'display': 'Easy'},
    {'value': 'AVERAGE',   'display': 'Average'},
    {'value': 'DIFFICULT', 'display': 'Difficult'},
  ];

  final Map<String, List<String>> _mathTopics = {
    'EASY': [
      'Addition & Subtraction', 'Multiplication', 'Division',
      'Counting & Numbers', 'Basic Shapes', 'Comparing Numbers',
      'Number Patterns', 'Telling Time',
    ],
    'AVERAGE': [
      'Fractions & Decimals', 'Algebra Basics', 'Geometry',
      'Ratios & Proportions', 'Percentages', 'Area & Perimeter',
      'Integers', 'Word Problems',
    ],
    'DIFFICULT': [
      'Calculus', 'Statistics & Probability', 'Advanced Algebra',
      'Trigonometry', 'Linear Equations', 'Polynomials',
      'Logarithms', 'Matrices',
    ],
  };

  final Map<String, List<String>> _scienceTopics = {
    'EASY': [
      'Plants & Animals', 'Human Body', 'Weather & Seasons',
      'Day & Night', 'Rocks & Soil', 'Food Chains',
      'Simple Machines', 'Senses',
    ],
    'AVERAGE': [
      'Ecosystems', 'Cells & Organisms', 'Matter & States',
      'Forces & Motion', 'Solar System', 'Energy Types',
      'Water Cycle', 'Photosynthesis',
    ],
    'DIFFICULT': [
      'Molecular Biology', 'Advanced Chemistry', 'Quantum Physics',
      'Genetics & DNA', 'Thermodynamics', 'Electromagnetism',
      'Chemical Reactions', 'Atomic Structure',
    ],
  };

  String get _categoryForApi => _selectedMainCategory != null
      ? (_selectedMainCategory![0] + _selectedMainCategory!.substring(1).toLowerCase())
      : 'Science';

  String get _difficultyForApi {
    switch (_selectedDifficulty) {
      case 'EASY':      return 'Easy';
      case 'AVERAGE':   return 'Average';
      case 'DIFFICULT': return 'Difficult';
      default:          return 'Easy';
    }
  }

  @override
  void initState() {
    super.initState();
    AudioService().playBattleMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGameTutorialStatus();
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  Color _battleDifficultyColor(String value) {
    switch (value) {
      case 'EASY':      return const Color(0xFF1D9358);
      case 'AVERAGE':   return const Color(0xFF046EB8);
      case 'DIFFICULT': return const Color(0xFFBD442E);
      default:          return const Color(0xFF1D9358);
    }
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<void> _checkGameTutorialStatus() async {
  try {
    final shouldShow = await GameTutorialOverlay.shouldShowTutorial(
      widget.userId, 'battle',
    ).timeout(const Duration(seconds: 5)); // ADD THIS
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
    if (mounted) setState(() => _checkingTutorialStatus = false); // already there, good
  }
}

  Future<void> _createRoom() async {
    if (_isLoading) return;
    try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
    setState(() => _isLoading = true);

    final roomCode = _generateRoomCode();

    final wsService = BattleWebSocketService();
    final connected = await wsService.connect(widget.userId);

    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Failed to connect to server')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    wsService.createRoom(
      roomCode: roomCode,
      hostName: widget.username,
      hostAvatar: widget.userAvatar,
      category: _categoryForApi,
      difficulty: _difficultyForApi,
    );

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BattleGameScreen(
            battleRoom: BattleRoom(
              gameCode: roomCode,
              category: _categoryForApi,
              difficulty: _difficultyForApi,
            ),
            userId: widget.userId,
            username: widget.username,
            userAvatar: widget.userAvatar,
            isHost: true,
            webSocketService: wsService,
          ),
        ),
      );
    }
  }

  Future<void> _joinRoom() async {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code')),
      );
      return;
    }
    try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
    setState(() => _isLoading = true);

    final wsService = BattleWebSocketService();
    final connected = await wsService.connect(widget.userId);
    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to server')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    String? hostName;
    String? hostAvatar;
    String? errorMessage;
    String? hostCategory;
    String? hostDifficulty;

    final completer = Completer<void>();
    final subscription = wsService.messages.listen((message) {
      if (completer.isCompleted) return;
      final event = message['event'];

      if (event == 'join_success') {
        hostName       = message['host_name'];
        hostAvatar     = message['host_avatar'];
        hostCategory   = message['category'];
        hostDifficulty = message['difficulty'];
        completer.complete();
      } else if (event == 'error') {
        errorMessage = message['message'];
        completer.complete();
      }
    });

    wsService.joinRoom(
      roomCode: roomCode,
      playerName: widget.username,
      playerAvatar: widget.userAvatar,
    );

    await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    subscription.cancel();

    if (errorMessage != null) {
      if (mounted) {
        await wsService.dispose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $errorMessage'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (hostName == null) {
      if (mounted) {
        await wsService.dispose();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid code or timed out. Please check and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BattleGameScreen(
            battleRoom: BattleRoom(
              gameCode:   roomCode,
              category:   hostCategory   ?? _categoryForApi,
              difficulty: hostDifficulty ?? _difficultyForApi,
            ),
            userId: widget.userId,
            username: widget.username,
            userAvatar: widget.userAvatar,
            isHost: false,
            webSocketService: wsService,
            initialOpponentName: hostName,
            initialOpponentAvatar: hostAvatar,
          ),
        ),
      );
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
                  child: CircularProgressIndicator(color: Color(0xFFC571E2)),
                )
              : Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _currentPage == 0
                          ? _buildJoinCreatePage()
                          : _buildSetupPage(),
                    ),
                  ],
                ),
        ),
        if (_showGameTutorial)
          GameTutorialOverlay(
            userId: widget.userId,
            gameType: 'battle',
            onComplete: () => setState(() => _showGameTutorial = false),
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
              Image.asset(
                'assets/images-logo/newhomepagelogo.png',
                width: 150, height: 50, fit: BoxFit.contain,
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showSettingsDialog,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC571E2), width: 3),
                    ),
                    child: ClipOval(
                      child: Image(image: _avatarProvider(widget.userAvatar), fit: BoxFit.cover),
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
            color: Color(0xFFC571E2),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: () async {
                  try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                  if (_currentPage == 1) {
                    setState(() => _currentPage = 0);
                  } else {
                    Navigator.pop(context);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: Text(
                  _currentPage == 0 ? 'Whiz Battle' : 'Set Up Battle',
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

  Widget _buildJoinCreatePage() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Create a Room',
                  subtitle: 'Host a new battle and invite a friend',
                  buttonLabel: 'CREATE ROOM',
                  onTap: () => setState(() => _currentPage = 1),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  const Expanded(child: Divider(thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: Colors.grey[500], letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(thickness: 1)),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black87, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.login_rounded, size: 24, color: Colors.black87),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Join a Room',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                            Text(
                              "Enter a code to join a friend's battle",
                              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _roomCodeController,
                        decoration: InputDecoration(
                          hintText: 'Room Code (e.g. AB12CD)',
                          hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2, fontWeight: FontWeight.w600),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(color: Color(0xFFC571E2), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3),
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _isLoading ? null : _joinRoom,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.black87, width: 2),
                              ),
                              child: _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                      ),
                                    )
                                  : const Text(
                                      'JOIN ROOM',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w900,
                                        letterSpacing: 1, color: Colors.black87,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFC571E2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC571E2).withValues(alpha: 0.45),
            blurRadius: 12, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
              ],
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    buttonLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      letterSpacing: 1, color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPage() {
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                _buildDifficultyRow(),
                const SizedBox(height: 28),
                const Text(
                  'CATEGORY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                _buildExpandableCategoryCard('Math', Icons.calculate),
                const SizedBox(height: 14),
                _buildExpandableCategoryCard('Science', Icons.science),
                const SizedBox(height: 40),
                Center(child: _buildCreateButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyRow() {
    return Row(
      children: _difficultyLevels.map((d) {
        final isSelected = _selectedDifficulty == d['value'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                  setState(() {
                    _selectedDifficulty = d['value']!;
                    _selectedMainCategory = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? _battleDifficultyColor(d['value']!) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? _battleDifficultyColor(d['value']!) : Colors.black87,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: _battleDifficultyColor(d['value']!).withValues(alpha: 0.5),
                            blurRadius: 8, offset: const Offset(0, 3),
                          )]
                        : [],
                  ),
                  child: Text(
                    d['display']!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87, letterSpacing: 0.5,
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

  Widget _buildExpandableCategoryCard(String category, IconData icon) {
    final isExpanded = _selectedMainCategory?.toLowerCase() == category.toLowerCase();
    final topics = category.toLowerCase() == 'math'
        ? _mathTopics[_selectedDifficulty] ?? []
        : _scienceTopics[_selectedDifficulty] ?? [];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
          setState(() {
            _selectedMainCategory = isExpanded ? null : category.toUpperCase();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded ? _battleDifficultyColor(_selectedDifficulty) : Colors.black87,
              width: 2,
            ),
            boxShadow: isExpanded
                ? [BoxShadow(
                    color: _battleDifficultyColor(_selectedDifficulty).withValues(alpha: 0.35),
                    blurRadius: 10, offset: const Offset(0, 4),
                  )]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  color: isExpanded ? _battleDifficultyColor(_selectedDifficulty) : Colors.white,
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
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
                          fontSize: 17, fontWeight: FontWeight.w900,
                          color: isExpanded ? Colors.white : Colors.black87, letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.remove : Icons.add,
                          color: isExpanded ? Colors.white : Colors.black87, size: 18,
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
                            fontSize: 10, fontWeight: FontWeight.w800,
                            color: Colors.black45, letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: topics.map((topic) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.grey[300]!, width: 1.5),
                            ),
                            child: Text(
                              topic,
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87,
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

  Widget _buildCreateButton() {
    final isEnabled = _selectedMainCategory != null && !_isLoading;
    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: isEnabled ? _createRoom : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          decoration: BoxDecoration(
            color: isEnabled ? _battleDifficultyColor(_selectedDifficulty) : Colors.grey[300],
            borderRadius: BorderRadius.circular(30),
            boxShadow: isEnabled
                ? [BoxShadow(
                    color: _battleDifficultyColor(_selectedDifficulty).withValues(alpha: 0.5),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )]
                : [],
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black87),
                )
              : Text(
                  'CREATE ROOM',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900,
                    letterSpacing: 1, color: isEnabled ? Colors.black87 : Colors.grey[600],
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

// ============================================================================
// BATTLE GAME SCREEN
// ============================================================================
class BattleGameScreen extends StatefulWidget {
  final BattleRoom battleRoom;
  final String userId;
  final String username;
  final String userAvatar;
  final bool isHost;
  final BattleWebSocketService webSocketService;
  final String? initialOpponentName;
  final String? initialOpponentAvatar;

  const BattleGameScreen({
    super.key,
    required this.battleRoom,
    required this.userId,
    required this.username,
    required this.userAvatar,
    required this.isHost,
    required this.webSocketService,
    this.initialOpponentName,
    this.initialOpponentAvatar,
  });

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen> {

  List<Question> questions = [];
  int currentQuestionIndex = 0;
  int myScore = 0;
  int opponentScore = 0;
  bool gameStarted = false;
  int correctAnswersCount = 0;
  Map<String, dynamic>? badgeAwarded;
  List<bool?> questionResults = [];

  String opponentName = "Waiting...";
  String opponentAvatar = "assets/images-avatars/default.png";
  bool opponentJoined = false;

  Color _getDifficultyBackgroundColor() {
    switch (widget.battleRoom.difficulty.toUpperCase()) {
      case "EASY":      return const Color(0xFFB8EED4);
      case "AVERAGE":   return const Color(0xFFB8D9F5);
      case "DIFFICULT": return const Color(0xFFF5C4B8);
      default:          return const Color(0xFFB8EED4);
    }
  }

  Timer? questionTimer;
  final ValueNotifier<int> _timerNotifier = ValueNotifier(15);
  int get timeRemaining => _timerNotifier.value;
  bool showFeedback = false;
  bool wasCorrect = false;
  int earnedPoints = 0;
  bool waitingForOpponent = false;
  String? _selectedAnswer;
  bool _answerLocked = false;
  bool _isMusicEnabled = true;

  late StreamSubscription wsSubscription;
  late final Color _difficultyColor = _getDifficultyColor();

  @override
  void initState() {
    super.initState();
    if (widget.initialOpponentName != null) {
      opponentName = widget.initialOpponentName!;
      opponentAvatar = widget.initialOpponentAvatar ?? "assets/images-avatars/default.png";
      opponentJoined = true;
    }
    _listenToWebSocket();
  }

  @override
  void dispose() {
    questionTimer?.cancel();
    _timerNotifier.dispose();
    wsSubscription.cancel();
    super.dispose();
  }

  void _listenToWebSocket() {
    wsSubscription = widget.webSocketService.messages.listen((message) {
      if (!mounted) return;
      final event = message['event'];

      switch (event) {
        case 'room_created':
          break;

        case 'opponent_joined':
          if (mounted) {
            setState(() {
              opponentName = message['opponent_name'] ?? 'Opponent';
              opponentAvatar = message['opponent_avatar'] ?? 'assets/images-avatars/default.png';
              opponentJoined = true;
            });
          }
          break;

        case 'join_success':
          if (mounted) {
            setState(() {
              opponentName = message['host_name'] ?? 'Host';
              opponentAvatar = message['host_avatar'] ?? 'assets/images-avatars/default.png';
              opponentJoined = true;
            });
          }
          break;

        case 'game_started':
          _handleGameStarted(message);
          break;

        case 'score_update':
          _handleScoreUpdate(message);
          break;

        case 'both_answered':
          _handleBothAnswered(message);
          break;

        case 'next_question':
          _nextQuestion();
          break;

        case 'game_over':
          _handleGameOver(message);
          break;

        case 'player_left':
        case 'player_disconnected':
          _showOpponentLeftDialog();
          break;

        case 'error':
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message['message'] ?? 'Error occurred')),
            );
          }
          break;
      }
    });
  }

  void _handleGameStarted(Map<String, dynamic> message) {
    final questionsData = message['questions'] as List<dynamic>?;
    if (questionsData == null) return;

    questions = questionsData.map((q) {
      final qMap = q as Map<String, dynamic>;
      return Question(
        question: qMap['question'] ?? '',
        questionImage: qMap['question_image'],
        options: [
          qMap['choice_a'] ?? '',
          qMap['choice_b'] ?? '',
          qMap['choice_c'] ?? '',
          qMap['choice_d'] ?? '',
        ],
        optionImages: [
          qMap['choice_a_image'],
          qMap['choice_b_image'],
          qMap['choice_c_image'],
          qMap['choice_d_image'],
        ],
        correctAnswer: qMap['correct_answer'] ?? '',
      );
    }).toList();

    setState(() {
      gameStarted = true;
      currentQuestionIndex = 0;
      correctAnswersCount = 0;
      questionResults = [];
    });

    _startQuestionTimer();
  }

  void _handleScoreUpdate(Map<String, dynamic> message) {
    final scores = message['scores'] as Map<String, dynamic>?;
    if (scores == null || !mounted) return;
    setState(() {
      myScore = (scores[widget.userId] as num?)?.toInt() ?? myScore;
      scores.forEach((key, value) {
        if (key != widget.userId) {
          opponentScore = (value as num?)?.toInt() ?? opponentScore;
        }
      });
    });
  }

  void _handleBothAnswered(Map<String, dynamic> message) {
    final scores = message['scores'] as Map<String, dynamic>?;
    if (scores != null && mounted) {
      setState(() {
        myScore = (scores[widget.userId] as num?)?.toInt() ?? myScore;
        scores.forEach((key, value) {
          if (key != widget.userId) {
            opponentScore = (value as num?)?.toInt() ?? opponentScore;
          }
        });
        waitingForOpponent = false;
      });
    }
  }

  void _handleGameOver(Map<String, dynamic> message) async {
    questionTimer?.cancel();
    final winnerId = message['winner_id'] as String?;
    final didIWin = winnerId == widget.userId;

    try {
      final response = await QuizApiService.saveBattleResult(
        playerId: widget.userId,
        category: widget.battleRoom.category,
        difficulty: widget.battleRoom.difficulty,
        score: myScore,
        result: didIWin ? 'won' : 'lost',
        questionsAnswered: questions.length,
        correctAnswers: correctAnswersCount,
        battleId: widget.battleRoom.gameCode,
      );

      if (response != null && response['badge_awarded'] != null) {
        badgeAwarded = response['badge_awarded'];
      }
    } catch (e) {
      debugPrint('Error saving battle result: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BattleResultScreen(
          category: widget.battleRoom.category,
          difficulty: widget.battleRoom.difficulty,
          gameCode: widget.battleRoom.gameCode,
          myScore: myScore,
          opponentScore: opponentScore,
          myName: widget.username,
          opponentName: opponentName,
          myAvatar: widget.userAvatar,
          opponentAvatar: opponentAvatar,
          totalQuestions: questions.length,
          didIWin: didIWin,
          badgeAwarded: badgeAwarded,
        ),
      ),
    );
  }

  void _startQuestionTimer() {
    _timerNotifier.value = 15;
    questionTimer?.cancel();
    questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_timerNotifier.value > 0) {
        _timerNotifier.value--;
      } else {
        timer.cancel();
        if (!showFeedback && !_answerLocked) {
          _handleAnswer('');
        }
      }
    });
  }

  void _handleAnswer(String answer) {
    if (showFeedback || _answerLocked) return;
    questionTimer?.cancel();

    final isCorrect = answer.isNotEmpty &&
        answer == questions[currentQuestionIndex].correctAnswer;
    final points = isCorrect ? _timerNotifier.value : 0;

    setState(() {
      _selectedAnswer = answer;
      _answerLocked = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        showFeedback = true;
        wasCorrect = isCorrect;
        earnedPoints = points;
        myScore += points;
        waitingForOpponent = true;
        if (isCorrect) correctAnswersCount++;
        while (questionResults.length <= currentQuestionIndex) {
          questionResults.add(null);
        }
        questionResults[currentQuestionIndex] = isCorrect;
      });

      widget.webSocketService.submitAnswer(
        roomCode: widget.battleRoom.gameCode,
        isCorrect: isCorrect,
        points: points,
        questionIndex: currentQuestionIndex,
      );
    });
  }

  void _nextQuestion() {
    if (!mounted) return;
    setState(() {
      currentQuestionIndex++;
      showFeedback = false;
      wasCorrect = false;
      earnedPoints = 0;
      waitingForOpponent = false;
      _selectedAnswer = null;
      _answerLocked = false;
    });
    _startQuestionTimer();
  }

  void _showOpponentLeftDialog() {
    questionTimer?.cancel();
    if (!mounted) return;
    final didIWinByForfeit = gameStarted;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              didIWinByForfeit ? Icons.emoji_events : Icons.warning_amber_rounded,
              color: didIWinByForfeit ? Colors.amber : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(didIWinByForfeit ? 'Victory!' : 'Battle Ended'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              didIWinByForfeit
                  ? 'Your opponent has left. You win by forfeit!'
                  : 'Your opponent has left the battle.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (!didIWinByForfeit)
              const Text('The room has been closed.',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
              widget.webSocketService.disconnect();
              AudioService().playHomepageMusic();
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC571E2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor() {
    switch (widget.battleRoom.difficulty.toUpperCase()) {
      case "EASY":      return const Color(0xFF1D9358);
      case "AVERAGE":   return const Color(0xFF046EB8);
      case "DIFFICULT": return const Color(0xFFBD442E);
      default:          return const Color(0xFF1D9358);
    }
  }

  String _getDifficultyBackground() {
    switch (widget.battleRoom.difficulty.toUpperCase()) {
      case "EASY":      return 'assets/backgrounds/easybg.png';
      case "AVERAGE":   return 'assets/backgrounds/averagebg.png';
      case "DIFFICULT": return 'assets/backgrounds/difficultbg.png';
      default:          return 'assets/backgrounds/easybg.png';
    }
  }

  Future<bool> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Battle?'),
        content: const Text('Are you sure you want to leave? This will end the battle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldLeave == true;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getDifficultyColor();

    // HOST: Waiting for opponent
    if (widget.isHost && !opponentJoined) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
            widget.webSocketService.disconnect();
            AudioService().playHomepageMusic();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Waiting for opponent...', style: TextStyle(fontSize: 18, fontFamily: 'Poppins')),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text('Room Code:', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(
                        widget.battleRoom.gameCode,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                OutlinedButton.icon(
                  onPressed: () async {
                    try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                    widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
                    widget.webSocketService.disconnect();
                    AudioService().playHomepageMusic();
                    if (mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // HOST: Opponent joined, show START button
    if (widget.isHost && opponentJoined && !gameStarted) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
            widget.webSocketService.disconnect();
            AudioService().playHomepageMusic();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1D9358), size: 80),
                const SizedBox(height: 20),
                const Text('Opponent Ready!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const SizedBox(height: 20),
                Text(opponentName, style: const TextStyle(fontSize: 20, fontFamily: 'Poppins')),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () async {
                    try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                    widget.webSocketService.startGame(widget.battleRoom.gameCode);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('START BATTLE',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Poppins', color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // JOINER: Waiting for host to start
    if (!widget.isHost && !gameStarted) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
            widget.webSocketService.disconnect();
            AudioService().playHomepageMusic();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Waiting for host to start...', style: TextStyle(fontSize: 18, fontFamily: 'Poppins')),
                if (opponentJoined) ...[
                  const SizedBox(height: 20),
                  Text('Host: $opponentName', style: const TextStyle(fontSize: 16, fontFamily: 'Poppins')),
                ],
                const SizedBox(height: 30),
                OutlinedButton.icon(
                  onPressed: () async {
                    try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                    widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
                    widget.webSocketService.disconnect();
                    AudioService().playHomepageMusic();
                    if (mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Leave'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── GAME IN PROGRESS ──────────────────────────────────────────────────────
    // ── GAME IN PROGRESS ──────────────────────────────────────────────────────
    // ── GAME IN PROGRESS ──────────────────────────────────────────────────────
    if (gameStarted && questions.isNotEmpty) {
      final question = questions[currentQuestionIndex];
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            final leave = await _confirmLeave();
            if (leave && mounted) {
              widget.webSocketService.leaveRoom(widget.battleRoom.gameCode);
              widget.webSocketService.disconnect();
              AudioService().playHomepageMusic();
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
        },
        child: Scaffold(
          backgroundColor: _getDifficultyBackgroundColor(),
          extendBodyBehindAppBar: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    _getDifficultyBackground(),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _buildBattleHeader(color),
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 200,
                            child: _buildPlayerCard(widget.username, widget.userAvatar, myScore, color),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'VS',
                              style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900,
                                color: color, fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: _buildPlayerCard(opponentName, opponentAvatar, opponentScore, color),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  showFeedback ? _buildFeedback() : _buildQuestion(question),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // ── BATTLE HEADER with timer translated up to overlap the white bar ─────────
  Widget _buildBattleHeader(Color color) {
  return Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.bottomCenter,
    children: [
      // Slim white top bar — same as original
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.battleRoom.category}  ·  ${widget.battleRoom.difficulty}',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 0.4, fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 88),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _isMusicEnabled = !_isMusicEnabled);
                      if (_isMusicEnabled) {
                        AudioService().resumeMusic().catchError((_) => AudioService().playBattleMusic());
                      } else {
                        AudioService().pauseMusic();
                      }
                    },
                    icon: Icon(
                      _isMusicEnabled ? Icons.music_note : Icons.music_off,
                      size: 26, color: color,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Timer — half overlapping bottom of white bar
      Positioned(
        bottom: -44,
        child: ValueListenableBuilder<int>(
          valueListenable: _timerNotifier,
          builder: (_, secs, __) {
            final timerColor = secs <= 5 ? Colors.red : color;
            return Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: timerColor,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: timerColor.withValues(alpha: 0.45),
                    blurRadius: 10, offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$secs',
                  style: const TextStyle(
                    fontSize: 34, fontWeight: FontWeight.bold,
                    color: Colors.white, fontFamily: 'Poppins',
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildQuestion(Question question) {
    final color = _difficultyColor;
    final hasImageChoices = question.optionImages.any((img) => img != null && img.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 2), // reduced — sits tight under VS cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Question ${currentQuestionIndex + 1}',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins', color: color,
                ),
              ),
              const SizedBox(width: 10),
              ...List.generate(questions.length, (i) {
                Color dotColor;
                if (i < questionResults.length && questionResults[i] != null) {
                  dotColor = questionResults[i] == true
                      ? const Color(0xFF1D9358)
                      : const Color(0xFFE74C3C);
                } else if (i == currentQuestionIndex) {
                  dotColor = color;
                } else {
                  dotColor = color.withValues(alpha: 0.2);
                }
                return Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                );
              }),
              const SizedBox(width: 10),
              Text(
                'of ${questions.length}',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins', color: Color(0xFFAAAAAA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                  blurRadius: 10, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                question.question,
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins', height: 1.5,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
                softWrap: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: hasImageChoices
                  ? GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4, mainAxisSpacing: 10,
                        crossAxisSpacing: 12, childAspectRatio: 0.75,
                      ),
                      itemCount: question.options.length,
                      itemBuilder: (context, index) => _buildAnswerButton(
                        question.options[index], index,
                        imageUrl: question.optionImages.length > index
                            ? question.optionImages[index]
                            : null,
                      ),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10,
                        crossAxisSpacing: 12, childAspectRatio: 3.5,
                      ),
                      itemCount: question.options.length,
                      itemBuilder: (context, index) => _buildAnswerButton(
                        question.options[index], index, imageUrl: null,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static const List<Color> _answerColors = [
    Color(0xFF046EB8),
    Color(0xFFF39C12),
    Color(0xFFE67E22),
    Color(0xFF9B59B6),
  ];

  Widget _buildAnswerButton(String answer, int index, {String? imageUrl}) {
    final buttonColor = _answerColors[index % _answerColors.length];
    final isSelected = _selectedAnswer == answer;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (_answerLocked || showFeedback) {
      final isCorrectAnswer = answer == questions[currentQuestionIndex].correctAnswer;
      final isMyWrongPick = isSelected && !isCorrectAnswer;

      if (isCorrectAnswer) {
        bgColor = const Color(0xFF1D9358);
        borderColor = const Color(0xFF1D9358);
        textColor = Colors.white;
      } else if (isMyWrongPick) {
        bgColor = const Color(0xFFE74C3C);
        borderColor = const Color(0xFFE74C3C);
        textColor = Colors.white;
      } else {
        bgColor = Colors.white;
        borderColor = Colors.grey.shade300;
        textColor = Colors.black38;
      }
    } else {
      bgColor = Colors.white;
      borderColor = buttonColor;
      textColor = Colors.black87;
    }

    return MouseRegion(
      cursor: (_answerLocked || showFeedback)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: (_answerLocked || showFeedback) ? null : () => _handleAnswer(answer),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image_outlined, color: textColor, size: 32),
                          ),
                        ),
                      ),
                    ),
                    if (answer.isNotEmpty)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: bgColor.withValues(alpha: 0.9),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                          ),
                          child: Text(
                            answer,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: textColor, fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      answer,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600,
                        color: textColor, fontFamily: 'Poppins', height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final color = _getDifficultyColor();
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 18),
                Text(
                  wasCorrect ? 'CORRECT ANSWER!' : 'WRONG ANSWER!',
                  style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.bold,
                    color: wasCorrect ? const Color(0xFF1D9358) : const Color(0xFFE74C3C),
                    fontFamily: 'Poppins',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Image.asset(
                          'assets/images-icons/lightbulb.png',
                          width: 35, height: 35,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.lightbulb, color: Color(0xFFFFC107), size: 40),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              questions[currentQuestionIndex].question,
                              style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14, fontFamily: 'Poppins', color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Answer: ',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(
                                    text: questions[currentQuestionIndex].correctAnswer,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (wasCorrect) ...[
                              const SizedBox(height: 6),
                              Text(
                                '+$earnedPoints pts',
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D9358), fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (waitingForOpponent) ...[
                  const SizedBox(height: 18),
                  CircularProgressIndicator(color: color),
                  const SizedBox(height: 8),
                  const Text(
                    'Waiting for opponent...',
                    style: TextStyle(
                      fontSize: 15, color: Colors.white, fontFamily: 'Poppins',
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(String name, String avatar, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: _avatarProvider(avatar),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins',
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.star_rounded, color: color, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '$score pts',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: color, fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BATTLE RESULT SCREEN
// ============================================================================
class BattleResultScreen extends StatelessWidget {
  final String category;
  final String difficulty;
  final String gameCode;
  final int myScore;
  final int opponentScore;
  final String myName;
  final String opponentName;
  final String myAvatar;
  final String opponentAvatar;
  final int totalQuestions;
  final bool didIWin;
  final Map<String, dynamic>? badgeAwarded;

  const BattleResultScreen({
    super.key,
    required this.category,
    required this.difficulty,
    required this.gameCode,
    required this.myScore,
    required this.opponentScore,
    required this.myName,
    required this.opponentName,
    required this.myAvatar,
    required this.opponentAvatar,
    required this.totalQuestions,
    required this.didIWin,
    this.badgeAwarded,
  });

  Color _getDifficultyColor() {
    switch (difficulty.toUpperCase()) {
      case "EASY":      return const Color(0xFF1D9358);
      case "AVERAGE":   return const Color(0xFF046EB8);
      case "DIFFICULT": return const Color(0xFFBD442E);
      default:          return const Color(0xFF1D9358);
    }
  }

  Color _getResultColor()       => didIWin ? const Color(0xFFFDD000) : const Color(0xFFBD442E);
  Color _getResultStrokeColor() => didIWin ? const Color(0xFFAC8337) : const Color(0xFF631F13);
  String _getResultTitle()      => didIWin ? 'VICTORY!' : 'DEFEAT!';
  String _getResultMessage() {
    if (didIWin && badgeAwarded != null) return 'You won and earned a badge!';
    if (didIWin) return 'Great battle! You crushed it!';
    return 'Not this time — challenge them again!';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getDifficultyColor();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(color),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Stack(
                          children: [
                            Text(
                              _getResultTitle(),
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                letterSpacing: 2,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 7
                                  ..color = _getResultStrokeColor(),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              _getResultTitle(),
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: _getResultColor(),
                                fontFamily: 'Poppins',
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getResultMessage(),
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500,
                          color: Colors.black54, fontFamily: 'Poppins',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (didIWin && badgeAwarded != null) ...[
                        _buildBadgeProgress(color),
                        const SizedBox(height: 28),
                      ],
                      _buildVsCard(color),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                                AudioService().playHomepageMusic();
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(color: color, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: Text(
                                'Exit',
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins', color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                try { await AudioService().playClickSound(); } catch (e) { debugPrint('$e'); }
                                AudioService().playHomepageMusic();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 4,
                              ),
                              child: const Text(
                                'Play Again',
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins',
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
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold,
              color: Colors.white, letterSpacing: 1.5, fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            difficulty.toUpperCase(),
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: Colors.white70, fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBadgeProgress(Color color) {
    final badgeUnlocked  = badgeAwarded!['badge_unlocked'] ?? false;
    final badgeNumber    = badgeAwarded!['badge_number'];
    final difficultyName = badgeAwarded!['difficulty'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade300, Colors.amber.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.5),
            blurRadius: 15, spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            badgeUnlocked ? Icons.emoji_events : Icons.military_tech,
            color: Colors.white, size: 52,
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.stars, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  badgeUnlocked ? 'BADGE #$badgeNumber UNLOCKED!' : 'BADGE EARNED!',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: Colors.white, fontFamily: 'Poppins',
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              Text(
                badgeUnlocked ? 'Visit Badges screen to claim!' : 'Keep winning to unlock badges!',
                style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'Poppins'),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  difficultyName.toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold,
                    color: Colors.white, fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVsCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildPlayerResult(myName, myAvatar, myScore, isWinner: didIWin, color: color),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$myScore : $opponentScore',
                  style: TextStyle(
                    fontSize: 42, fontWeight: FontWeight.bold,
                    color: color, fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalQuestions questions',
                  style: const TextStyle(fontSize: 12, color: Colors.black38, fontFamily: 'Poppins'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildPlayerResult(opponentName, opponentAvatar, opponentScore, isWinner: !didIWin, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerResult(String name, String avatar, int score, {
    required bool isWinner,
    required Color color,
  }) {
    const double r = 46.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: r * 2 + 24,
          height: r * 2 + 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 12, top: 12,
                child: Container(
                  width: r * 2, height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isWinner ? color : Colors.grey.shade300,
                      width: isWinner ? 3.5 : 2,
                    ),
                    boxShadow: isWinner
                        ? [BoxShadow(
                            color: color.withValues(alpha: 0.30),
                            blurRadius: 12, spreadRadius: 2,
                          )]
                        : [],
                  ),
                  child: ClipOval(
                    child: Image(
                      image: _avatarProvider(avatar),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              if (isWinner)
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold,
            color: isWinner ? Colors.black87 : Colors.black45, fontFamily: 'Poppins',
          ),
          textAlign: TextAlign.center,
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: isWinner ? color : Colors.grey, size: 18),
            const SizedBox(width: 4),
            Text(
              '$score pts',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: isWinner ? color : Colors.grey, fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// SETTINGS DIALOG
// ============================================================================
class _SettingsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;

  const _SettingsDialog({required this.userId, required this.onLogout});

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
    bool shouldEnableSfx   = _sfxLevel > 0;

    if (!shouldEnableMusic && _audioService.isMusicEnabled)       _audioService.toggleMusic();
    else if (shouldEnableMusic && !_audioService.isMusicEnabled)  _audioService.toggleMusic();
    if (!shouldEnableSfx && _audioService.isSfxEnabled)           _audioService.toggleSfx();
    else if (shouldEnableSfx && !_audioService.isSfxEnabled)      _audioService.toggleSfx();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume_${widget.userId}', _volumeLevel);
    await prefs.setDouble('sfx_volume_${widget.userId}', _sfxLevel);
  }

  void _onVolumeChanged(double value) {
    setState(() => _volumeLevel = value);
    _audioService.setMusicVolume(value / 100.0);
    bool shouldEnable = value > 0;
    if (!shouldEnable && _audioService.isMusicEnabled)      _audioService.toggleMusic();
    else if (shouldEnable && !_audioService.isMusicEnabled) _audioService.toggleMusic();
    _saveSettings();
  }

  void _onSfxVolumeChanged(double value) {
    setState(() => _sfxLevel = value);
    bool shouldEnable = value > 0;
    if (!shouldEnable && _audioService.isSfxEnabled)      _audioService.toggleSfx();
    else if (shouldEnable && !_audioService.isSfxEnabled) _audioService.toggleSfx();
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
              Image.asset("assets/images-icons/sadlogout.png", width: 80, height: 80),
              const SizedBox(height: 15),
              const Text("Logout Confirmation",
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("No",
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF046EB8))),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Yes",
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
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
                const Row(children: [
                  Icon(Icons.settings, color: Color(0xFF046EB8), size: 28),
                  SizedBox(width: 12),
                  Text('Settings',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                          fontWeight: FontWeight.bold, color: Color(0xFF046EB8))),
                ]),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF046EB8)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Row(children: [
              Icon(Icons.music_note, color: Color(0xFF046EB8), size: 20),
              SizedBox(width: 8),
              Text('Music Volume',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600, color: Colors.black87)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _volumeLevel, min: 0, max: 100, divisions: 20,
                  activeColor: const Color(0xFF046EB8), inactiveColor: Colors.grey[300],
                  onChanged: _onVolumeChanged,
                ),
              ),
              SizedBox(
                width: 35,
                child: Text('${_volumeLevel.round()}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 16),
            const Row(children: [
              Icon(Icons.graphic_eq, color: Color(0xFF046EB8), size: 20),
              SizedBox(width: 8),
              Text('Sound Effects Volume',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                      fontWeight: FontWeight.w600, color: Colors.black87)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _sfxLevel, min: 0, max: 100, divisions: 20,
                  activeColor: const Color(0xFF046EB8), inactiveColor: Colors.grey[300],
                  onChanged: _onSfxVolumeChanged,
                ),
              ),
              SizedBox(
                width: 35,
                child: Text('${_sfxLevel.round()}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ]),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleRateGame,
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text('Rate Game',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDD000),
                  foregroundColor: const Color(0xFF816A03),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF046EB8),
                  side: const BorderSide(color: Color(0xFF046EB8), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// RATING DIALOG
// ============================================================================
class _RatingDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onRatingSubmitted;

  const _RatingDialog({required this.userId, this.onRatingSubmitted});

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
      debugPrint('⭐ Rating saved: $_rating stars  feedback: $_feedback');
      if (mounted) {
        widget.onRatingSubmitted?.call();
        Navigator.pop(context, true);
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your rating!'), backgroundColor: Colors.green),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFDD000), size: 60),
            const SizedBox(height: 16),
            const Text('Rate Our Game!',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 24,
                    fontWeight: FontWeight.bold, color: Color(0xFF046EB8))),
            const SizedBox(height: 8),
            const Text('Your feedback helps us improve',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black54),
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
                      color: const Color(0xFFFDD000), size: 40,
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
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
                  child: const Text('Later',
                      style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF816A03)),
                          ),
                        )
                      : const Text('Submit',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}