// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';
import 'loading_page.dart';
import 'login.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Settings Dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Full settings dialog shared by Memory Match and Whiz Puzzle.
///
/// Handles music/SFX volume sliders, rate-game, and logout — all in one place.
class GameSettingsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;

  const GameSettingsDialog({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  @override
  State<GameSettingsDialog> createState() => _GameSettingsDialogState();
}

class _GameSettingsDialogState extends State<GameSettingsDialog> {
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
      _volumeLevel =
          prefs.getDouble('music_volume_${widget.userId}') ?? 50.0;
      _sfxLevel =
          prefs.getDouble('sfx_volume_${widget.userId}') ?? 50.0;
    });

    await _audioService.setMusicVolume(_volumeLevel / 100.0);

    _syncMusicToggle(_volumeLevel > 0);
    _syncSfxToggle(_sfxLevel > 0);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
        'music_volume_${widget.userId}', _volumeLevel);
    await prefs.setDouble('sfx_volume_${widget.userId}', _sfxLevel);
  }

  void _syncMusicToggle(bool shouldEnable) {
    if (!shouldEnable && _audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    } else if (shouldEnable && !_audioService.isMusicEnabled) {
      _audioService.toggleMusic();
    }
  }

  void _syncSfxToggle(bool shouldEnable) {
    if (!shouldEnable && _audioService.isSfxEnabled) {
      _audioService.toggleSfx();
    } else if (shouldEnable && !_audioService.isSfxEnabled) {
      _audioService.toggleSfx();
    }
  }

  void _onVolumeChanged(double value) {
    setState(() => _volumeLevel = value);
    _audioService.setMusicVolume(value / 100.0);
    _syncMusicToggle(value > 0);
    _saveSettings();
  }

  void _onSfxVolumeChanged(double value) {
    setState(() => _sfxLevel = value);
    _syncSfxToggle(value > 0);
    _saveSettings();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConfirmDialog(
        icon: Image.asset('assets/images-icons/sadlogout.png',
            width: 80, height: 80),
        title: 'Logout Confirmation',
        message: 'Are you sure you want to log out?',
        confirmLabel: 'Yes',
        cancelLabel: 'No',
        confirmColor: const Color(0xFFFDD000),
        confirmTextColor: const Color(0xFF816A03),
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onLogout();
  }

  Future<void> _handleRateGame() async {
    final prefs = await SharedPreferences.getInstance();
    final hasRated =
        prefs.getBool('has_rated_${widget.userId}') ?? false;

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
      builder: (_) => GameRatingDialog(
        userId: widget.userId,
        onRatingSubmitted: () async {
          final p = await SharedPreferences.getInstance();
          await p.setBool('has_rated_${widget.userId}', true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings,
                        color: Color(0xFF046EB8), size: 28),
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

            // Music volume
            _sliderRow(
              icon: Icons.music_note,
              label: 'Music Volume',
              value: _volumeLevel,
              onChanged: _onVolumeChanged,
            ),
            const SizedBox(height: 16),

            // SFX volume
            _sliderRow(
              icon: Icons.graphic_eq,
              label: 'Sound Effects Volume',
              value: _sfxLevel,
              onChanged: _onSfxVolumeChanged,
            ),
            const SizedBox(height: 24),

            const Divider(),
            const SizedBox(height: 16),

            // Rate game
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleRateGame,
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text(
                  'Rate Game',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                ),
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

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF046EB8),
                  side: const BorderSide(
                      color: Color(0xFF046EB8), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF046EB8), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
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
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: const Color(0xFF046EB8),
                inactiveColor: Colors.grey[300],
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 35,
              child: Text(
                '${value.round()}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rating Dialog
// ─────────────────────────────────────────────────────────────────────────────

class GameRatingDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onRatingSubmitted;

  const GameRatingDialog({
    super.key,
    required this.userId,
    this.onRatingSubmitted,
  });

  @override
  State<GameRatingDialog> createState() => _GameRatingDialogState();
}

class _GameRatingDialogState extends State<GameRatingDialog> {
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
      await prefs.setString(
        'rating_timestamp_${widget.userId}',
        DateTime.now().toIso8601String(),
      );

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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            const Icon(Icons.star_rounded,
                color: Color(0xFFFDD000), size: 60),
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

            // Star picker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFDD000),
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Feedback field
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
                onChanged: (v) => _feedback = v,
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text(
                      'Later',
                      style: TextStyle(
                          fontFamily: 'Poppins', color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDD000),
                      foregroundColor: const Color(0xFF816A03),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
                                  Color(0xFF816A03)),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable confirm dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Generic two-button confirmation dialog used by both games.
class _ConfirmDialog extends StatelessWidget {
  final Widget icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final Color confirmTextColor;

  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
    required this.confirmTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 14),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: confirmColor, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      cancelLabel,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: confirmColor),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: confirmTextColor,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper — logout handler (call from any game screen)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> handleGameLogout(BuildContext context) async {
  LoadingHelper.showLoadingPage(context, message: 'Logging out...');
  await Future.delayed(const Duration(milliseconds: 500));
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  } catch (e) {
    debugPrint('Error clearing preferences: $e');
  }
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}