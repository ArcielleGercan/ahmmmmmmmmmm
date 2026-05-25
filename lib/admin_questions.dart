import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'api_service.dart';

class AdminQuizQuestionsPage extends StatefulWidget {
  const AdminQuizQuestionsPage({super.key});

  @override
  State<AdminQuizQuestionsPage> createState() => _AdminQuizQuestionsPageState();
}

class _AdminQuizQuestionsPageState extends State<AdminQuizQuestionsPage> {
  final ApiService _api = ApiService();

  bool isLoading = false;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  int itemsPerPage = 10;
  int currentPage = 1;
  int totalPages = 1;
  int totalItems = 0;

  String? selectedYearFilter;
  String? selectedCategoryFilter;
  String? selectedDifficultyFilter;

  String sortColumn = 'status';
  bool sortAscending = false; // desc: active (1) first, inactive (0) last

  List<Map<String, dynamic>> questionsData = [];

  static const Map<String, String> _yearLevelDisplay = {
    'ELEMENTARY': 'Elem (Grade 1–6)',
    'JUNIOR':     'Junior (Grade 7–10)',
    'SENIOR':     'Senior (Grade 11–12)',
  };
  static const Map<String, String> _yearLevelApi = {
    'Elem (Grade 1–6)':     'ELEMENTARY',
    'Junior (Grade 7–10)':  'JUNIOR',
    'Senior (Grade 11–12)': 'SENIOR',
  };

  static const List<String> _categories  = ['Math', 'Science'];
  static const List<String> _difficulties = ['Easy', 'Average', 'Difficult'];
  static const List<String> _yearLevels  = ['Elem (Grade 1–6)', 'Junior (Grade 7–10)', 'Senior (Grade 11–12)'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadQuestions({int? page}) async {
    if (page != null) setState(() => currentPage = page);
    setState(() => isLoading = true);

    final result = await _api.getQuestions(
      category:   selectedCategoryFilter,
      difficulty: selectedDifficultyFilter,
      yearLevel:  selectedYearFilter != null ? _yearLevelApi[selectedYearFilter] : null,
      search:     searchQuery.isEmpty ? null : searchQuery,
      sortBy:     sortColumn == 'yearLevel' ? 'year_level'
          : sortColumn == 'difficulty' ? 'difficulty_level'
          : sortColumn == 'status' ? 'is_active'
          : sortColumn,
      sortDir:    sortAscending ? 'asc' : 'desc',
      page:       currentPage,
      perPage:    itemsPerPage,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final raw = (result['questions'] as List<dynamic>? ?? [])
          .map((q) => _mapQuestion(q as Map<String, dynamic>))
          .toList();
      setState(() {
        questionsData = raw;
        totalPages    = result['total_pages'] ?? 1;
        totalItems    = result['total'] ?? 0;
        isLoading     = false;
      });
    } else {
      setState(() => isLoading = false);
      _snack(result['message'] ?? 'Failed to load questions.', Colors.red);
    }
  }

  Map<String, dynamic> _mapQuestion(Map<String, dynamic> q) => {
    'id':             q['id'],
    'question':       q['question'],
    'yearLevel':      _yearLevelDisplay[q['year_level']] ?? q['year_level'],
    'year_level_raw': q['year_level'],
    'category':       q['category'],
    'difficulty':     q['difficulty_level'],
    'correctAnswer':  q['correct_answer'],
    'choice_a':       q['choice_a'],
    'choice_b':       q['choice_b'],
    'choice_c':       q['choice_c'],
    'choice_d':       q['choice_d'],
    'image_url':      q['image_url'],
    'status':         (q['is_active'] ?? 1) == 1,
  };

  void _onSearch(String v) {
    setState(() { searchQuery = v; currentPage = 1; });
    _loadQuestions();
  }

  void _applyFilter() {
    setState(() => currentPage = 1);
    _loadQuestions();
  }

  void _clearFilters() {
    setState(() {
      selectedYearFilter       = null;
      selectedCategoryFilter   = null;
      selectedDifficultyFilter = null;
      searchQuery              = '';
      searchController.clear();
      currentPage              = 1;
    });
    _loadQuestions();
  }

  void _sortBy(String column) {
    setState(() {
      sortAscending = sortColumn == column ? !sortAscending : true;
      sortColumn    = column;
      currentPage   = 1;
    });
    _loadQuestions();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Toggle active/inactive ────────────────────────────────────────────────

  void _toggleStatus(Map<String, dynamic> q) async {
    final isActive = q['status'] as bool;
    // Show confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: (isActive ? Colors.red : Colors.green).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isActive ? Icons.visibility_off : Icons.visibility,
                  size: 26, color: isActive ? Colors.red : Colors.green),
            ),
            const SizedBox(height: 12),
            Text(isActive ? 'Deactivate Question?' : 'Restore Question?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'This question will no longer appear in the game.'
                  : 'This question will be active again in the game.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isActive ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: Text(isActive ? 'Deactivate' : 'Restore',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed != true) return;

    final result = isActive
        ? await _api.deleteQuestion(q['id'].toString())
        : await _api.restoreQuestion(q['id'].toString());

    if (!mounted) return;
    if (result['success'] == true) {
      _loadQuestions();
      _snack(isActive ? 'Question deactivated.' : 'Question restored.', isActive ? Colors.orange : const Color(0xFF27AE60));
    } else {
      _snack(result['message'] ?? 'Action failed.', Colors.red);
    }
  }

  // ── Permanent Delete ─────────────────────────────────────────────────────

  void _permanentDelete(Map<String, dynamic> q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever, size: 26, color: Colors.red),
            ),
            const SizedBox(height: 12),
            const Text('Delete Permanently?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(height: 8),
            Text('This cannot be undone. The question will be permanently removed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: const Text('Delete Forever', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed != true) return;
    final result = await _api.permanentDeleteQuestion(q['id'].toString());
    if (!mounted) return;
    if (result['success'] == true) {
      _loadQuestions();
      _snack('Question permanently deleted.', Colors.red);
    } else {
      _snack(result['message'] ?? 'Delete failed.', Colors.red);
    }
  }

  // ── Add / Edit Dialog ────────────────────────────────────────────────────

  void _showAddQuestionDialog()                         => _showQuestionDialog(null);
  void _showEditQuestionDialog(Map<String, dynamic> q)  => _showQuestionDialog(q);

  void _showQuestionDialog(Map<String, dynamic>? existing) {
    final isEdit = existing != null;

    final questionCtrl = TextEditingController(text: existing?['question'] ?? '');
    final choiceACtrl  = TextEditingController(text: existing?['choice_a'] ?? '');
    final choiceBCtrl  = TextEditingController(text: existing?['choice_b'] ?? '');
    final choiceCCtrl  = TextEditingController(text: existing?['choice_c'] ?? '');
    final choiceDCtrl  = TextEditingController(text: existing?['choice_d'] ?? '');

    // Per-choice image data URIs (base64 from file picker)
    String? imgA = existing?['choice_a_image'];
    String? imgB = existing?['choice_b_image'];
    String? imgC = existing?['choice_c_image'];
    String? imgD = existing?['choice_d_image'];
    String? questionImageData = existing?['question_image'];

    String selectedCategory   = existing?['category']       ?? 'Math';
    String selectedDifficulty = existing?['difficulty']     ?? 'Easy';
    String selectedYearLevel  = existing?['year_level_raw'] ?? 'ELEMENTARY';
    String? selectedCorrect   = existing?['correctAnswer'];

    bool isSaving = false;

    // Validation errors
    bool qErr = false, aErr = false, bErr = false, cErr = false, dErr = false, ansErr = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {
        // Helper: choice is valid if it has text OR an image
        List<String> validChoices() => [
          if (choiceACtrl.text.trim().isNotEmpty || imgA != null) 'A',
          if (choiceBCtrl.text.trim().isNotEmpty || imgB != null) 'B',
          if (choiceCCtrl.text.trim().isNotEmpty || imgC != null) 'C',
          if (choiceDCtrl.text.trim().isNotEmpty || imgD != null) 'D',
        ];

        String choiceLabel(String letter) {
          final ctrl = letter == 'A' ? choiceACtrl : letter == 'B' ? choiceBCtrl : letter == 'C' ? choiceCCtrl : choiceDCtrl;
          final img  = letter == 'A' ? imgA : letter == 'B' ? imgB : letter == 'C' ? imgC : imgD;
          final text = ctrl.text.trim();
          return text.isNotEmpty ? text : (img != null ? '[Image $letter]' : letter);
        }

        InputDecoration fieldDec(String hint, {bool hasError = false}) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: hasError ? Colors.red.shade300 : Colors.grey.shade400, fontFamily: 'Poppins'),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFF046EB8), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        );

        Widget choiceField(String letter, TextEditingController ctrl, Color color, bool hasError, String? imgData, Function(String?) onImageChanged) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                  onChanged: (value) {
                    setDS(() {
                      if (letter == 'A') { aErr = false; }
                      if (letter == 'B') { bErr = false; }
                      if (letter == 'C') { cErr = false; }
                      if (letter == 'D') { dErr = false; }
                      if (!validChoices().contains(selectedCorrect)) { selectedCorrect = null; }
                    });
                  },
                  decoration: fieldDec('Choice $letter', hasError: hasError).copyWith(
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Image file picker button
              Tooltip(
                message: imgData != null ? 'Change image' : 'Add image',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await _pickImageFile();
                      if (picked != null) setDS(() {
                        onImageChanged(picked);
                        if (!validChoices().contains(selectedCorrect)) selectedCorrect = null;
                      });
                    },
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: imgData != null ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: imgData != null ? color : Colors.grey.shade300,
                          width: imgData != null ? 1.5 : 1,
                        ),
                      ),
                      child: imgData != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(imgData, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, size: 20, color: color)),
                      )
                          : Icon(Icons.image_outlined, size: 20, color: Colors.grey.shade500),
                    ),
                  ),
                ),
              ),
              // Remove image button (only shown when image is set)
              if (imgData != null) ...[
                const SizedBox(width: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setDS(() => onImageChanged(null)),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle,
                          border: Border.all(color: Colors.red.shade200)),
                      child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                    ),
                  ),
                ),
              ],
            ]),
            if (hasError) const Padding(
              padding: EdgeInsets.only(left: 4, top: 3),
              child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Poppins')),
            ),
          ]);
        }

        Widget dropdownField(String label, String value, List<String> opts, ValueChanged<String?> onChange) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF444444), fontFamily: 'Poppins')),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: value,
              onChanged: onChange,
              items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)))).toList(),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF046EB8), width: 2)),
                isDense: true,
              ),
            ),
          ]);
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: SizedBox(
            width: 620,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header bar ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: BoxDecoration(
                  color: isEdit ? Colors.orange.withValues(alpha: 0.05) : const Color(0xFF046EB8).withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isEdit ? Colors.orange : const Color(0xFF046EB8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isEdit ? Icons.edit : Icons.add, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEdit ? 'Edit Question' : 'Add New Question',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    Text(isEdit ? 'Update the fields below.' : 'Fill in all fields to add a question.',
                        style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.grey.shade500)),
                  ]),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              // ── Body ──
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Classification row (top)
                  Row(children: [
                    Expanded(child: dropdownField('Category', selectedCategory, _categories,
                            (v) => setDS(() => selectedCategory = v!))),
                    const SizedBox(width: 12),
                    Expanded(child: dropdownField('Difficulty', selectedDifficulty, _difficulties,
                            (v) => setDS(() => selectedDifficulty = v!))),
                    const SizedBox(width: 12),
                    Expanded(child: dropdownField('Year Level', selectedYearLevel,
                        ['ELEMENTARY', 'JUNIOR', 'SENIOR'],
                            (v) => setDS(() => selectedYearLevel = v!))),
                  ]),
                  const SizedBox(height: 18),

                  // Question text
                  const Text('Question *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: questionCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                    onChanged: (_) => setDS(() => qErr = false),
                    decoration: fieldDec('Enter the question text...', hasError: qErr),
                  ),
                  if (qErr) const Padding(
                    padding: EdgeInsets.only(left: 4, top: 3),
                    child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Poppins')),
                  ),
                  const SizedBox(height: 18),

                  // Answer choices
                  const Text('Answer Choices *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: choiceField('A', choiceACtrl, const Color(0xFF046EB8), aErr, imgA, (v) => imgA = v)),
                    const SizedBox(width: 12),
                    Expanded(child: choiceField('B', choiceBCtrl, Colors.green, bErr, imgB, (v) => imgB = v)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: choiceField('C', choiceCCtrl, Colors.orange, cErr, imgC, (v) => imgC = v)),
                    const SizedBox(width: 12),
                    Expanded(child: choiceField('D', choiceDCtrl, Colors.red, dErr, imgD, (v) => imgD = v)),
                  ]),
                  const SizedBox(height: 18),

                  // Correct Answer — dropdown from the choices
                  Row(children: [
                    const Text('Correct Answer *',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: Color(0xFF1A1A1A))),
                    const SizedBox(width: 8),
                    Text('(select from choices above)',
                        style: TextStyle(fontSize: 11, fontFamily: 'Poppins', color: Colors.grey.shade500)),
                  ]),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: validChoices().contains(selectedCorrect) ? selectedCorrect : null,
                    hint: Text('Select the correct answer', style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: ansErr ? Colors.red.shade300 : Colors.grey.shade400)),
                    onChanged: (v) => setDS(() { selectedCorrect = v; ansErr = false; }),
                    items: validChoices().map((letter) => DropdownMenuItem(
                      value: letter,
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(choiceLabel(letter), style: const TextStyle(fontFamily: 'Poppins', fontSize: 13), overflow: TextOverflow.ellipsis)),
                      ]),
                    )).toList(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ansErr ? Colors.red : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: ansErr ? Colors.red : Colors.green, width: 2),
                      ),
                      isDense: true,
                    ),
                  ),
                  if (ansErr) const Padding(
                    padding: EdgeInsets.only(left: 4, top: 3),
                    child: Text('Select the correct answer', style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Poppins')),
                  ),
                  const SizedBox(height: 18),

                  // Question Image (optional) - file upload only
                ]),
              )),

              // ── Footer buttons ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: isSaving ? null : () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF046EB8),
                      side: const BorderSide(color: Color(0xFF046EB8)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF816A03)))
                        : Icon(isEdit ? Icons.save_rounded : Icons.add, size: 18),
                    label: Text(isEdit ? 'SAVE CHANGES' : 'ADD QUESTION',
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFDD000),
                      foregroundColor: const Color(0xFF816A03),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    onPressed: isSaving ? null : () async {
                      // Validate — text OR image is sufficient for each choice
                      bool err = false;
                      if (questionCtrl.text.trim().isEmpty) { setDS(() => qErr = true); err = true; }
                      if (choiceACtrl.text.trim().isEmpty && imgA == null) { setDS(() => aErr = true); err = true; }
                      if (choiceBCtrl.text.trim().isEmpty && imgB == null) { setDS(() => bErr = true); err = true; }
                      if (choiceCCtrl.text.trim().isEmpty && imgC == null) { setDS(() => cErr = true); err = true; }
                      if (choiceDCtrl.text.trim().isEmpty && imgD == null) { setDS(() => dErr = true); err = true; }
                      if (selectedCorrect == null) { setDS(() => ansErr = true); err = true; }
                      if (err) { _snack('Please fill in all required fields.', Colors.red); return; }

                      // Map letter back to actual text value
                      String correctAnswerValue;
                      switch (selectedCorrect) {
                        case 'A': correctAnswerValue = choiceACtrl.text.trim().isNotEmpty ? choiceACtrl.text.trim() : 'A'; break;
                        case 'B': correctAnswerValue = choiceBCtrl.text.trim().isNotEmpty ? choiceBCtrl.text.trim() : 'B'; break;
                        case 'C': correctAnswerValue = choiceCCtrl.text.trim().isNotEmpty ? choiceCCtrl.text.trim() : 'C'; break;
                        case 'D': correctAnswerValue = choiceDCtrl.text.trim().isNotEmpty ? choiceDCtrl.text.trim() : 'D'; break;
                        default:  correctAnswerValue = selectedCorrect!;
                      }

                      setDS(() => isSaving = true);
                      final payload = {
                        'question':         questionCtrl.text.trim(),
                        'choice_a':         choiceACtrl.text.trim(),
                        'choice_b':         choiceBCtrl.text.trim(),
                        'choice_c':         choiceCCtrl.text.trim(),
                        'choice_d':         choiceDCtrl.text.trim(),
                        'correct_answer':   correctAnswerValue,
                        'category':         selectedCategory,
                        'difficulty_level': selectedDifficulty,
                        'year_level':       selectedYearLevel,
                        if (questionImageData != null) 'question_image': questionImageData,
                        if (imgA != null) 'choice_a_image': imgA,
                        if (imgB != null) 'choice_b_image': imgB,
                        if (imgC != null) 'choice_c_image': imgC,
                        if (imgD != null) 'choice_d_image': imgD,
                      };

                      final result = isEdit
                          ? await _api.updateQuestion((existing as Map<String, dynamic>)['id'].toString(), payload)
                          : await _api.addQuestion(payload);

                      if (!ctx.mounted) return;
                      setDS(() => isSaving = false);

                      if (result['success'] == true) {
                        Navigator.pop(ctx);
                        _loadQuestions();
                        _snack(isEdit ? 'Question updated!' : 'Question added!', const Color(0xFF27AE60));
                      } else {
                        _snack(result['message'] ?? 'Failed to save.', Colors.red);
                      }
                    },
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── CSV helpers ───────────────────────────────────────────────────────────

  /// Opens OS file picker and returns the image as a base64 data URI.
  Future<String?> _pickImageFile() async {
    final completer = Completer<String?>();
    final input = html.FileUploadInputElement();
    input.accept = 'image/png,image/jpeg,image/jpg,image/gif,image/webp';
    input.onChange.listen((event) {
      final files = input.files;
      if (files == null || files.isEmpty) { completer.complete(null); return; }
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          completer.complete(result); // data URI: "data:image/png;base64,..."
        } else {
          completer.complete(null);
        }
      });
      reader.readAsDataUrl(file);
    });
    input.click();
    return completer.future;
  }

  /// Opens OS file picker and returns the CSV text content.
  Future<({String name, String content})?> _pickCsvFile() async {
    final completer = Completer<({String name, String content})?>();
    final input = html.FileUploadInputElement();
    input.accept = '.csv,text/csv';
    input.onChange.listen((event) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          completer.complete((name: file.name, content: result));
        } else {
          completer.complete(null);
        }
      });
      reader.readAsText(file);
    });
    input.click();
    return completer.future;
  }

  /// Triggers a browser download of [content] as a CSV file.
  void _triggerDownload(String content, String filename) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  /// Parses CSV text into rows, respecting double-quoted fields.
  List<List<String>> _parseCsvContent(String raw) {
    final result = <List<String>>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final cols = <String>[];
      bool inQuotes = false;
      final buf = StringBuffer();
      for (int i = 0; i < trimmed.length; i++) {
        final ch = trimmed[i];
        if (ch == '"') {
          inQuotes = !inQuotes;
        } else if (ch == ',' && !inQuotes) {
          cols.add(buf.toString().trim());
          buf.clear();
        } else {
          buf.write(ch);
        }
      }
      cols.add(buf.toString().trim());
      result.add(cols);
    }
    return result;
  }

  // ── Import CSV Dialog ─────────────────────────────────────────────────────

  void _showImportDialog() {
    String? pickedFileName;
    String? csvContent;
    bool isDragOver = false;
    bool importing = false;
    int imported = 0;
    int failed = 0;
    List<String> failedRows = [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {

        Future<void> pickFile() async {
          final picked = await _pickCsvFile();
          if (picked == null) return;
          setDS(() {
            pickedFileName = picked.name;
            csvContent = picked.content;
            imported = 0;
            failed = 0;
            failedRows = [];
          });
        }

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: SizedBox(
            width: 640,
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                    child: const Icon(Icons.upload_file, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Import Questions from CSV',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    Text('Pick or drag a .csv file to upload questions in bulk',
                        style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: Colors.grey.shade500)),
                  ]),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              // ── Body ──
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Format info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF046EB8)),
                        SizedBox(width: 6),
                        Text('Required CSV Column Order',
                            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF046EB8))),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'question, choice_a, choice_b, choice_c, choice_d, correct_answer, category, difficulty_level, year_level\n\n'
                            'Example:\nWhat is 2+2?,3,4,5,6,4,Math,Easy,ELEMENTARY',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Drop zone
                  DragTarget<Object>(
                    onWillAcceptWithDetails: (_) { setDS(() => isDragOver = true); return true; },
                    onLeave: (_) => setDS(() => isDragOver = false),
                    onAcceptWithDetails: (_) => setDS(() => isDragOver = false),
                    builder: (_, __, ___) => GestureDetector(
                      onTap: pickFile,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        decoration: BoxDecoration(
                          color: isDragOver
                              ? Colors.purple.withValues(alpha: 0.08)
                              : pickedFileName != null
                              ? Colors.green.withValues(alpha: 0.05)
                              : Colors.grey.withValues(alpha: 0.04),
                          border: Border.all(
                            color: isDragOver
                                ? Colors.purple
                                : pickedFileName != null
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: isDragOver ? 2 : 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            pickedFileName != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            size: 52,
                            color: pickedFileName != null
                                ? Colors.green
                                : Colors.purple.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 12),
                          if (pickedFileName != null) ...[
                            Text(pickedFileName!,
                                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600,
                                    fontSize: 14, color: Colors.green)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => setDS(() {
                                pickedFileName = null; csvContent = null;
                                imported = 0; failed = 0; failedRows = [];
                              }),
                              child: const Text('Remove file',
                                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.red)),
                            ),
                          ] else ...[
                            const Text('Drag & drop your CSV file here',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
                                    fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 6),
                            Text('or', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade500)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.folder_open_rounded, size: 18),
                              label: const Text('Browse File',
                                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('.csv files only',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.grey.shade400)),
                          ],
                        ]),
                      ),
                    ),
                  ),

                  // Results
                  if (imported > 0 || failed > 0) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      if (imported > 0) Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade200)),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Text('$imported imported',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                                  fontWeight: FontWeight.w600, color: Colors.green)),
                        ]),
                      )),
                      if (imported > 0 && failed > 0) const SizedBox(width: 10),
                      if (failed > 0) Expanded(child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200)),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text('$failed failed',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                                  fontWeight: FontWeight.w600, color: Colors.red)),
                        ]),
                      )),
                    ]),
                    if (failedRows.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Failed rows:',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                                  fontWeight: FontWeight.w600, color: Colors.red)),
                          const SizedBox(height: 4),
                          ...failedRows.take(5).map((r) => Text('• $r',
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.red),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (failedRows.length > 5)
                            Text('... and ${failedRows.length - 5} more',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.red)),
                        ]),
                      ),
                    ],
                  ],
                ]),
              )),

              // ── Footer ──
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      const header = 'question,choice_a,choice_b,choice_c,choice_d,correct_answer,category,difficulty_level,year_level\n';
                      const example = 'What is 2+2?,3,4,5,6,4,Math,Easy,ELEMENTARY\n';
                      _triggerDownload(header + example, 'quiz_template.csv');
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download Template',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: importing ? null : () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF046EB8),
                      side: const BorderSide(color: Color(0xFF046EB8)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: importing
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(importing ? 'Importing...' : 'IMPORT',
                        style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.purple.withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                    onPressed: (importing || csvContent == null) ? null : () async {
                      final rows = _parseCsvContent(csvContent!);
                      final dataRows = rows.isNotEmpty &&
                          rows.first.first.toLowerCase() == 'question'
                          ? rows.skip(1).toList()
                          : rows;

                      if (dataRows.isEmpty) {
                        _snack('No data rows found in the CSV.', Colors.orange);
                        return;
                      }

                      setDS(() { importing = true; imported = 0; failed = 0; failedRows = []; });

                      for (final cols in dataRows) {
                        if (cols.length < 9) {
                          setDS(() { failed++; failedRows.add(cols.join(',')); });
                          continue;
                        }
                        final payload = {
                          'question':         cols[0],
                          'choice_a':         cols[1],
                          'choice_b':         cols[2],
                          'choice_c':         cols[3],
                          'choice_d':         cols[4],
                          'correct_answer':   cols[5],
                          'category':         cols[6],
                          'difficulty_level': cols[7],
                          'year_level':       cols[8],
                        };
                        final res = await _api.addQuestion(payload);
                        setDS(() {
                          if (res['success'] == true) {
                            imported++;
                          } else {
                            failed++;
                            failedRows.add(cols.join(','));
                          }
                        });
                      }

                      setDS(() => importing = false);
                      if (ctx.mounted && imported > 0) _loadQuestions();
                    },
                  ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  // ── Export CSV ────────────────────────────────────────────────────────────

  Future<void> _exportCsv() async {
    _snack('Fetching questions for export...', const Color(0xFF046EB8));

    final result = await _api.getQuestions(
      category:   selectedCategoryFilter,
      difficulty: selectedDifficultyFilter,
      yearLevel:  selectedYearFilter != null ? _yearLevelApi[selectedYearFilter] : null,
      search:     searchQuery.isEmpty ? null : searchQuery,
      page:       1,
      perPage:    99999,
    );

    if (result['success'] != true) {
      _snack('Export failed: ${result['message']}', Colors.red);
      return;
    }

    final questions = (result['questions'] as List<dynamic>? ?? [])
        .map((q) => q as Map<String, dynamic>)
        .toList();

    if (questions.isEmpty) {
      _snack('No questions to export.', Colors.orange);
      return;
    }

    String esc(dynamic v) {
      final s = (v ?? '').toString();
      return s.contains(',') || s.contains('"') || s.contains('\n')
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    final buf = StringBuffer();
    buf.writeln('question,choice_a,choice_b,choice_c,choice_d,correct_answer,category,difficulty_level,year_level,status');
    for (final q in questions) {
      buf.writeln([
        esc(q['question']),  esc(q['choice_a']),  esc(q['choice_b']),
        esc(q['choice_c']),  esc(q['choice_d']),  esc(q['correct_answer']),
        esc(q['category']),  esc(q['difficulty_level']), esc(q['year_level']),
        esc((q['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive'),
      ].join(','));
    }

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    _triggerDownload(buf.toString(), 'quiz_questions_$ts.csv');
    _snack('Exported ${questions.length} questions!', Colors.green);
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _sortIcon(String column) {
    if (sortColumn != column) return const Icon(Icons.unfold_more, size: 15, color: Colors.grey);
    return Icon(sortAscending ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        size: 15, color: const Color(0xFF046EB8));
  }

  Widget _filterDrop(String hint, String? value, List<String> options, ValueChanged<String?> onChange) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: value != null ? const Color(0xFF046EB8) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(25),
        color: value != null ? const Color(0xFF046EB8).withValues(alpha: 0.05) : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.grey.shade600)),
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: value != null ? const Color(0xFF046EB8) : Colors.grey),
          style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Color(0xFF046EB8)),
          isDense: true,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('All $hint', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87))),
            ...options.map((o) => DropdownMenuItem<String?>(value: o, child: Text(o, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87)))),
          ],
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _headerCell(String label, String column, {int flex = 2}) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _sortBy(column),
        child: Row(children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Poppins')),
          const SizedBox(width: 2),
          _sortIcon(column),
        ]),
      ),
    );
  }

  Widget _difficultyChip(String diff) {
    final color = diff == 'Easy' ? Colors.green : diff == 'Average' ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(diff, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Poppins', fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    );
  }

  Widget _buildTableHeader() => Container(
    color: const Color(0xFFF8F9FA),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      _headerCell('#', 'id', flex: 1),
      _headerCell('Question', 'question', flex: 5),
      _headerCell('Year Level', 'yearLevel', flex: 3),
      _headerCell('Category', 'category', flex: 2),
      _headerCell('Difficulty', 'difficulty', flex: 2),
      _headerCell('Status', 'status', flex: 2),
      const Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Poppins'))),
    ]),
  );

  Widget _buildTableRow(Map<String, dynamic> q, int index) {
    final isActive = q['status'] as bool;
    final rowNum = (currentPage - 1) * itemsPerPage + index + 1;
    return InkWell(
      onTap: () => _showEditQuestionDialog(q),
      hoverColor: const Color(0xFF046EB8).withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Expanded(flex: 1, child: Text('$rowNum', style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.black54))),
          Expanded(flex: 5, child: Text(q['question'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
          Expanded(flex: 3, child: Text(q['yearLevel'].toString(), style: const TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.black87))),
          Expanded(flex: 2, child: Text(q['category'].toString(), style: const TextStyle(fontSize: 13, fontFamily: 'Poppins'))),
          Expanded(flex: 2, child: _difficultyChip(q['difficulty'].toString())),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(fontSize: 12, color: isActive ? Colors.green : Colors.red, fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          )),
          Expanded(flex: 2, child: Row(children: [
            MouseRegion(cursor: SystemMouseCursors.click, child: IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.orange),
              tooltip: 'Edit',
              onPressed: () => _showEditQuestionDialog(q),
              constraints: const BoxConstraints(), padding: const EdgeInsets.all(6),
            )),
            const SizedBox(width: 2),
            MouseRegion(cursor: SystemMouseCursors.click, child: IconButton(
              icon: Icon(isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 18, color: isActive ? Colors.orange : Colors.green),
              tooltip: isActive ? 'Deactivate' : 'Restore',
              onPressed: () => _toggleStatus(q),
              constraints: const BoxConstraints(), padding: const EdgeInsets.all(6),
            )),
            const SizedBox(width: 2),
            MouseRegion(cursor: SystemMouseCursors.click, child: IconButton(
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
              tooltip: 'Delete Permanently',
              onPressed: () => _permanentDelete(q),
              constraints: const BoxConstraints(), padding: const EdgeInsets.all(6),
            )),
          ])),
        ]),
      ),
    );
  }

  Widget _buildPagination() {
    Widget pageBtn(int p) => GestureDetector(
      onTap: () => _loadQuestions(page: p),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: p == currentPage ? const Color(0xFF046EB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p == currentPage ? const Color(0xFF046EB8) : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text('$p', style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
          color: p == currentPage ? Colors.white : Colors.black87,
          fontWeight: p == currentPage ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );

    List<Widget> pages = [];
    for (int p = 1; p <= totalPages; p++) {
      if (p == 1 || p == totalPages || (p >= currentPage - 1 && p <= currentPage + 1)) {
        pages.add(pageBtn(p));
      } else if (p == currentPage - 2 || p == currentPage + 2) {
        pages.add(const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey))));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(children: [
        Text('Page $currentPage of $totalPages', style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13)),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            onPressed: currentPage > 1 ? () => _loadQuestions(page: currentPage - 1) : null,
            icon: Icon(Icons.chevron_left, color: currentPage > 1 ? Colors.black87 : Colors.grey.shade300),
            splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          ...pages,
          IconButton(
            onPressed: currentPage < totalPages ? () => _loadQuestions(page: currentPage + 1) : null,
            icon: Icon(Icons.chevron_right, color: currentPage < totalPages ? Colors.black87 : Colors.grey.shade300),
            splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ])),
        Row(children: [
          const Text('Show:', style: TextStyle(color: Colors.grey, fontFamily: 'Poppins', fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: itemsPerPage,
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87),
                isDense: true,
                items: [10, 25, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: (n) { if (n == null) return; setState(() { itemsPerPage = n; currentPage = 1; }); _loadQuestions(); },
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasFilters = selectedYearFilter != null || selectedCategoryFilter != null || selectedDifficultyFilter != null;

    return Container(
      color: const Color(0xFF94D2FD),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // ── Top header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(children: [
              const Icon(Icons.quiz_outlined, size: 28),
              const SizedBox(width: 12),
              const Text('Quiz Questions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF046EB8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('$totalItems total', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF046EB8))),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export CSV', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Import CSV', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _showAddQuestionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Question', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF046EB8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadQuestions,
                icon: const Icon(Icons.refresh, size: 20),
                style: IconButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: const CircleBorder()),
                tooltip: 'Refresh',
              ),
            ]),
          ),

          // ── Search + Filters ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(children: [
              // Search
              Expanded(child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(25)),
                child: Row(children: [
                  const Icon(Icons.search, color: Color(0xFF858585), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: searchController,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search questions...', hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14),
                      border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
                    ),
                    onChanged: _onSearch,
                  )),
                  if (searchQuery.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear, size: 18, color: Color(0xFF858585)),
                        onPressed: () { searchController.clear(); _onSearch(''); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
              )),
              const SizedBox(width: 10),
              _filterDrop('Year Level', selectedYearFilter, _yearLevels,
                      (v) { setState(() { selectedYearFilter = v; }); _applyFilter(); }),
              const SizedBox(width: 8),
              _filterDrop('Category', selectedCategoryFilter, _categories,
                      (v) { setState(() { selectedCategoryFilter = v; }); _applyFilter(); }),
              const SizedBox(width: 8),
              _filterDrop('Difficulty', selectedDifficultyFilter, _difficulties,
                      (v) { setState(() { selectedDifficultyFilter = v; }); _applyFilter(); }),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 15),
                  label: const Text('Clear', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
              ],
            ]),
          ),

          // ── Table ──
          Expanded(child: isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF046EB8)))
              : questionsData.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(hasFilters || searchQuery.isNotEmpty ? 'No questions match your filters.' : 'No questions yet.',
                style: TextStyle(fontFamily: 'Poppins', color: Colors.grey.shade500, fontSize: 15)),
            if (hasFilters || searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: _clearFilters, child: const Text('Clear filters', style: TextStyle(fontFamily: 'Poppins'))),
            ],
          ]))
              : Column(children: [
            _buildTableHeader(),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Expanded(child: ListView.separated(
              itemCount: questionsData.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, i) => _buildTableRow(questionsData[i], i),
            )),
            _buildPagination(),
          ]),
          ),
        ]),
      ),
    );
  }
}