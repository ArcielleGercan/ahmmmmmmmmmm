import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Single source of truth for all audio in the app.
/// Uses audioplayers only — flame_audio is NOT used anywhere.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer _musicPlayer = AudioPlayer();

  bool _isMusicEnabled = true;
  bool _isSfxEnabled   = true;
  bool _isInitialized  = false;
  String? _currentMusic;

  // For smooth transitions
  bool _isFading = false;
  double _currentVolume = 0.50; // Default music volume
  double _sfxVolume = 0.50;     // Default SFX volume

  // ── Asset map ────────────────────────────────────────────────────────────
  // IMPORTANT: homepage_music is .wav — everything else is .mp3
  static const Map<String, String> _assets = {
    'homepage':    'audio/homepage_music.wav',   // ← .wav not .mp3
    'battle':      'audio/battle_music.mp3',
    'puzzle':      'audio/puzzle_music.mp3',
    'memorymatch': 'audio/memorymatch_music.mp3',
    'quiz':        'audio/quiz_music1.mp3',      // ← Quiz/Challenge music
  };

  static const Map<String, double> _volumes = {
    'homepage':    0.50,  // ← INCREASED from 0.30 to 0.50
    'battle':      0.25,
    'puzzle':      0.25,
    'memorymatch': 0.25,
    'quiz':        0.25,  // ← Quiz music volume
  };

  // ── Initialise ───────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('🔧 AudioService: initializing...');
    try {
      await _resetMusicPlayer();
      _isInitialized = true;
      debugPrint('✅ AudioService: ready');
    } catch (e) {
      debugPrint('❌ AudioService init error: $e');
    }
  }

  Future<void> _resetMusicPlayer() async {
    try { await _musicPlayer.dispose(); } catch (_) {}
    _musicPlayer = AudioPlayer();
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _musicPlayer.onPlayerStateChanged.listen(
          (s) => debugPrint('🎵 music player → ${s.name}'),
    );
  }

  // ── Fade-in effect ───────────────────────────────────────────────────────
  Future<void> _fadeIn(double targetVolume, {int durationMs = 2000}) async {
    _isFading = true;
    const steps = 40;
    final stepDuration = durationMs ~/ steps;
    final volumeStep = targetVolume / steps;

    for (int i = 1; i <= steps; i++) {
      if (!_isFading) break;
      await _musicPlayer.setVolume(volumeStep * i);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    await _musicPlayer.setVolume(targetVolume);
    _isFading = false;
    _currentVolume = targetVolume;
  }

  // ── Fade-out effect ──────────────────────────────────────────────────────
  Future<void> _fadeOut({int durationMs = 1500}) async {
    _isFading = true;
    final currentVol = _currentVolume;  // Use tracked volume instead of getVolume()
    const steps = 30;
    final stepDuration = durationMs ~/ steps;
    final volumeStep = currentVol / steps;

    for (int i = steps; i >= 0; i--) {
      if (!_isFading) break;
      await _musicPlayer.setVolume(volumeStep * i);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }

    await _musicPlayer.setVolume(0);
    _isFading = false;
  }

  // ── Core internal play with fade-in ──────────────────────────────────────
  Future<void> _playMusic(String key, {bool fadeIn = true}) async {
    if (!_isMusicEnabled) {
      debugPrint('⚠️ Music disabled – skipping $key');
      return;
    }

    // Cancel any ongoing fade immediately
    _isFading = false;

    // Already playing correct track? Do nothing.
    if (_currentMusic == key && _musicPlayer.state == PlayerState.playing) {
      debugPrint('🎵 $key already playing');
      return;
    }

    final asset  = _assets[key]!;
    final targetVolume = _volumes[key] ?? 0.50;

    debugPrint('🎵 Starting $key → $asset (fade-in: $fadeIn)');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Fade out current music if playing
        if (_musicPlayer.state == PlayerState.playing && fadeIn) {
          await _fadeOut(durationMs: 1000);
        }

        await _musicPlayer.stop();

        // Start at volume 0 if fading in
        if (fadeIn) {
          await _musicPlayer.setVolume(0);
        } else {
          await _musicPlayer.setVolume(targetVolume);
        }

        await _musicPlayer.play(AssetSource(asset));
        _currentMusic = key;

        // Fade in
        if (fadeIn) {
          await _fadeIn(targetVolume, durationMs: 2000);
        } else {
          _currentVolume = targetVolume;
        }

        debugPrint('✅ $key music playing (attempt $attempt)');
        return;
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed for $key: $e');
        if (attempt < 3) {
          await _resetMusicPlayer();
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
    }

    debugPrint('❌ All 3 attempts failed for $key');
  }

  // ── Public music API ─────────────────────────────────────────────────────
  Future<void> playHomepageMusic({bool fadeIn = true}) => _playMusic('homepage', fadeIn: fadeIn);
  Future<void> playBattleMusic({bool fadeIn = true})   => _playMusic('battle', fadeIn: fadeIn);
  Future<void> playPuzzleMusic({bool fadeIn = true})   => _playMusic('puzzle', fadeIn: fadeIn);
  Future<void> playMemoryMatchMusic({bool fadeIn = true}) => _playMusic('memorymatch', fadeIn: fadeIn);
  Future<void> playQuizMusic({bool fadeIn = true})     => _playMusic('quiz', fadeIn: fadeIn);

  Future<void> stopMusic() async {
    _isFading = false; // Cancel any active fade loop immediately
    try {
      await _musicPlayer.setVolume(0);
      await _musicPlayer.stop();
      _currentMusic = null;
      _currentVolume = 0;
    } catch (e) {
      debugPrint('❌ stopMusic: $e');
    }
  }

  // Smooth fade-out then stop — use this before every navigation away
  Future<void> fadeOutAndStop({int durationMs = 1000}) async {
    await _fadeOut(durationMs: durationMs);
    await stopMusic();
  }

  Future<void> pauseMusic() async {
    _isFading = false; // Cancel any active fade loop
    try {
      // ✅ Don't zero volume — just pause. resumeMusic() restores volume correctly.
      await _musicPlayer.pause();
    } catch (e) {
      debugPrint('❌ pauseMusic: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_isMusicEnabled) return;
    try {
      await _musicPlayer.resume();
      // ✅ Restore the correct volume after resume (in case it was at 0)
      final targetVolume = _currentMusic != null
          ? (_volumes[_currentMusic!] ?? _currentVolume)
          : _currentVolume;
      await _musicPlayer.setVolume(targetVolume);
      _currentVolume = targetVolume;
    } catch (_) {
      // If resume fails (source was released), replay the track
      if (_currentMusic != null) await _playMusic(_currentMusic!, fadeIn: false);
    }
  }

  // ── SFX ──────────────────────────────────────────────────────────────────
  // Spawns a fresh AudioPlayer per sound so concurrent SFX never cut each other off
  Future<void> _playSfx(String asset, {double? volume, Duration? startAt}) async {
    if (!_isSfxEnabled) return;
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release); // auto-dispose when done
      await player.play(AssetSource(asset), volume: volume ?? _sfxVolume);
      if (startAt != null) {
        await player.seek(startAt);
      }
    } catch (e) {
      debugPrint('❌ SFX $asset: $e');
      await player.dispose();
    }
    // Player disposes itself via ReleaseMode.release when playback ends
  }

  Future<void> playClickSound()         => _playSfx('audio/click1.wav');
  Future<void> playCorrectAnswerSound() => _playSfx('audio/correct_answer1.mp3', startAt: const Duration(milliseconds: 200));
  Future<void> playWrongAnswerSound()   => _playSfx('audio/wrong_answer1.mp3');
  Future<void> playWrongAnswer2Sound()  => _playSfx('audio/wrong_answer2.mp3');

  // ── Settings ─────────────────────────────────────────────────────────────
  void toggleMusic() {
    _isMusicEnabled = !_isMusicEnabled;
    // ✅ Use pause/resume (not stop) so the track position is preserved
    _isMusicEnabled ? resumeMusic() : pauseMusic();
  }

  void toggleSfx() {
    _isSfxEnabled = !_isSfxEnabled;
  }

  Future<void> setMusicVolume(double v) async {
    final clampedVolume = v.clamp(0.0, 1.0);
    _currentVolume = clampedVolume;
    await _musicPlayer.setVolume(clampedVolume);
  }

  /// Sets the volume applied to every SFX played after this call.
  /// Also enables/disables SFX based on whether value is 0.
  Future<void> setSfxVolume(double v) async {
    _sfxVolume = v.clamp(0.0, 1.0);
    // Enable SFX when volume > 0, disable when muted
    if (_sfxVolume == 0 && _isSfxEnabled) {
      _isSfxEnabled = false;
    } else if (_sfxVolume > 0 && !_isSfxEnabled) {
      _isSfxEnabled = true;
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  bool    get isMusicEnabled => _isMusicEnabled;
  bool    get isSfxEnabled   => _isSfxEnabled;
  String? get currentMusic   => _currentMusic;
  double  get currentVolume  => _currentVolume;
  double  get sfxVolume      => _sfxVolume;

  Future<void> dispose() async {
    _isFading = false;
    await _musicPlayer.dispose();
    _isInitialized = false;
  }
}