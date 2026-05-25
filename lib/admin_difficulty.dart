import 'package:flutter/material.dart';
import 'api_service.dart';
import 'difficulty_settings_service.dart';

class AdminQuizDifficultyPage extends StatefulWidget {
  const AdminQuizDifficultyPage({super.key});

  @override
  State<AdminQuizDifficultyPage> createState() =>
      _AdminQuizDifficultyPageState();
}

class _AdminQuizDifficultyPageState extends State<AdminQuizDifficultyPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  // Difficulty settings loaded from API
  Map<String, Map<String, int>> difficultySettings = {
    'Easy':      {'questions': 10, 'time': 15},
    'Average':   {'questions': 10, 'time': 20},
    'Difficult': {'questions': 10, 'time': 25},
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _api.getDifficultySettings();

    if (!mounted) return;

    if (result['success'] == true) {
      final settings = result['settings'] as Map<String, dynamic>;
      final updated = <String, Map<String, int>>{};

      for (final level in ['Easy', 'Average', 'Difficult']) {
        if (settings.containsKey(level)) {
          final s = settings[level] as Map<String, dynamic>;
          updated[level] = {
            'questions': (s['num_questions'] as num?)?.toInt() ?? 10,
            'time':      (s['time_per_qn'] as num?)?.toInt() ?? 15,
          };
        }
      }

      setState(() {
        difficultySettings = updated.isNotEmpty ? updated : difficultySettings;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'] ?? 'Failed to load settings.';
      });
    }
  }

  void _showEditDialog(String difficulty) {
    final settings = difficultySettings[difficulty]!;
    final questionsController =
    TextEditingController(text: settings['questions'].toString());
    final timeController =
    TextEditingController(text: settings['time'].toString());

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit, color: Color(0xFF046EB8), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        difficulty,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInputField('No. of Questions', questionsController),
                  const SizedBox(height: 16),
                  _buildTimeField('Time per Question (seconds)', timeController),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF046EB8),
                          side: const BorderSide(color: Color(0xFF046EB8)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text('Close', style: TextStyle(fontFamily: 'Poppins')),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                          final numQ =
                              int.tryParse(questionsController.text) ??
                                  settings['questions']!;
                          final timeQ =
                              int.tryParse(timeController.text) ??
                                  settings['time']!;

                          setDialogState(() => isSaving = true);

                          final result =
                          await _api.updateDifficultySettings(
                            difficulty,
                            numQuestions: numQ,
                            timePerQn: timeQ,
                          );

                          if (!context.mounted) return;
                          setDialogState(() => isSaving = false);

                          if (result['success'] == true) {
                            setState(() {
                              difficultySettings[difficulty] = {
                                'questions': numQ,
                                'time': timeQ,
                              };
                            });
                            // Immediately update singleton so quiz_game.dart uses new values
                            DifficultySettingsService.instance.update(
                              difficulty,
                              questions: numQ,
                              time: timeQ,
                            );
                            Navigator.of(context).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '$difficulty settings updated!'),
                                  backgroundColor:
                                  const Color(0xFF27AE60),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(8)),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ??
                                    'Update failed.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF046EB8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF816A03)))
                            : const Text('SAVE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontFamily: 'Poppins')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.grey)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFF046EB8))),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontFamily: 'Poppins')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.access_time, color: Colors.grey),
            suffixText: 's',
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.grey)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.grey)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFF046EB8))),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        color: const Color(0xFF94D2FD),
        child: LayoutBuilder(builder: (context, bc) {
          final pad = bc.maxWidth < 500 ? 12.0 : 24.0;
          return Padding(padding: EdgeInsets.all(pad), child: Column(
            children: [
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final hPad = constraints.maxWidth < 600 ? 16.0 : 40.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Difficulty Settings',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF051525),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        IconButton(
                          onPressed: _loadSettings,
                          icon: const Icon(Icons.refresh, size: 20),
                          style: IconButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: const CircleBorder(),
                            backgroundColor: Colors.white,
                          ),
                          tooltip: 'Refresh settings',
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              Expanded(
                child: _isLoading
                    ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF046EB8)))
                    : _errorMessage != null
                    ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              fontFamily: 'Poppins', color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSettings,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF046EB8)),
                        child: const Text('Retry',
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins')),
                      ),
                    ],
                  ),
                )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    if (isNarrow) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildDifficultyCard('Easy', difficultySettings['Easy']!, Colors.green),
                            const SizedBox(height: 16),
                            _buildDifficultyCard('Average', difficultySettings['Average']!, Colors.blue),
                            const SizedBox(height: 16),
                            _buildDifficultyCard('Difficult', difficultySettings['Difficult']!, Colors.red),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDifficultyCard('Easy', difficultySettings['Easy']!, Colors.green)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDifficultyCard('Average', difficultySettings['Average']!, Colors.blue)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDifficultyCard('Difficult', difficultySettings['Difficult']!, Colors.red)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ));
        }));
  }

  Widget _buildDifficultyCard(
      String title, Map<String, int> settings, Color accentColor) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colored top accent bar
            Container(
              height: 5,
              color: accentColor,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      'DIFFICULTY',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: accentColor,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ]),
                  GestureDetector(
                    onTap: () => _showEditDialog(title),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit, color: accentColor, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F4F8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: Column(
                children: [
                  _buildInfoRow('Questions', settings['questions'].toString(),
                      Icons.help_outline_rounded, accentColor),
                  const SizedBox(height: 16),
                  _buildInfoRow('Time / Q', '${settings['time']}s',
                      Icons.access_time_rounded, accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Poppins')),
          ],
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF051525),
                fontFamily: 'Poppins')),
      ],
    );
  }
}