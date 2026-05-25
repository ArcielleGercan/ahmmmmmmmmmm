import 'audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'leaderboard_constants.dart';
import 'leaderboard_service.dart';
import 'leaderboard_widgets.dart';

class Leaderboard extends StatefulWidget {
  final String currentUserId;
  final String userAvatar;
  final String username;

  const Leaderboard({
    super.key,
    required this.currentUserId,
    required this.userAvatar,
    required this.username,
  });

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  late final LeaderboardService _svc;

  // ── Leaderboard table state ─────────────────────────────────────────────────
  String _selectedGame       = 'badges';
  String _selectedDifficulty = 'EASY';
  String _selectedCategory   = 'Solar System';
  bool   _isLoading          = true;
  List<Map<String, dynamic>> _rows = [];

  // ── Player stats state ──────────────────────────────────────────────────────
  int    _playerStars    = 0;
  String _playerTier     = 'Beginner';

  Map<String, dynamic> _badgeCounts = {
    'easy_count': 0, 'average_count': 0, 'difficult_count': 0,
  };

  // ── Memory game picker ──────────────────────────────────────────────────────
  int _memoryDiffIdx = 0;
  Map<String, dynamic>? _memoryStats;

  // ── Puzzle picker ───────────────────────────────────────────────────────────
  int _puzzleDiffIdx = 0;
  int _puzzleCatIdx  = 0;
  Map<String, dynamic>? _puzzleStats;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _svc = LeaderboardService(http.Client());
    _initLoad();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initLoad() async {
    await Future.wait([
      _loadLeaderboard(),
      _loadPlayerProfile(),
      _loadMemoryStat(),
      _loadPuzzleStat(autoSelect: true),
    ]);
  }

  // ── Data loaders ────────────────────────────────────────────────────────────

  Future<void> _loadPlayerProfile() async {
    final results = await Future.wait([
      _svc.fetchPlayerStars(widget.currentUserId),
      _svc.fetchBadgeCounts(widget.currentUserId),
    ]);

    final starsData  = results[0];
    final badgeData  = results[1];

    if (!mounted) return;
    setState(() {
      if (starsData != null) {
        _playerStars = starsData['total_stars']           ?? 0;
        _playerTier  = starsData['current_tier']?['tier'] ?? 'Beginner';
      }
      if (badgeData != null) {
        _badgeCounts = {
          'easy_count':      badgeData['easy_count']      ?? 0,
          'average_count':   badgeData['average_count']   ?? 0,
          'difficult_count': badgeData['difficult_count'] ?? 0,
        };
      }
    });
  }

  Future<void> _loadMemoryStat() async {
    final diff = kGameDifficulties[_memoryDiffIdx];
    final data = await _svc.fetchMemoryMatchStat(widget.currentUserId, diff);
    if (mounted) setState(() => _memoryStats = data);
  }

  Future<void> _loadPuzzleStat({bool autoSelect = false}) async {
    final diff = kGameDifficulties[_puzzleDiffIdx];
    final cat  = kPuzzleCategories[_puzzleCatIdx];
    final data = await _svc.fetchPuzzleStat(widget.currentUserId, diff, cat);

    if (!mounted) return;
    setState(() => _puzzleStats = data);

    if (autoSelect && data == null) {
      // Parallel scan — much faster than the old sequential loop.
      final best = await _svc.autoFindBestPuzzle(widget.currentUserId);
      if (best != null && mounted) {
        setState(() {
          _puzzleDiffIdx = best.diffIdx;
          _puzzleCatIdx  = best.catIdx;
          _puzzleStats   = best.record;
        });
      }
    }
  }

  Future<void> _loadLeaderboard() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final data = await _fetchLeaderboardRows();
      if (mounted) setState(() => _rows = data);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLeaderboardRows() {
    switch (_selectedGame) {
      case 'badges': return _svc.fetchBadgesLeaderboard();
      case 'stars':  return _svc.fetchStarsLeaderboard();
      default:
        final gameType = _selectedGame == 'whiz_memory_match'
            ? 'memory_match'
            : 'puzzle';
        return _svc.fetchFastestTimeLeaderboard(
          gameType:   gameType,
          difficulty: _selectedDifficulty,
          category:   gameType == 'puzzle' ? _selectedCategory : null,
        );
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatTime(int? seconds) {
    if (seconds == null) return '--:--';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _accentColor() => gameColor(_selectedGame);

  Future<void> _playClick() async {
    try { await AudioService().playClickSound(); } catch (_) {}
  }

  // ── Root build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final isNarrow = w < 600;

    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: isNarrow
            ? Column(
                children: [
                  Expanded(flex: 6, child: _buildRankingsPanel()),
                  SizedBox(height: h * 0.38, child: _buildStatsPanel()),
                ],
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildRankingsPanel()),
                        SizedBox(
                          width: w < 900 ? w * 0.36 : 340,
                          child: Align(
                              alignment: Alignment.topCenter,
                              child: _buildStatsPanel()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: const [
          Text('LEADERBOARD',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2),
              textAlign: TextAlign.center),
          SizedBox(height: 2),
          Text('See how you rank against other Whiz Champions!',
              style: TextStyle(fontSize: 11, color: Color(0x99FFFFFF)),
              textAlign: TextAlign.center),
        ]),
      );

  // ═══════════════════════════════════════════════════════════════════════════
  // Rankings panel (left)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRankingsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFFE2E8F0), width: 1.5)),
            child: Column(
              children: [
                _buildRankingsToolbar(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                        color: _accentColor(),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTableHeader(),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingsToolbar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _GameButton(
                    label: 'Badges',
                    gameId: 'badges',
                    selectedGame: _selectedGame,
                    onTap: _onGameSelected),
                _GameButton(
                    label: 'Stars',
                    gameId: 'stars',
                    selectedGame: _selectedGame,
                    onTap: _onGameSelected),
              ],
            ),
            Row(
              children: [
                _buildFilterDropdowns(),
                const SizedBox(width: 4),
                _RefreshButton(onTap: () async {
                  await _playClick();
                  _loadLeaderboard();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Refreshing leaderboard…'),
                        duration: Duration(seconds: 1)));
                  }
                }),
              ],
            ),
          ],
        ),
      );

  void _onGameSelected(String gameId) async {
    await _playClick();
    setState(() {
      _selectedGame       = gameId;
      _rows               = [];
      _selectedDifficulty = 'EASY';
      _selectedCategory   = 'Solar System';
    });
    _loadLeaderboard();
  }

  Widget _buildFilterDropdowns() {
    final color = _accentColor();
    if (_selectedGame == 'badges' || _selectedGame == 'stars') {
      return const SizedBox.shrink();
    }
    if (_selectedGame == 'whiz_memory_match') {
      return _Dropdown(
        value: _selectedDifficulty,
        items: kGameDifficulties,
        labels: kGameDifficultiesDisplay,
        color: color,
        onChanged: (v) {
          if (v == null) return;
          setState(() => _selectedDifficulty = v);
          _loadLeaderboard();
        },
      );
    }
    // puzzle
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Dropdown(
          value: _selectedCategory,
          items: const [
            'Solar System', 'Scientists', 'Human Body',
            'Animals', 'Geometry', 'Starbooks',
          ],
          color: color,
          width: 130,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedCategory = v);
            _loadLeaderboard();
          },
        ),
        _Dropdown(
          value: _selectedDifficulty,
          items: kGameDifficulties,
          labels: kGameDifficultiesDisplay,
          color: color,
          onChanged: (v) {
            if (v == null) return;
            setState(() => _selectedDifficulty = v);
            _loadLeaderboard();
          },
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final color   = _accentColor();
    final isLight = color.computeLuminance() > 0.5;
    final textC   = isLight ? Colors.black87 : Colors.white;

    Widget col(String text, {int flex = 1}) => Expanded(
          flex: flex,
          child: Center(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: textC,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5))),
        );

    Widget label(String text) => Text(text,
        style: TextStyle(
            color: textC,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.5));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          SizedBox(width: 38, child: Center(child: label('RANK'))),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: label('PLAYER')),
          if (_selectedGame == 'badges') ...[
            col('TOTAL'), col('EASY'), col('AVG'), col('DIFF'),
          ] else if (_selectedGame == 'stars') ...[
            col('STARS'), col('TIER', flex: 2),
          ] else ...[
            col('TIME'),
            SizedBox(width: 60, child: Center(child: label('MOVES'))),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: _accentColor(), strokeWidth: 2.5));
    }
    if (_rows.isEmpty) {
      return const Center(
          child: Text('No rankings available yet.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      itemCount: _rows.length,
      itemBuilder: (_, i) {
        final p  = _rows[i];
        final id = LeaderboardService.extractIdPublic(
            p['player_id'] ?? p['id'] ?? p['_id']);
        return RankingRow(
          key: ValueKey('$id-$i'),
          player: p,
          rank: i + 1,
          isCurrentUser: id == widget.currentUserId,
          selectedGame: _selectedGame,
          formatTime: _formatTime,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Stats panel (right)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatsPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 16, 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUserProfile(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStarsRow(),
                  const SizedBox(height: 10),
                  _buildBadgesGrid(),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildMemoryCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPuzzleCard()),
                      ],
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

  Widget _buildUserProfile() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F4FF),
          borderRadius:
              BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
          border:
              Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: kGold, width: 3)),
              child: ClipOval(
                child: Image.asset(widget.userAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person,
                        size: 32, color: Color(0xFF85B7EB))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.username,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: kGold.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: kGold.withValues(alpha: 0.5))),
                    child: Text('Your Stats',
                        style: TextStyle(
                            fontSize: 10,
                            color: kGold,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildStarsRow() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: kAverage.withValues(alpha: 0.35), width: 1)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STARS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8)),
                  const SizedBox(height: 2),
                  Text('$_playerStars',
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          height: 1)),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: kAverage.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: kAverage.withValues(alpha: 0.5))),
                child: Text(_playerTier,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kAverage)),
              ),
              const SizedBox(width: 5),
              const TierInfoButton(average: kAverage),
            ]),
          ],
        ),
      );

  Widget _buildBadgesGrid() {
    final easy      = _badgeCounts['easy_count']      ?? 0;
    final average   = _badgeCounts['average_count']   ?? 0;
    final difficult = _badgeCounts['difficult_count'] ?? 0;
    final total     = easy + average + difficult;

    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFFFFDF0),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGold.withValues(alpha: 0.35), width: 1)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Text('BADGES',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8)),
                const Spacer(),
                Text('$total total',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kGold)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Row(
              children: [
                _BadgeTile('Easy',      '$easy',      kEasy,      'assets/images-badges/whiz-ready.png'),
                _BadgeTile('Average',   '$average',   kAverage,   'assets/images-badges/whiz-happy.png'),
                _BadgeTile('Difficult', '$difficult', kDifficult, 'assets/images-badges/whiz-achiever.png'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard() {
    const accent = kPurple;
    return _GameStatCard(
      accent: accent,
      bgColor: const Color(0xFFF5F3FF),
      icon: Icons.grid_view_rounded,
      label: 'MEMORY',
      timeStr: _formatTime(_memoryStats?['time_seconds']),
      difficultyPicker: DifficultyPicker(
        label: kGameDifficultiesDisplay[_memoryDiffIdx],
        accentColor: accent,
        onLeft: () {
          setState(() {
            _memoryDiffIdx = (_memoryDiffIdx - 1 + kGameDifficulties.length) %
                kGameDifficulties.length;
            _memoryStats = null;
          });
          _loadMemoryStat();
        },
        onRight: () {
          setState(() {
            _memoryDiffIdx =
                (_memoryDiffIdx + 1) % kGameDifficulties.length;
            _memoryStats = null;
          });
          _loadMemoryStat();
        },
      ),
    );
  }

  Widget _buildPuzzleCard() {
    const accent = kOrange;
    final rawTime = _puzzleStats?['time_seconds'];
    final timeStr =
        _formatTime(rawTime != null ? (rawTime as num).toInt() : null);

    return _GameStatCard(
      accent: accent,
      bgColor: const Color(0xFFFFF7ED),
      icon: Icons.extension_rounded,
      label: 'PUZZLE',
      timeStr: timeStr,
      extraContent: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: List.generate(kPuzzleCategories.length, (i) {
          final selected = i == _puzzleCatIdx;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _puzzleCatIdx = i;
                  _puzzleStats  = null;
                });
                _loadPuzzleStat();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: selected ? accent : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? accent
                            : const Color(0xFFCBD5E1))),
                child: Text(kPuzzleCategoriesShort[i],
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF64748B))),
              ),
            ),
          );
        }),
      ),
      difficultyPicker: DifficultyPicker(
        label: kGameDifficultiesDisplay[_puzzleDiffIdx],
        accentColor: accent,
        onLeft: () {
          setState(() {
            _puzzleDiffIdx = (_puzzleDiffIdx - 1 + kGameDifficulties.length) %
                kGameDifficulties.length;
            _puzzleStats = null;
          });
          _loadPuzzleStat();
        },
        onRight: () {
          setState(() {
            _puzzleDiffIdx =
                (_puzzleDiffIdx + 1) % kGameDifficulties.length;
            _puzzleStats = null;
          });
          _loadPuzzleStat();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widget helpers (file-local, no need to export)
// ═══════════════════════════════════════════════════════════════════════════

class _GameButton extends StatelessWidget {
  final String label;
  final String gameId;
  final String selectedGame;
  final void Function(String) onTap;

  const _GameButton({
    required this.label,
    required this.gameId,
    required this.selectedGame,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedGame == gameId;
    final color      = gameColor(gameId);
    final isLight    = color.computeLuminance() > 0.5;
    final textColor  = isSelected
        ? (isLight ? Colors.black87 : Colors.white)
        : const Color(0xFF64748B);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTap(gameId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: isSelected ? color : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                  width: 1.5)),
          child: Text(label,
              style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: textColor)),
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Refresh',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final List<String>? labels;
  final void Function(String?) onChanged;
  final Color color;
  final double width;

  const _Dropdown({
    required this.value,
    required this.items,
    this.labels,
    required this.onChanged,
    required this.color,
    this.width = 110,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1.5)),
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          underline: const SizedBox(),
          icon: Icon(Icons.keyboard_arrow_down, size: 15, color: color),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: items.asMap().entries.map((e) {
            final lbl = labels != null ? labels![e.key] : e.value;
            return DropdownMenuItem(
              value: e.value,
              child: Text(lbl,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B))),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      );
}

class _BadgeTile extends StatelessWidget {
  final String label;
  final String count;
  final Color color;
  final String imagePath;

  const _BadgeTile(this.label, this.count, this.color, this.imagePath);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35), width: 1.5)),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Image.asset(imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.military_tech_rounded,
                          color: color,
                          size: 22)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(count,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8))),
          ],
        ),
      );
}

/// Generic card used for Memory Match & Puzzle personal stats.
class _GameStatCard extends StatelessWidget {
  final Color accent;
  final Color bgColor;
  final IconData icon;
  final String label;
  final String timeStr;
  final Widget difficultyPicker;
  final Widget? extraContent; // puzzle category chips

  const _GameStatCard({
    required this.accent,
    required this.bgColor,
    required this.icon,
    required this.label,
    required this.timeStr,
    required this.difficultyPicker,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: accent.withValues(alpha: 0.35), width: 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.6)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(timeStr,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  height: 1),
              textAlign: TextAlign.center),
          const Text('fastest time',
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          if (extraContent != null) ...[extraContent!, const SizedBox(height: 6)],
          Center(child: difficultyPicker),
        ],
      ),
    );
  }
}
