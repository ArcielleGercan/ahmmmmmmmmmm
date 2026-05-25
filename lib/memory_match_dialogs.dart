// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';
import 'login.dart';
import 'loading_page.dart';

// ---------------------------------------------------------------------------
// Pause Dialog
// ---------------------------------------------------------------------------

class MemoryMatchPauseDialog extends StatefulWidget {
  final bool isMusicEnabled;
  final VoidCallback onResume;
  final VoidCallback onExit;
  final ValueChanged<bool> onMusicToggle;

  const MemoryMatchPauseDialog({
    super.key,
    required this.isMusicEnabled,
    required this.onResume,
    required this.onExit,
    required this.onMusicToggle,
  });

  @override
  State<MemoryMatchPauseDialog> createState() => _MemoryMatchPauseDialogState();
}

class _MemoryMatchPauseDialogState extends State<MemoryMatchPauseDialog> {
  late bool _isMusicEnabled;

  @override
  void initState() {
    super.initState();
    _isMusicEnabled = widget.isMusicEnabled;
  }

  @override
  Widget build(BuildContext context) {
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
                    'PAUSED!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5F6FDB),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22, color: Colors.black54),
                    onPressed: () async {
                      try { await AudioService().playClickSound(); } catch (_) {}
                      Navigator.pop(context);
                      widget.onResume();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Music toggle
              Container(
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
                        Text(
                          _isMusicEnabled ? 'Music ON' : 'Music OFF',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isMusicEnabled,
                      activeColor: const Color(0xFF5F6FDB),
                      onChanged: (val) {
                        setState(() => _isMusicEnabled = val);
                        widget.onMusicToggle(val);
                        AudioService().toggleMusic();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Resume button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try { await AudioService().playClickSound(); } catch (_) {}
                    Navigator.pop(context);
                    widget.onResume();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F6FDB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'RESUME',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Exit button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => _ExitConfirmDialog(),
                    );
                    if (confirmed == true && context.mounted) {
                      Navigator.pop(context);
                      widget.onExit();
                    } else if (context.mounted) {
                      widget.onResume();
                    }
                  },
                  icon: const Icon(Icons.home, size: 20),
                  label: const Text(
                    'EXIT',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}

// ---------------------------------------------------------------------------
// Exit Confirmation Dialog (shared by pause + in-game header)
// ---------------------------------------------------------------------------

class _ExitConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
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
              'Exit Game',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Are you sure you want to exit? Your progress will be lost.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF5F6FDB)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'No',
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
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDD000),
                      foregroundColor: const Color(0xFF816A03),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Yes',
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
    );
  }
}

/// Shows an exit confirmation and returns true if user confirms.
Future<bool> showExitConfirmation(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExitConfirmDialog(),
  ) ?? false;
}

// ---------------------------------------------------------------------------
// Settings Dialog
// ---------------------------------------------------------------------------

class MemoryMatchSettingsDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onLogout;

  const MemoryMatchSettingsDialog({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  @override
  State<MemoryMatchSettingsDialog> createState() =>
      _MemoryMatchSettingsDialogState();
}

class _MemoryMatchSettingsDialogState
    extends State<MemoryMatchSettingsDialog> {
  double _musicVol = 50;
  double _sfxVol = 50;
  final AudioService _audio = AudioService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final music = prefs.getDouble('music_volume_${widget.userId}') ?? 50.0;
    final sfx = prefs.getDouble('sfx_volume_${widget.userId}') ?? 50.0;
    if (!mounted) return;
    setState(() {
      _musicVol = music;
      _sfxVol = sfx;
    });
    await _audio.setMusicVolume(music / 100.0);
    _syncMusic(music > 0);
    _syncSfx(sfx > 0);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('music_volume_${widget.userId}', _musicVol);
    await prefs.setDouble('sfx_volume_${widget.userId}', _sfxVol);
  }

  void _syncMusic(bool enable) {
    if (!enable && _audio.isMusicEnabled) {
      _audio.toggleMusic();
    } else if (enable && !_audio.isMusicEnabled) {
      _audio.toggleMusic();
    }
  }

  void _syncSfx(bool enable) {
    if (!enable && _audio.isSfxEnabled) {
      _audio.toggleSfx();
    } else if (enable && !_audio.isSfxEnabled) {
      _audio.toggleSfx();
    }
  }

  void _onMusicChanged(double v) {
    setState(() => _musicVol = v);
    _audio.setMusicVolume(v / 100.0);
    _syncMusic(v > 0);
    _save();
  }

  void _onSfxChanged(double v) {
    setState(() => _sfxVol = v);
    _syncSfx(v > 0);
    _save();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images-icons/sadlogout.png',
                  width: 80, height: 80),
              const SizedBox(height: 15),
              const Text('Logout Confirmation',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  )),
              const SizedBox(height: 10),
              const Text('Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14)),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF046EB8)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('No',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF046EB8))),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Yes',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
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
      builder: (_) => MemoryMatchRatingDialog(
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

            // Music Volume
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
                    value: _musicVol,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF046EB8),
                    inactiveColor: Colors.grey[300],
                    onChanged: _onMusicChanged,
                  ),
                ),
                SizedBox(
                  width: 35,
                  child: Text('${_musicVol.round()}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SFX Volume
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
                    value: _sfxVol,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF046EB8),
                    inactiveColor: Colors.grey[300],
                    onChanged: _onSfxChanged,
                  ),
                ),
                SizedBox(
                  width: 35,
                  child: Text('${_sfxVol.round()}',
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
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
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('Logout',
                    style: TextStyle(
                        fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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
}

// ---------------------------------------------------------------------------
// Rating Dialog
// ---------------------------------------------------------------------------

class MemoryMatchRatingDialog extends StatefulWidget {
  final String userId;
  final VoidCallback? onRatingSubmitted;

  const MemoryMatchRatingDialog({
    super.key,
    required this.userId,
    this.onRatingSubmitted,
  });

  @override
  State<MemoryMatchRatingDialog> createState() =>
      _MemoryMatchRatingDialogState();
}

class _MemoryMatchRatingDialogState extends State<MemoryMatchRatingDialog> {
  int _rating = 0;
  String _feedback = '';
  bool _isSubmitting = false;

  Future<void> _submit() async {
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
      widget.onRatingSubmitted?.call();
      if (mounted) {
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
            const Icon(Icons.star_rounded, color: Color(0xFFFDD000), size: 60),
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
                  fontFamily: 'Poppins', fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Later',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
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
                                  Color(0xFF816A03)),
                            ),
                          )
                        : const Text('Submit',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold)),
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

// ---------------------------------------------------------------------------
// Logout helper used by the main widget
// ---------------------------------------------------------------------------

Future<void> performLogout(BuildContext context) async {
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