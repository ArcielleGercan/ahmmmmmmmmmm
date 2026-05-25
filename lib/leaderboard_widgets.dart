import 'package:flutter/material.dart';
import 'leaderboard_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Rank badge (medal or number circle)
// ─────────────────────────────────────────────────────────────────────────────

class RankBadge extends StatelessWidget {
  final int rank;
  const RankBadge(this.rank, {super.key});

  static Color colorFor(int rank) => switch (rank) {
    1 => kRank1, 2 => kRank2, 3 => kRank3, _ => kRankN,
  };

  @override
  Widget build(BuildContext context) {
    final bg = colorFor(rank);
    if (rank <= 3) {
      const medals = ['🥇', '🥈', '🥉'];
      return _circle(
        bg: bg.withValues(alpha: 0.20),
        border: bg,
        child: Text(medals[rank - 1], style: const TextStyle(fontSize: 18)),
      );
    }
    return _circle(
      bg: const Color(0xFFF1F5F9),
      border: const Color(0xFFE2E8F0),
      child: Text('$rank',
          style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w800,
              fontSize: 13)),
    );
  }

  Widget _circle({
    required Color bg,
    required Color border,
    required Widget child,
  }) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 2)),
        child: Center(child: child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat cell (single number in a table row)
// ─────────────────────────────────────────────────────────────────────────────

class StatCell extends StatelessWidget {
  final String value;
  final Color color;
  final bool bold;
  const StatCell(this.value, this.color, {this.bold = false, super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(value,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: color)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Difficulty arrow picker  ‹ Easy ›
// ─────────────────────────────────────────────────────────────────────────────

class DifficultyPicker extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const DifficultyPicker({
    super.key,
    required this.label,
    required this.accentColor,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _arrow(Icons.chevron_left, onLeft),
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            color: accentColor.withValues(alpha: 0.18),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: accentColor)),
            ),
          ),
          _arrow(Icons.chevron_right, onRight),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback cb) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: cb,
          child: Container(
            width: 20,
            height: 18,
            color: accentColor,
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tier info overlay button  (hover → popup)
// ─────────────────────────────────────────────────────────────────────────────

class TierInfoButton extends StatefulWidget {
  final Color average;
  const TierInfoButton({super.key, required this.average});

  @override
  State<TierInfoButton> createState() => _TierInfoButtonState();
}

class _TierInfoButtonState extends State<TierInfoButton> {
  OverlayEntry? _entry;
  final _key = GlobalKey();

  void _show() {
    if (_entry != null) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx - 185,
        top: offset.dy - 200,
        child: Material(
          color: Colors.transparent,
          child: _TierPopupCard(tiers: kTiers),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _show(),
      onExit: (_) => _hide(),
      child: Container(
        key: _key,
        width: 16,
        height: 16,
        decoration: BoxDecoration(
            color: widget.average.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: widget.average, width: 1.2)),
        child: Center(
          child: Text('i',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: widget.average,
                  fontStyle: FontStyle.normal,
                  fontFamily: 'Poppins',
                  height: 1.0)),
        ),
      ),
    );
  }
}

class _TierPopupCard extends StatelessWidget {
  final List<({String name, String from, String to, Color color})> tiers;
  const _TierPopupCard({required this.tiers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('STAR TIERS',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.8)),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 6),
          ...tiers.map((t) {
            final range = t.to.isEmpty ? '${t.from} stars' : '${t.from} – ${t.to} stars';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: t.color, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(t.name,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: t.color))),
                Text(range,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8))),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hoverable ranking row  (extracted from double-StatefulBuilder anti-pattern)
// ─────────────────────────────────────────────────────────────────────────────

class RankingRow extends StatefulWidget {
  final Map<String, dynamic> player;
  final int rank;
  final bool isCurrentUser;
  final String selectedGame;
  final String Function(int?) formatTime;

  const RankingRow({
    super.key,
    required this.player,
    required this.rank,
    required this.isCurrentUser,
    required this.selectedGame,
    required this.formatTime,
  });

  @override
  State<RankingRow> createState() => _RankingRowState();
}

class _RankingRowState extends State<RankingRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p    = widget.player;
    final isMe = widget.isCurrentUser;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? kGold.withValues(alpha: _hovered ? 0.14 : 0.08)
              : _hovered
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isMe
                ? kGold.withValues(alpha: _hovered ? 0.6 : 0.45)
                : _hovered
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFFE2E8F0),
            width: isMe ? 1.5 : (_hovered ? 1.5 : 0.5),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 38, child: RankBadge(widget.rank)),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: RankBadge.colorFor(widget.rank), width: 2),
                        color: const Color(0xFFE2E8F0)),
                    child: ClipOval(
                      child: Image.asset(
                        p['avatar'] ?? 'assets/images-avatars/Adventurer.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            color: Color(0xFF85B7EB),
                            size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['username'] ?? p['player_username'] ?? 'Unknown',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isMe
                                  ? kGoldDark
                                  : const Color(0xFF1E293B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isMe)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: kGold,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('YOU',
                                style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: kNavy,
                                    letterSpacing: 0.8)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ..._trailingCells(p),
          ],
        ),
      ),
    );
  }

  List<Widget> _trailingCells(Map<String, dynamic> p) {
    switch (widget.selectedGame) {
      case 'badges':
        final total = (p['easy_count'] ?? 0) +
            (p['average_count'] ?? 0) +
            (p['difficult_count'] ?? 0);
        return [
          Expanded(child: StatCell('$total', const Color(0xFF1E293B), bold: true)),
          Expanded(child: StatCell('${p['easy_count'] ?? 0}', kEasy)),
          Expanded(child: StatCell('${p['average_count'] ?? 0}', kAverage)),
          Expanded(child: StatCell('${p['difficult_count'] ?? 0}', kDifficult)),
        ];
      case 'stars':
        return [
          Expanded(child: StatCell('${p['stars'] ?? 0}', kGold, bold: true)),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: kAverage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: kAverage.withValues(alpha: 0.4))),
                child: Text('${p['tier'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kAverage),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ];
      default: // memory / puzzle
        return [
          Expanded(
              child: StatCell(
                  widget.formatTime(p['time_seconds']),
                  const Color(0xFF1E293B))),
          SizedBox(
              width: 60,
              child: StatCell(
                  '${p['moves'] ?? 0}', const Color(0xFF1E293B))),
        ];
    }
  }
}
