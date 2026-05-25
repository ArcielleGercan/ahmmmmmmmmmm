import 'audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:confetti/confetti.dart';
import 'config.dart';

class PlayerBadgesDialog extends StatefulWidget {
  final String playerId;
  final String baseUrl;

  PlayerBadgesDialog({
    super.key,
    required this.playerId,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.baseUrl;

  @override
  State<PlayerBadgesDialog> createState() => _PlayerBadgesDialogState();
}

class _PlayerBadgesDialogState extends State<PlayerBadgesDialog> {
  bool isLoading = true;
  Map<String, dynamic>? badgeData;
  Map<String, List<dynamic>> unclaimedBadges = {
    'easy': [],
    'average': [],
    'difficult': [],
  };
  String? errorMessage;

  final Map<String, String> badgeImages = {
    "easy": "assets/images-badges/whiz-ready.png",
    "average": "assets/images-badges/whiz-happy.png",
    "difficult": "assets/images-badges/whiz-achiever.png",
  };

  final Map<String, Color> badgeColors = {
    "easy": const Color(0xFF1D9358),
    "average": const Color(0xFF046EB8),
    "difficult": const Color(0xFFBD442E),
  };

  @override
  void initState() {
    super.initState();
    _fetchPlayerBadges();
  }

  Future<void> _fetchPlayerBadges() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      debugPrint('🔍 Fetching badges for player: ${widget.playerId}');

      final summaryUrl = '${widget.baseUrl}/badges/player/${widget.playerId}/summary';
      final unclaimedUrl = '${widget.baseUrl}/badges/player/${widget.playerId}/unclaimed';

      debugPrint('Summary URL: $summaryUrl');
      debugPrint('Unclaimed URL: $unclaimedUrl');

      final summaryResponse = await http.get(
        Uri.parse(summaryUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('timeout');
        },
      );

      debugPrint('Summary response status: ${summaryResponse.statusCode}');
      debugPrint('Summary response body: ${summaryResponse.body}');

      final unclaimedResponse = await http.get(
        Uri.parse(unclaimedUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('timeout');
        },
      );

      debugPrint('Unclaimed response status: ${unclaimedResponse.statusCode}');
      debugPrint('Unclaimed response body: ${unclaimedResponse.body}');

      if (summaryResponse.statusCode == 200 && unclaimedResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);
        final unclaimedData = json.decode(unclaimedResponse.body);

        if (summaryData['success'] && unclaimedData['success']) {
          setState(() {
            badgeData = summaryData['data'];

            // Parse unclaimed badges properly
            final unclaimedDataMap = unclaimedData['data'] as Map<String, dynamic>;
            unclaimedBadges = {
              'easy': (unclaimedDataMap['easy'] as List<dynamic>?) ?? [],
              'average': (unclaimedDataMap['average'] as List<dynamic>?) ?? [],
              'difficult': (unclaimedDataMap['difficult'] as List<dynamic>?) ?? [],
            };

            isLoading = false;
          });

          debugPrint('✅ Badges loaded successfully');
          debugPrint('Badge data: $badgeData');
          debugPrint('Unclaimed badges - Easy: ${unclaimedBadges['easy']?.length}');
          debugPrint('Unclaimed badges - Average: ${unclaimedBadges['average']?.length}');
          debugPrint('Unclaimed badges - Difficult: ${unclaimedBadges['difficult']?.length}');

          if (badgeData != null && badgeData!['official_badges'] != null) {
            debugPrint('🏆 Official Badges Count:');
            debugPrint('   Easy: ${badgeData!['official_badges']['easy']}');
            debugPrint('   Average: ${badgeData!['official_badges']['average']}');
            debugPrint('   Difficult: ${badgeData!['official_badges']['difficult']}');
          }
        } else {
          setState(() {
            errorMessage = 'Failed to load badges: ${summaryData['message'] ?? unclaimedData['message']}';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Server error: Summary(${summaryResponse.statusCode}) Unclaimed(${unclaimedResponse.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading badges: $e');
      final msg = e.toString();
      String friendlyMessage;
      if (msg.contains('timeout')) {
        friendlyMessage = 'Could not connect to the server. Please check your connection and try again.';
      } else if (msg.contains('SocketException') || msg.contains('Failed to fetch') || msg.contains('NetworkException')) {
        friendlyMessage = 'No internet connection. Please check your network and try again.';
      } else {
        friendlyMessage = 'Something went wrong loading badges. Please try again.';
      }
      setState(() {
        errorMessage = friendlyMessage;
        isLoading = false;
      });
    }
  }



  void _showHowToEarnDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () async {
                      try {
                        await AudioService().playClickSound();
                      } catch (e) {
                        debugPrint('Click sound not found: $e');
                      }
                      Navigator.pop(context);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              // Title
              const Text(
                'Earn Epic Badges!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF046EB8),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Master challenges and unlock exclusive rewards',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 24),

              // Badge Preview
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBadgePreview(
                    'Easy',
                    'assets/images-badges/whiz-ready.png',
                    const Color(0xFF1D9358),
                  ),
                  const SizedBox(width: 16),
                  _buildBadgePreview(
                    'Average',
                    'assets/images-badges/whiz-happy.png',
                    const Color(0xFF046EB8),
                  ),
                  const SizedBox(width: 16),
                  _buildBadgePreview(
                    'Difficult',
                    'assets/images-badges/whiz-achiever.png',
                    const Color(0xFFBD442E),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // How to unlock section
              Column(
                children: [
                  Text(
                    'Unlock badges by:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Whiz Challenge Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildUnlockMethod(
                      icon: Icons.flash_on,
                      iconColor: const Color(0xFFFDD000),
                      title: 'Getting perfect scores in ',
                      highlight: 'Whiz Challenges',
                      highlightColor: const Color(0xFFFDD000),
                      description: '100% correct answers with no mistakes',
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Whiz Battles Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildUnlockMethod(
                      icon: Icons.emoji_events,
                      iconColor: const Color(0xFFC571E2),
                      title: 'Winning ',
                      highlight: 'Whiz Battles',
                      highlightColor: const Color(0xFFC571E2),
                      description: 'Compete and win against opponents',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Completion requirement text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Complete all 3 difficulty levels (Easy, Average, Difficult) to claim the ultimate rewards!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await AudioService().playClickSound();
                    } catch (e) {
                      debugPrint('Click sound not found: $e');
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDD000),
                    foregroundColor: const Color(0xFF816A03),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'GOT IT!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildBadgePreview(String label, String imagePath, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockMethod({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String highlight,
    required Color highlightColor,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(text: title),
                    TextSpan(
                      text: highlight,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: highlightColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _claimBadge(String difficulty) async {
    try {
      debugPrint('🎯 Attempting to claim badge for difficulty: $difficulty');

      final badgesList = unclaimedBadges[difficulty] ?? [];

      if (badgesList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No badge available to claim'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get the first unclaimed badge
      final badgeToClaim = badgesList.first;

      // ✅ Extract the badge ID properly
      String? rewardId;

      // Handle different possible formats
      if (badgeToClaim['_id'] is String) {
        rewardId = badgeToClaim['_id'] as String;
      } else if (badgeToClaim['_id'] is Map) {
        // Handle MongoDB ObjectId format
        final idMap = badgeToClaim['_id'] as Map;
        rewardId = idMap['\$oid']?.toString() ?? idMap['oid']?.toString();
      } else {
        rewardId = badgeToClaim['_id']?.toString();
      }

      debugPrint('📝 Extracted reward ID: $rewardId');

      if (rewardId == null || rewardId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid badge ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final claimUrl = '${widget.baseUrl}/badges/player/${widget.playerId}/claim';
      debugPrint('🌐 Claim URL: $claimUrl');
      debugPrint('📤 Sending reward_id: $rewardId');

      final response = await http.post(
        Uri.parse(claimUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'reward_id': rewardId,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout while claiming badge');
        },
      );

      debugPrint('✅ Claim response status: ${response.statusCode}');
      debugPrint('📄 Claim response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // Refresh badges
          await _fetchPlayerBadges();

          if (mounted) {
            final totalBadgesClaimed = badgeData?['official_badges']?[difficulty] ?? 1;

            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _ClaimSuccessDialog(
                difficulty: difficulty,
                borderColor: badgeColors[difficulty] ?? Colors.grey,
                badgeImage: badgeImages[difficulty] ?? "",
                totalBadgesClaimed: totalBadgesClaimed,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed: ${data['message'] ?? 'Unknown error'}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${errorData['message'] ?? 'Server error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error claiming badge: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming badge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _hasUnclaimedBadge(String difficulty) {
    final badges = unclaimedBadges[difficulty] ?? [];
    return badges.isNotEmpty;
  }

  int _getClaimedBadgeCount(String difficulty) {
    if (badgeData == null || badgeData!['official_badges'] == null) {
      debugPrint('⚠️ No badge data or official_badges for $difficulty');
      return 0;
    }

    final count = badgeData!['official_badges'][difficulty] ?? 0;
    debugPrint('🏆 Claimed badges for $difficulty: $count');
    return count;
  }

  Map<String, int> _getProgress(String difficulty) {
    if (badgeData == null || badgeData!['progress'] == null) {
      return {'current': 0, 'needed': 3, 'remaining': 3};
    }

    final progress = badgeData!['progress'][difficulty];
    if (progress == null) {
      return {'current': 0, 'needed': 3, 'remaining': 3};
    }

    return {
      'current': progress['current_count'] ?? 0,
      'needed': 3,
      'remaining': progress['remaining'] ?? 3,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 410, minHeight: 520, maxHeight: 520),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.red, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchPlayerBadges,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
                : Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadgeCategory("Easy", "easy"),
                    const SizedBox(height: 42),
                    _buildBadgeCategory("Average", "average"),
                    const SizedBox(height: 42),
                    _buildBadgeCategory("Difficult", "difficult"),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -74,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                "assets/images-badges/whiz-achiever.png",
                width: 220,
                height: 145,
              ),
            ),
          ),
          // Help button (?)
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.black),
              onPressed: () async {
                try {
                  await AudioService().playClickSound();
                } catch (e) {
                  debugPrint('Click sound not found: $e');
                }
                _showHowToEarnDialog();
              },
            ),
          ),
// Close button (X)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () async {
                try {
                  await AudioService().playClickSound();
                } catch (e) {
                  debugPrint('Click sound not found: $e');
                }
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCategory(String title, String difficulty) {
    if (badgeData == null) return const SizedBox.shrink();

    final progress = _getProgress(difficulty);
    final hasUnclaimed = _hasUnclaimedBadge(difficulty);
    final totalBadgesEarned = _getClaimedBadgeCount(difficulty);
    final borderColor = badgeColors[difficulty] ?? Colors.grey;
    final badgeImage = badgeImages[difficulty] ?? "";
    final currentInSet = progress['current']!;

    List<String?> badgePaths;
    if (hasUnclaimed) {
      badgePaths = [badgeImage, badgeImage, badgeImage];
    } else {
      badgePaths = List.generate(3, (i) => i < currentInSet ? badgeImage : null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: borderColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasUnclaimed
                    ? '3/3 - Ready!'
                    : '$currentInSet/3',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                ),
              ),
            ),
            const Spacer(),
            if (totalBadgesEarned > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'x$totalBadgesEarned',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(3, (i) {
              final path = badgePaths[i];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: path != null ? borderColor : Colors.grey.shade300,
                      width: 3,
                    ),
                    color: path == null ? Colors.grey.shade100 : null,
                  ),
                  child: path != null
                      ? ClipOval(
                          child: Image.asset(path, fit: BoxFit.contain))
                      : ClipOval(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      1, 0,
                            ]),
                            child: Opacity(
                              opacity: 0.45,
                              child: Image.asset(badgeImage, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton(
              onPressed: hasUnclaimed ? () async {
                try {
                  await AudioService().playClickSound();
                } catch (e) {
                  debugPrint('Click sound not found: $e');
                }
                _claimBadge(difficulty);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasUnclaimed
                    ? borderColor
                    : Colors.grey.shade300,
                foregroundColor: hasUnclaimed
                    ? Colors.white
                    : Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(hasUnclaimed ? "CLAIM!" : "LOCKED"),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClaimSuccessDialog extends StatefulWidget {
  final String difficulty;
  final Color borderColor;
  final String badgeImage;
  final int totalBadgesClaimed;

  const _ClaimSuccessDialog({
    required this.difficulty,
    required this.borderColor,
    required this.badgeImage,
    required this.totalBadgesClaimed,
  });

  @override
  State<_ClaimSuccessDialog> createState() => _ClaimSuccessDialogState();
}

class _ClaimSuccessDialogState extends State<_ClaimSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _textController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _textController.forward();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: -150,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: true,
            child: SizedBox(
              height: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return ConfettiWidget(
                    confettiController: ConfettiController(duration: const Duration(seconds: 3))..play(),
                    blastDirection: 3.14159 / 2,
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
        ),
        Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.borderColor, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.borderColor, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: widget.borderColor.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(widget.badgeImage, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_textAnimation),
                      child: Text(
                        'FANTASTIC!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: widget.borderColor,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _textAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: widget.borderColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.borderColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            color: widget.borderColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'You earned your '),
                                  TextSpan(
                                    text: '${widget.difficulty.toUpperCase()} BADGE #${widget.totalBadgesClaimed}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: widget.borderColor,
                                    ),
                                  ),
                                  const TextSpan(text: '!\nKeep collecting!'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await AudioService().playClickSound();
                          } catch (e) {
                            debugPrint('Click sound not found: $e');
                          }
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text(
                          'Continue Playing',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.borderColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
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
    );
  }
}