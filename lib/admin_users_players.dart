import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'loading_page.dart';

// ═══════════════════════════════════════════════════════════════
// REUSABLE SELECTION WIDGETS  (same as edit_profile.dart)
// ═══════════════════════════════════════════════════════════════

class _SelectionGridItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _SelectionGridItem({required this.label, required this.isSelected, required this.onTap});
  @override State<_SelectionGridItem> createState() => _SelectionGridItemState();
}
class _SelectionGridItemState extends State<_SelectionGridItem> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFFDD000) : _isHovered ? const Color(0xFFFDD000).withValues(alpha: 0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.isSelected ? const Color(0xFFFDD000) : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05), blurRadius: _isHovered ? 6 : 4, offset: const Offset(0, 2))],
          ),
          child: Center(child: Text(widget.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }
}

class _AvatarGridItem extends StatefulWidget {
  final String avatarName, avatarPath;
  final bool isSelected;
  final VoidCallback onTap;
  const _AvatarGridItem({required this.avatarName, required this.avatarPath, required this.isSelected, required this.onTap});
  @override State<_AvatarGridItem> createState() => _AvatarGridItemState();
}
class _AvatarGridItemState extends State<_AvatarGridItem> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected ? const Color(0xFFFDD000) : _isHovered ? const Color(0xFFFDD000).withValues(alpha: 0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.isSelected ? const Color(0xFFFDD000) : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05), blurRadius: _isHovered ? 6 : 4, offset: const Offset(0, 2))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset(widget.avatarPath, width: 50, height: 50, fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40, color: Color(0xFF046EB8))),
            const SizedBox(height: 4),
            Text(widget.avatarName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADMIN PLAYERS PAGE
// ═══════════════════════════════════════════════════════════════

class AdminPlayersPage extends StatefulWidget {
  const AdminPlayersPage({super.key});
  @override State<AdminPlayersPage> createState() => _AdminPlayersPageState();
}

class _AdminPlayersPageState extends State<AdminPlayersPage> {
  final ApiService _api = ApiService();
  static const String baseUrl = 'http://127.0.0.1:8000';

  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> playersData = [];
  bool isLoading = false;
  String? errorMessage;
  int currentPage = 1, perPage = 10, totalPages = 1, totalPlayers = 0;
  String searchQuery = '', sortBy = 'username';
  bool sortAscending = true;
  String? filterCategory, filterSex, filterStudentCategory;

  static const List<String> avatarPaths = [
    "assets/images-avatars/Adventurer.png", "assets/images-avatars/Astronaut.png",
    "assets/images-avatars/Boy.png",        "assets/images-avatars/Brainy.png",
    "assets/images-avatars/Cool-Monkey.png","assets/images-avatars/Cute-Elephant.png",
    "assets/images-avatars/Doctor-Boy.png", "assets/images-avatars/Doctor-Girl.png",
    "assets/images-avatars/Engineer-Boy.png","assets/images-avatars/Engineer-Girl.png",
    "assets/images-avatars/Girl.png",       "assets/images-avatars/Hacker.png",
    "assets/images-avatars/Leonel.png",     "assets/images-avatars/Scientist-Boy.png",
    "assets/images-avatars/Scientist-Girl.png","assets/images-avatars/Sly-Fox.png",
    "assets/images-avatars/Sneaky-Snake.png","assets/images-avatars/Teacher-Boy.png",
    "assets/images-avatars/Teacher-Girl.png","assets/images-avatars/Twirky.png", // cSpell:ignore Twirky
    "assets/images-avatars/Whiz-Achiever.png","assets/images-avatars/Whiz-Busy.png",
    "assets/images-avatars/Whiz-Happy.png", "assets/images-avatars/Whiz-Ready.png",
    "assets/images-avatars/Wise-Turtle.png",
  ];
  static List<String> get avatarNames => avatarPaths
      .map((p) => p.split('/').last.replaceAll('.png', '').replaceAll('-', ' ')).toList();

  @override void initState() { super.initState(); _loadPlayers(); }
  @override void dispose() { searchController.dispose(); super.dispose(); }

  // ─── API calls ────────────────────────────────────────────────────────────

  // ─── Location name cache (avoid re-fetching) ────────────────────────────
  // ignore: prefer_final_fields
  Map<String, String> _regionCache   = {};
  // ignore: prefer_final_fields
  Map<String, Map<String, String>> _provinceCache = {};
  // ignore: prefer_final_fields
  Map<String, Map<String, String>> _cityCache     = {};

  Future<void> _loadPlayers({int page = 1}) async {
    setState(() { isLoading = true; errorMessage = null; currentPage = page; });
    final r = await _api.getPlayers(
      search: searchQuery.isEmpty ? null : searchQuery,
      category: filterCategory, sex: filterSex,
      sortBy: sortBy, sortDir: sortAscending ? 'asc' : 'desc',
      page: page, perPage: perPage,
    );
    if (!mounted) return;
    if (r['success'] == true) {
      final raw = List<Map<String, dynamic>>.from(r['players'] ?? []);
      // Resolve any missing location names client-side
      final resolved = await _resolveAddresses(raw);
      if (!mounted) return;
      setState(() {
        playersData  = resolved;
        totalPages   = r['total_pages'] ?? 1;
        totalPlayers = r['total'] ?? 0;
        isLoading    = false;
      });
    } else {
      setState(() { errorMessage = r['message'] ?? 'Failed to load players.'; isLoading = false; });
    }
  }

  /// For each player missing region_name/province_name/city_name, resolve via API.
  Future<List<Map<String, dynamic>>> _resolveAddresses(List<Map<String, dynamic>> players) async {
    // Collect unique IDs that need resolving
    final needsRegion   = players.where((p) => (p['region_name'] == null || (p['region_name'] as String?)!.isEmpty) && p['region'] != null && p['region'].toString().isNotEmpty && p['region'].toString() != '0').map((p) => p['region'].toString()).toSet();
    final needsProvince = players.where((p) => (p['province_name'] == null || (p['province_name'] as String?)!.isEmpty) && p['province'] != null && p['province'].toString().isNotEmpty && p['province'].toString() != '0').map((p) => p['province'].toString()).toSet();
    final needsCity     = players.where((p) => (p['city_name'] == null || (p['city_name'] as String?)!.isEmpty) && p['city'] != null && p['city'].toString().isNotEmpty && p['city'].toString() != '0').map((p) => p['city'].toString()).toSet();

    if (needsRegion.isEmpty && needsProvince.isEmpty && needsCity.isEmpty) return players;

    // Fetch regions once and cache
    if (needsRegion.isNotEmpty && _regionCache.isEmpty) {
      try {
        final regions = await fetchRegions();
        _regionCache = { for (final r in regions) r['id']!: r['name']! };
      } catch (_) {}
    }

    // Fetch provinces per unique region
    for (final p in players) {
      final rid = p['region']?.toString() ?? '';
      if (rid.isEmpty || rid == '0') continue;
      if (!_provinceCache.containsKey(rid)) {
        try {
          final provinceList = await fetchProvinces(rid);
          _provinceCache[rid] = { for (final pv in provinceList) pv['id']!: pv['name']! };
        } catch (_) { _provinceCache[rid] = {}; }
      }
      final pid = p['province']?.toString() ?? '';
      if (pid.isEmpty || pid == '0') continue;
      if (!_cityCache.containsKey(pid)) {
        try {
          final cities = await fetchCities(pid);
          _cityCache[pid] = { for (final c in cities) c['id']!: c['name']! };
        } catch (_) { _cityCache[pid] = {}; }
      }
    }

    return players.map((p) {
      final result = Map<String, dynamic>.from(p);
      final rid = p['region']?.toString() ?? '';
      final pid = p['province']?.toString() ?? '';
      final cid = p['city']?.toString() ?? '';
      if ((result['region_name'] == null || (result['region_name'] as String?)!.isEmpty) && rid.isNotEmpty && rid != '0') {
        result['region_name'] = _regionCache[rid] ?? '';
      }
      if ((result['province_name'] == null || (result['province_name'] as String?)!.isEmpty) && rid.isNotEmpty && pid.isNotEmpty && pid != '0') {
        result['province_name'] = (_provinceCache[rid] ?? {})[pid] ?? '';
      }
      if ((result['city_name'] == null || (result['city_name'] as String?)!.isEmpty) && pid.isNotEmpty && cid.isNotEmpty && cid != '0') {
        result['city_name'] = (_cityCache[pid] ?? {})[cid] ?? '';
      }
      return result;
    }).toList();
  }

  void _refresh() => _loadPlayers(page: 1);

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
      backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ─── Location API ─────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> fetchRegions() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/region'));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map<Map<String, String>>((e) => {
          'id': e['id'].toString(),
          'name': (e['region_name'] ?? e['name']).toString(),
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> fetchProvinces(String regionId) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/province/$regionId'));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map<Map<String, String>>((e) => {
          'id': e['id'].toString(),
          'name': (e['province_name'] ?? e['name']).toString(),
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> fetchCities(String provinceId) async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/city/$provinceId'));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        return data.map<Map<String, String>>((e) => {
          'id': e['id'].toString(),
          'name': (e['city_name'] ?? e['name']).toString(),
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Shared UI helpers (EXACT match to edit_profile.dart) ────────────────

  InputDecoration _inputDecoration(String hint, {IconData? icon, bool hasError = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, fontFamily: "Poppins", color: hasError ? Colors.red.shade300 : null),
      prefixIcon: icon != null ? Icon(icon, size: 18, color: hasError ? Colors.red : null) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey, width: hasError ? 2 : 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFF046EB8), width: 2),
      ),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.red, width: 2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.red, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildTextField(IconData icon, String hint, {TextEditingController? controller, bool hasError = false, void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13, fontFamily: "Poppins"),
        decoration: _inputDecoration(hint, icon: icon, hasError: hasError),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildClickableField(String label, String? value, VoidCallback onTap, {bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: hasError ? Colors.red : Colors.grey, width: hasError ? 2 : 1),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(value ?? label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: value != null ? Colors.black : Colors.grey))),
                const Icon(Icons.arrow_drop_down, size: 20),
              ]),
            ),
          ),
        ),
        if (hasError)
          const Padding(padding: EdgeInsets.only(left: 12, top: 4), child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11))),
      ]),
    );
  }

  Widget _pageIndicator(int currentPage) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(
          color: currentPage == 0 ? const Color(0xFFFDD000) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Container(width: 40, height: 4, decoration: BoxDecoration(
          color: currentPage == 1 ? const Color(0xFFFDD000) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
    ]);
  }

  // ─── Avatar picker dialog (same as edit_profile.dart) ────────────────────

  void _showAvatarPickerDialog(BuildContext ctx, String? selectedAvatar, void Function(String) onSelected) {
    showDialog(context: ctx, builder: (dCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 500, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Choose Your Avatar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF046EB8))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dCtx)),
          ]),
          const SizedBox(height: 20),
          SizedBox(height: 400, child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
            itemCount: avatarPaths.length,
            itemBuilder: (_, i) => _AvatarGridItem(
              avatarName: avatarNames[i], avatarPath: avatarPaths[i],
              isSelected: selectedAvatar == avatarPaths[i],
              onTap: () { onSelected(avatarPaths[i]); Navigator.pop(dCtx); },
            ),
          )),
        ]),
      ),
    ));
  }

  // ─── Generic list picker (same style) ────────────────────────────────────

  void _showListPicker(BuildContext ctx, String title, List<String> items, String? current, void Function(String) onSelected) {
    showDialog(context: ctx, builder: (dCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 400, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF046EB8))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dCtx)),
          ]),
          const SizedBox(height: 20),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SelectionGridItem(label: item, isSelected: current == item, onTap: () { onSelected(item); Navigator.pop(dCtx); }),
          )),
        ]),
      ),
    ));
  }

  // ─── Location picker dialog ───────────────────────────────────────────────

  void _showLocationPicker(BuildContext ctx, String title, List<Map<String, String>> items, String? currentId, void Function(String id, String name) onSelected) {
    showDialog(context: ctx, builder: (dCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 400, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF046EB8))),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dCtx)),
          ]),
          const SizedBox(height: 20),
          SizedBox(height: 400, child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SelectionGridItem(label: items[i]['name']!, isSelected: currentId == items[i]['id'],
                  onTap: () { onSelected(items[i]['id']!, items[i]['name']!); Navigator.pop(dCtx); }),
            ),
          )),
        ]),
      ),
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // ADD PLAYER DIALOG — same 2-page format as edit_profile.dart
  // ═══════════════════════════════════════════════════════════════

  void _showAddPlayerDialog() {
    final usernameCtrl  = TextEditingController();
    final passwordCtrl  = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    final schoolCtrl    = TextEditingController();
    int page = 0;
    final pageCtrl = PageController();
    bool obscure = true, obscureConfirm = true, saving = false;

    String? selAvatar, selAge, selSex, selCat, selStudCat;
    String? selRegionId, selRegionName, selProvId, selProvName, selCityId, selCityName;

    bool usernameErr = false, passwordErr = false, schoolErr = false, ageErr = false, sexErr = false, avatarErr = false, confPwErr = false;
    bool catErr = false, studCatErr = false, regionErr = false, provErr = false, cityErr = false;

    List<Map<String, String>> regions = [], provinces = [], cities = [];

    showDialog(context: context, barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {

          // ── location pickers ──
          Future<void> pickRegion() async {
            if (regions.isEmpty) {
              LoadingHelper.showLoadingDialog(ctx, message: 'Loading regions...', width: 300, height: 200);
              regions = await fetchRegions();
              if (!ctx.mounted) return;
              LoadingHelper.hideLoading(ctx);
              setDS(() {});
            }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select Region', regions, selRegionId, (id, name) {
              setDS(() { selRegionId = id; selRegionName = name; selProvId = null; selProvName = null; selCityId = null; selCityName = null; provinces = []; cities = []; regionErr = false; });
            });
          }

          Future<void> pickProvince() async {
            if (selRegionId == null) { _snack('Please select a region first.', Colors.orange); return; }
            if (provinces.isEmpty) {
              LoadingHelper.showLoadingDialog(ctx, message: 'Loading provinces...', width: 300, height: 200);
              provinces = await fetchProvinces(selRegionId!);
              if (!ctx.mounted) return;
              LoadingHelper.hideLoading(ctx);
              setDS(() {});
            }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select Province', provinces, selProvId, (id, name) {
              setDS(() { selProvId = id; selProvName = name; selCityId = null; selCityName = null; cities = []; provErr = false; });
            });
          }

          Future<void> pickCity() async {
            if (selProvId == null) { _snack('Please select a province first.', Colors.orange); return; }
            if (cities.isEmpty) {
              LoadingHelper.showLoadingDialog(ctx, message: 'Loading cities...', width: 300, height: 200);
              cities = await fetchCities(selProvId!);
              if (!ctx.mounted) return;
              LoadingHelper.hideLoading(ctx);
              setDS(() {});
            }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select City', cities, selCityId, (id, name) {
              setDS(() { selCityId = id; selCityName = name; cityErr = false; });
            });
          }

          bool validatePage1() {
            bool err = false;
            final u = usernameCtrl.text.trim();
            if (u.isEmpty || u.length < 3 || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(u)) { setDS(() => usernameErr = true); err = true; }
            if (passwordCtrl.text.length < 8) { setDS(() => passwordErr = true); err = true; }
            if (confirmPwCtrl.text.isEmpty || confirmPwCtrl.text != passwordCtrl.text) { setDS(() => confPwErr = true); err = true; }
            if (selAge == null) { setDS(() => ageErr = true); err = true; }
            if (selSex == null) { setDS(() => sexErr = true); err = true; }
            if (selAvatar == null) { setDS(() => avatarErr = true); err = true; }
            if (err) _snack('Please fill in all required fields on this page.', Colors.red);
            return !err;
          }

          bool validatePage2() {
            bool err = false;
            if (schoolCtrl.text.trim().length < 2) { setDS(() => schoolErr = true); err = true; }
            if (selCat == null) { setDS(() => catErr = true); err = true; }
            if (selCat == 'Student' && selStudCat == null) { setDS(() => studCatErr = true); err = true; }
            if (selRegionId == null) { setDS(() => regionErr = true); err = true; }
            if (selProvId == null) { setDS(() => provErr = true); err = true; }
            if (selCityId == null) { setDS(() => cityErr = true); err = true; }
            if (err) _snack('Please fill in all required fields.', Colors.red);
            return !err;
          }

          // ── Page 1: Exact register.dart _buildPersonalInfoContent layout (30-70 split) ──
          Widget buildPage1() => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE — Avatar (flex 3, same as register.dart)
              Expanded(flex: 3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _showAvatarPickerDialog(ctx, selAvatar, (a) => setDS(() { selAvatar = a; avatarErr = false; })),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]),
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: avatarErr ? Colors.red : const Color(0xFFFDD000),
                        child: CircleAvatar(
                          radius: 67,
                          backgroundColor: Colors.white,
                          backgroundImage: selAvatar != null ? AssetImage(selAvatar!) : null,
                          child: selAvatar == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton(
                    onPressed: () => _showAvatarPickerDialog(ctx, selAvatar, (a) => setDS(() { selAvatar = a; avatarErr = false; })),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 2),
                    child: const Text("Select Avatar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (avatarErr) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11))),
              ])),
              const SizedBox(width: 20),
              // RIGHT SIDE — Form fields (flex 7, same as register.dart)
              Expanded(flex: 7, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _buildTextField(Icons.person, "Username", controller: usernameCtrl, hasError: usernameErr,
                    onChanged: (_) => setDS(() { usernameErr = false; })),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(
                  controller: passwordCtrl, obscureText: obscure,
                  style: const TextStyle(fontSize: 13, fontFamily: "Poppins"),
                  decoration: _inputDecoration("Password", icon: Icons.lock, hasError: passwordErr).copyWith(
                      suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 18, color: passwordErr ? Colors.red : null),
                          onPressed: () => setDS(() => obscure = !obscure))),
                  onChanged: (_) => setDS(() { passwordErr = false; confPwErr = false; }),
                )),
                Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TextField(
                  controller: confirmPwCtrl, obscureText: obscureConfirm,
                  style: const TextStyle(fontSize: 13, fontFamily: "Poppins"),
                  decoration: _inputDecoration("Confirm Password", icon: Icons.lock, hasError: confPwErr).copyWith(
                      suffixIcon: IconButton(icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off, size: 18, color: confPwErr ? Colors.red : null),
                          onPressed: () => setDS(() => obscureConfirm = !obscureConfirm))),
                  onChanged: (_) => setDS(() { confPwErr = false; }),
                )),
                const SizedBox(height: 6),
                Row(children: [
                  // Age field — inline like register.dart
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                      onTap: () => _showListPicker(ctx, "Select Age Range", ["0-12","13-17","18-22","23-29","30-39","40+"], selAge, (v) => setDS(() { selAge = v; ageErr = false; })),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ageErr ? Colors.red : Colors.grey, width: ageErr ? 2 : 1)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(selAge ?? "Age", style: TextStyle(fontSize: 13, color: selAge != null ? Colors.black : Colors.grey)),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ]),
                      ),
                    )),
                    if (ageErr) const Padding(padding: EdgeInsets.only(left: 12, top: 4), child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11))),
                  ])),
                  const SizedBox(width: 10),
                  // Sex field — inline like register.dart
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(
                      onTap: () => _showListPicker(ctx, "Select Sex", ["Male","Female","Prefer Not to Say"], selSex, (v) => setDS(() { selSex = v; sexErr = false; })),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sexErr ? Colors.red : Colors.grey, width: sexErr ? 2 : 1)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(selSex ?? "Sex", style: TextStyle(fontSize: 13, color: selSex != null ? Colors.black : Colors.grey)),
                          const Icon(Icons.arrow_drop_down, size: 20),
                        ]),
                      ),
                    )),
                    if (sexErr) const Padding(padding: EdgeInsets.only(left: 12, top: 4), child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11))),
                  ])),
                ]),
              ])),
            ],
          );

          // ── Page 2: Category + Location ──
          Widget buildPage2() => SingleChildScrollView(
            child: Column(children: [
              _buildTextField(Icons.school, "School / Institution", controller: schoolCtrl, hasError: schoolErr,
                  onChanged: (_) => setDS(() { schoolErr = false; })),
              const SizedBox(height: 6),
              _buildClickableField("Category", selCat,
                      () => _showListPicker(ctx, "Select Category", ["Student","Government Employee","Private Employee","Self-Employed","Not Employed","Others"], selCat,
                          (v) => setDS(() { selCat = v; catErr = false; if (v != 'Student') selStudCat = null; })),
                  hasError: catErr),
              if (selCat == 'Student')
                _buildClickableField("Student Category", selStudCat,
                        () => _showListPicker(ctx, "Select Student Category", ["Grade 1-6 (Elementary)","Grade 7-10 (Junior High)","Grade 11-12 (Senior High)","College","Graduate School"], selStudCat,
                            (v) => setDS(() { selStudCat = v; studCatErr = false; })),
                    hasError: studCatErr),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _buildClickableField("Region", selRegionName, () async => await pickRegion(), hasError: regionErr)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("Province", selProvName, () async => await pickProvince(), hasError: provErr)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("City", selCityName, () async => await pickCity(), hasError: cityErr)),
              ]),
            ]),
          );

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: Container(
              width: 700, height: 390,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(children: [
                // Header
                const Row(children: [
                  Icon(Icons.person_add, color: Colors.black, size: 24), SizedBox(width: 8),
                  Text('Add New Player', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                ]),
                const SizedBox(height: 8),
                Expanded(child: PageView(controller: pageCtrl, physics: const NeverScrollableScrollPhysics(),
                    children: [buildPage1(), buildPage2()])),
                const SizedBox(height: 6),
                _pageIndicator(page),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  if (page == 0)
                    TextButton(onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF046EB8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14), side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('Cancel'))
                  else
                    TextButton(onPressed: () { pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setDS(() => page = 0); },
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF046EB8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14), side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('Back')),
                  if (page == 0)
                    ElevatedButton(
                        onPressed: () { if (validatePage1()) { pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setDS(() => page = 1); } },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), textStyle: const TextStyle(fontFamily: "Poppins", fontSize: 13, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('NEXT'))
                  else
                    ElevatedButton(
                        onPressed: saving ? null : () async {
                          if (!validatePage2()) return;
                          setDS(() => saving = true);
                          LoadingHelper.showLoadingDialog(ctx, message: 'Adding player...', width: 300, height: 200);
                          // Map display category to backend enum value
                          String? backendCat = selCat == 'Student'
                              ? 'Student'
                              : (selCat == 'Others' || selCat == null)
                              ? 'Others'
                              : 'Employee'; // Government/Private/Self-Employed/Not Employed → Employee
                          final res = await _api.addPlayer({
                            'username': usernameCtrl.text.trim(), 'password': passwordCtrl.text,
                            'school': schoolCtrl.text.trim(), 'age': selAge, 'sex': selSex,
                            'category': backendCat,
                            if (selStudCat != null && selCat == 'Student') 'student_category': selStudCat,
                            'avatar': selAvatar,
                            'region': int.tryParse(selRegionId ?? '0') ?? 0,
                            'province': int.tryParse(selProvId ?? '0') ?? 0,
                            'city': int.tryParse(selCityId ?? '0') ?? 0,
                          });
                          if (!ctx.mounted) return;
                          LoadingHelper.hideLoading(ctx);
                          setDS(() => saving = false);
                          if (res['success'] == true) { Navigator.pop(ctx); _snack('Player added successfully!', const Color(0xFF27AE60)); _refresh(); }
                          else { _snack(res['message'] ?? 'Failed to add player.', Colors.red); }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), textStyle: const TextStyle(fontFamily: "Poppins", fontSize: 13, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('ADD PLAYER')),
                ]),
              ]),
            ),
          );
        }));
  }

  // ═══════════════════════════════════════════════════════════════
  // CHANGE PASSWORD DIALOG (standalone, opened from Edit dialog)
  // ═══════════════════════════════════════════════════════════════

  void _showChangePasswordDialog(Map<String, dynamic> player) {
    final currPwCtrl = TextEditingController();
    final newPwCtrl  = TextEditingController();
    final confPwCtrl = TextEditingController();
    bool obscureCurr = true, obscureNew = true, obscureConf = true;
    bool saving = false;
    bool currPwErr = false, newPwErr = false, confPwErr = false;

    showDialog(context: context, barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400, padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.vpn_key, color: Color(0xFF046EB8), size: 22), const SizedBox(width: 8),
                Expanded(child: Text('Change Password — ${player['username'] ?? ''}',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black))),
              ]),
              const SizedBox(height: 6),
              Text('Enter the current password and set a new one.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 18),
              // Current password
              TextField(controller: currPwCtrl, obscureText: obscureCurr,
                  onChanged: (_) => setDS(() => currPwErr = false),
                  decoration: _inputDecoration("Current Password", icon: Icons.lock, hasError: currPwErr).copyWith(
                      suffixIcon: IconButton(icon: Icon(obscureCurr ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDS(() => obscureCurr = !obscureCurr)))),
              const SizedBox(height: 10),
              // New password
              TextField(controller: newPwCtrl, obscureText: obscureNew,
                  onChanged: (_) => setDS(() => newPwErr = false),
                  decoration: _inputDecoration("New Password", icon: Icons.lock, hasError: newPwErr).copyWith(
                      suffixIcon: IconButton(icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDS(() => obscureNew = !obscureNew)))),
              const SizedBox(height: 10),
              // Confirm new password
              TextField(controller: confPwCtrl, obscureText: obscureConf,
                  onChanged: (_) => setDS(() => confPwErr = false),
                  decoration: _inputDecoration("Confirm New Password", icon: Icons.lock, hasError: confPwErr).copyWith(
                      suffixIcon: IconButton(icon: Icon(obscureConf ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setDS(() => obscureConf = !obscureConf)))),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft,
                  child: Text('Min. 8 chars with uppercase, lowercase, number & special character.',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Colors.grey.shade500))),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF046EB8),
                        side: const BorderSide(color: Color(0xFF046EB8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                    child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontSize: 13))),
                ElevatedButton(
                    onPressed: saving ? null : () async {
                      bool hasErr = false;
                      if (currPwCtrl.text.isEmpty) { setDS(() => currPwErr = true); hasErr = true; }
                      if (newPwCtrl.text.length < 8) { setDS(() => newPwErr = true); hasErr = true; }
                      if (!newPwCtrl.text.contains(RegExp(r'[A-Z]')) || !newPwCtrl.text.contains(RegExp(r'[a-z]')) ||
                          !newPwCtrl.text.contains(RegExp(r'[0-9]')) || !newPwCtrl.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                        setDS(() => newPwErr = true); hasErr = true;
                      }
                      if (newPwCtrl.text != confPwCtrl.text) { setDS(() => confPwErr = true); hasErr = true; }
                      if (hasErr) {
                        _snack('Please fill in all fields correctly.', Colors.red);
                        return;
                      }
                      setDS(() => saving = true);
                      LoadingHelper.showLoadingDialog(ctx, message: 'Updating password...', width: 300, height: 200);
                      final res = await _api.changePlayerPassword(
                        player['id'].toString(),
                        newPassword: newPwCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      LoadingHelper.hideLoading(ctx);
                      setDS(() => saving = false);
                      if (res['success'] == true) { Navigator.pop(ctx); _snack('Password changed successfully!', const Color(0xFF27AE60)); }
                      else { _snack(res['message'] ?? 'Failed to change password.', Colors.red); }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: const Text('CHANGE PASSWORD')),
              ]),
            ]),
          ),
        )));
  }

  // ═══════════════════════════════════════════════════════════════
  // EDIT PLAYER DIALOG — same 2-page layout as Add New Player
  // ═══════════════════════════════════════════════════════════════

  void _showEditPlayerDialog(Map<String, dynamic> player) async {
    LoadingHelper.showLoadingDialog(context, message: 'Loading player data...', width: 300, height: 200);

    // Pre-resolve existing location IDs → names
    final regionIdRaw   = player['region']?.toString();
    final provinceIdRaw = player['province']?.toString();
    final cityIdRaw     = player['city']?.toString();

    String? initRegionId = regionIdRaw, initRegionName;
    String? initProvId   = provinceIdRaw, initProvName;
    String? initCityId   = cityIdRaw,    initCityName;
    List<Map<String, String>> preRegions = [], preProvinces = [], preCities = [];

    try {
      if (regionIdRaw != null && regionIdRaw.isNotEmpty && regionIdRaw != 'null' && regionIdRaw != '0') {
        preRegions = await fetchRegions();
        final r = preRegions.firstWhere((e) => e['id'] == regionIdRaw, orElse: () => {'id': regionIdRaw, 'name': ''});
        initRegionName = r['name']!.isNotEmpty ? r['name'] : null;
        if (provinceIdRaw != null && provinceIdRaw.isNotEmpty && provinceIdRaw != 'null' && provinceIdRaw != '0') {
          preProvinces = await fetchProvinces(regionIdRaw);
          final p = preProvinces.firstWhere((e) => e['id'] == provinceIdRaw, orElse: () => {'id': provinceIdRaw, 'name': ''});
          initProvName = p['name']!.isNotEmpty ? p['name'] : null;
          if (cityIdRaw != null && cityIdRaw.isNotEmpty && cityIdRaw != 'null' && cityIdRaw != '0') {
            preCities = await fetchCities(provinceIdRaw);
            final c = preCities.firstWhere((e) => e['id'] == cityIdRaw, orElse: () => {'id': cityIdRaw, 'name': ''});
            initCityName = c['name']!.isNotEmpty ? c['name'] : null;
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    LoadingHelper.hideLoading(context);
    final usernameCtrl = TextEditingController(text: player['username'] ?? '');
    final schoolCtrl   = TextEditingController(text: player['school'] ?? '');

    int page = 0;
    final pageCtrl = PageController();

    String? selAvatar  = player['avatar'];
    String? selAge     = player['age'];
    String? selSex     = player['sex'];
    // Map backend category value back to display label for the picker
    String? rawCat = player['category'];
    String? selCat = rawCat == 'Employee'
        ? 'Government Employee' // default display for Employee
        : rawCat; // 'Student' and 'Others' match directly
    String? selStudCat = player['student_category'];
    String? selRegionId = initRegionId, selRegionName = initRegionName;
    String? selProvId   = initProvId,   selProvName   = initProvName;
    String? selCityId   = initCityId,   selCityName   = initCityName;

    bool saving = false, hasChanged = false;
    bool usernameErr = false, schoolErr = false, ageErr = false, sexErr = false, avatarErr = false;
    bool catErr = false, studCatErr = false, regionErr = false, provErr = false, cityErr = false;

    List<Map<String, String>> regions   = preRegions;
    List<Map<String, String>> provinces = preProvinces;
    List<Map<String, String>> cities    = preCities;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {

          Future<void> pickRegion() async {
            if (regions.isEmpty) { LoadingHelper.showLoadingDialog(ctx, message: 'Loading regions...', width: 300, height: 200); regions = await fetchRegions(); if (!ctx.mounted) return;
            LoadingHelper.hideLoading(ctx); setDS(() {}); }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select Region', regions, selRegionId, (id, name) { setDS(() { selRegionId = id; selRegionName = name; selProvId = null; selProvName = null; selCityId = null; selCityName = null; provinces = []; cities = []; regionErr = false; hasChanged = true; }); });
          }
          Future<void> pickProvince() async {
            if (selRegionId == null) { _snack('Please select a region first.', Colors.orange); return; }
            if (provinces.isEmpty) { LoadingHelper.showLoadingDialog(ctx, message: 'Loading provinces...', width: 300, height: 200); provinces = await fetchProvinces(selRegionId!); if (!ctx.mounted) return;
            LoadingHelper.hideLoading(ctx); setDS(() {}); }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select Province', provinces, selProvId, (id, name) { setDS(() { selProvId = id; selProvName = name; selCityId = null; selCityName = null; cities = []; provErr = false; hasChanged = true; }); });
          }
          Future<void> pickCity() async {
            if (selProvId == null) { _snack('Please select a province first.', Colors.orange); return; }
            if (cities.isEmpty) { LoadingHelper.showLoadingDialog(ctx, message: 'Loading cities...', width: 300, height: 200); cities = await fetchCities(selProvId!); if (!ctx.mounted) return;
            LoadingHelper.hideLoading(ctx); setDS(() {}); }
            if (!ctx.mounted) return;
            _showLocationPicker(ctx, 'Select City', cities, selCityId, (id, name) { setDS(() { selCityId = id; selCityName = name; cityErr = false; hasChanged = true; }); });
          }

          bool validatePage1() {
            bool err = false;
            if (usernameCtrl.text.trim().isEmpty) { setDS(() => usernameErr = true); err = true; }
            if (schoolCtrl.text.trim().isEmpty)   { setDS(() => schoolErr   = true); err = true; }
            if (selAge == null)    { setDS(() => ageErr    = true); err = true; }
            if (selSex == null)    { setDS(() => sexErr    = true); err = true; }
            if (selAvatar == null) { setDS(() => avatarErr = true); err = true; }
            if (err) _snack('Please fill in all required fields on this page.', Colors.red);
            return !err;
          }

          bool validatePage2() {
            bool err = false;
            if (selCat == null) { setDS(() => catErr = true); err = true; }
            if (selCat == 'Student' && selStudCat == null) { setDS(() => studCatErr = true); err = true; }
            if (selRegionId == null) { setDS(() => regionErr = true); err = true; }
            if (selProvId   == null) { setDS(() => provErr   = true); err = true; }
            if (selCityId   == null) { setDS(() => cityErr   = true); err = true; }
            if (err) _snack('Please fill in all required fields.', Colors.red);
            return !err;
          }

          // ── Page 1: same as Add New Player ──
          Widget buildPage1() => Center(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(flex: 3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              MouseRegion(cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _showAvatarPickerDialog(ctx, selAvatar, (a) => setDS(() { selAvatar = a; avatarErr = false; hasChanged = true; })),
                  child: CircleAvatar(radius: 55,
                      backgroundColor: avatarErr ? Colors.red : const Color(0xFFFDD000),
                      child: CircleAvatar(radius: 52, backgroundColor: Colors.white,
                          backgroundImage: selAvatar != null ? AssetImage(selAvatar!) : null,
                          child: selAvatar == null ? const Icon(Icons.person, size: 46, color: Colors.grey) : null)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _showAvatarPickerDialog(ctx, selAvatar, (a) => setDS(() { selAvatar = a; avatarErr = false; hasChanged = true; })),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 2),
                child: const Text("Select Avatar", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              if (avatarErr) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11))),
            ])),
            const SizedBox(width: 16),
            Expanded(flex: 7, child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildTextField(Icons.person, "Username", controller: usernameCtrl, hasError: usernameErr,
                  onChanged: (_) => setDS(() { usernameErr = false; hasChanged = true; })),
              _buildTextField(Icons.school, "School / Institution", controller: schoolCtrl, hasError: schoolErr,
                  onChanged: (_) => setDS(() { schoolErr = false; hasChanged = true; })),
              Row(children: [
                Expanded(child: _buildClickableField("Age", selAge,
                        () => _showListPicker(ctx, "Select Age Range", ["0-12","13-17","18-22","23-29","30-39","40+"], selAge, (v) => setDS(() { selAge = v; ageErr = false; hasChanged = true; })),
                    hasError: ageErr)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("Sex", selSex,
                        () => _showListPicker(ctx, "Select Sex", ["Male","Female","Prefer Not to Say"], selSex, (v) => setDS(() { selSex = v; sexErr = false; hasChanged = true; })),
                    hasError: sexErr)),
              ]),
            ])),
          ]));

          // ── Page 2: same as Add New Player ──
          Widget buildPage2() => Center(child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildClickableField("Category", selCat,
                      () => _showListPicker(ctx, "Select Category", ["Student","Government Employee","Private Employee","Self-Employed","Not Employed","Others"], selCat,
                          (v) => setDS(() { selCat = v; catErr = false; if (v != 'Student') selStudCat = null; hasChanged = true; })),
                  hasError: catErr),
              if (selCat == 'Student')
                _buildClickableField("Student Category", selStudCat,
                        () => _showListPicker(ctx, "Select Student Category", ["Grade 1-6 (Elementary)","Grade 7-10 (Junior High)","Grade 11-12 (Senior High)","College","Graduate School"], selStudCat,
                            (v) => setDS(() { selStudCat = v; studCatErr = false; hasChanged = true; })),
                    hasError: studCatErr),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _buildClickableField("Region", selRegionName, () async => await pickRegion(), hasError: regionErr)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("Province", selProvName, () async => await pickProvince(), hasError: provErr)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("City", selCityName, () async => await pickCity(), hasError: cityErr)),
              ]),
            ]),
          ));

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.all(20),
            child: Container(
              width: 720, height: 320,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
              child: Column(children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Row(children: [
                    Icon(Icons.edit, color: Colors.black, size: 24), SizedBox(width: 8),
                    Text('Edit Player', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                  ]),
                  TextButton.icon(
                    onPressed: () { Navigator.pop(ctx); _showChangePasswordDialog(player); },
                    icon: const Icon(Icons.vpn_key, size: 16, color: Color(0xFF046EB8)),
                    label: const Text('Change Password', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF046EB8))),
                    style: TextButton.styleFrom(side: const BorderSide(color: Color(0xFF046EB8)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  ),
                ]),
                const SizedBox(height: 6),
                Expanded(child: PageView(controller: pageCtrl, physics: const NeverScrollableScrollPhysics(),
                    children: [buildPage1(), buildPage2()])),
                const SizedBox(height: 6),
                _pageIndicator(page),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  if (page == 0)
                    TextButton(onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF046EB8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14), side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('Cancel'))
                  else
                    TextButton(onPressed: () { pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setDS(() => page = 0); },
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF046EB8), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14), side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('Back')),
                  if (page == 0)
                    ElevatedButton(
                        onPressed: () { if (validatePage1()) { pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); setDS(() => page = 1); } },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), textStyle: const TextStyle(fontFamily: "Poppins", fontSize: 13, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: const Text('NEXT'))
                  else
                    ElevatedButton(
                        onPressed: (saving || !hasChanged) ? null : () async {
                          if (!validatePage2()) return;
                          setDS(() => saving = true);
                          LoadingHelper.showLoadingDialog(ctx, message: 'Saving changes...', width: 300, height: 200);
                          final res = await _api.updatePlayer(player['id'].toString(), {
                            'username': usernameCtrl.text.trim(),
                            'school': schoolCtrl.text.trim(),
                            if (selAge != null) 'age': selAge!,
                            if (selSex != null) 'sex': selSex!,
                            // Map display category to backend enum value
                            if (selCat != null) 'category': selCat == 'Student'
                                ? 'Student'
                                : (selCat == 'Others')
                                ? 'Others'
                                : 'Employee',
                            'student_category': selCat == 'Student' ? selStudCat : null,
                            if (selAvatar != null) 'avatar': selAvatar!,
                            if (selRegionId != null) 'region': int.tryParse(selRegionId!) ?? 0,
                            if (selProvId   != null) 'province': int.tryParse(selProvId!)   ?? 0,
                            if (selCityId   != null) 'city': int.tryParse(selCityId!)       ?? 0,
                          });
                          if (!ctx.mounted) return;
                          LoadingHelper.hideLoading(ctx);
                          setDS(() => saving = false);
                          if (res['success'] == true) { Navigator.pop(ctx); _snack('Player updated successfully!', const Color(0xFF27AE60)); _refresh(); }
                          else { _snack(res['message'] ?? 'Failed to update.', Colors.red); }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDD000), foregroundColor: const Color(0xFF816A03),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), textStyle: const TextStyle(fontFamily: "Poppins", fontSize: 13, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: Text(hasChanged ? 'SAVE CHANGES' : 'NO CHANGES')),
                ]),
              ]),
            ),
          );
        }));
  }

  // ═══════════════════════════════════════════════════════════════
  // AWARD BADGE DIALOG
  // Admin sees the player's claimed (completed) rewards and can
  // give the physical reward, which resets that difficulty's badges
  // ═══════════════════════════════════════════════════════════════

  void _showAwardBadgeDialog(Map<String, dynamic> player) async {
    LoadingHelper.showLoadingDialog(context, message: 'Loading badges...', width: 300, height: 200);

    Map<String, dynamic> badgeData = {};
    try {
      final res = await _api.getPlayerBadgeSummary(player['id'].toString());
      if (res['success'] == true) badgeData = res['data'] ?? {};
    } catch (_) {}

    if (!mounted) return;
    LoadingHelper.hideLoading(context);

    // Badge assets — exact same paths as player_badges.dart
    const badgeAssets = {
      'easy':      'assets/images-badges/whiz-ready.png',
      'average':   'assets/images-badges/whiz-happy.png',
      'difficult': 'assets/images-badges/whiz-achiever.png',
    };
    const difficultyLabels = {'easy': 'Easy', 'average': 'Average', 'difficult': 'Difficult'};
    const difficultyColors = {
      'easy':      Color(0xFF27AE60),
      'average':   Color(0xFF046EB8),
      'difficult': Color(0xFFE74C3C),
    };

    bool awarding = false;

    showDialog(context: context, barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) {

          final officialBadges = badgeData['official_badges'] as Map? ?? {};
          final unclaimed      = badgeData['requested']       as Map? ?? {};
          final progress       = badgeData['progress']        as Map? ?? {};

          // Builds one difficulty card — EXACT copy of player_badges.dart _buildBadgeCategory, button changed only
          Widget diffRow(String diff) {
            final label      = difficultyLabels[diff]!;
            final color      = difficultyColors[diff]!;
            final asset      = badgeAssets[diff]!;
            final prog       = progress[diff] as Map? ?? {};
            final currentCount = (prog['current_count'] ?? 0) as int;
            final official     = (officialBadges[diff]  ?? 0) as int;
            final unclaimedN   = (unclaimed[diff]       ?? 0) as int;
            final hasPending   = unclaimedN > 0;

            final List<String?> badgePaths = hasPending
                ? [asset, asset, asset]
                : List.generate(3, (i) => i < currentCount ? asset : null);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Label row: title + progress pill + trophy (moved here) ──
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(width: 8),
                  Text(
                    hasPending ? '3/3 ✓' : '$currentCount/3',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  ),
                  if (official > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.emoji_events, color: Colors.white, size: 13),
                        const SizedBox(width: 3),
                        Text('x$official', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ]),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                // ── Badges + button row ──
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  ...List.generate(3, (i) {
                    final path = badgePaths[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 68, height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: path != null ? color : Colors.grey.shade300, width: 3),
                          color: path == null ? Colors.grey.shade100 : null,
                        ),
                        child: path != null
                            ? ClipOval(child: Image.asset(path, fit: BoxFit.contain))
                            : Center(child: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 26)),
                      ),
                    );
                  }),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: hasPending && !awarding ? () async {
                      setDS(() => awarding = true);
                      LoadingHelper.showLoadingDialog(ctx, message: 'Awarding...', width: 300, height: 200);
                      final res = await _api.adminAwardBadge(player['id'].toString(), difficulty: diff);
                      if (!ctx.mounted) return;
                      LoadingHelper.hideLoading(ctx);
                      setDS(() => awarding = false);
                      if (res['success'] == true) {
                        _snack('${player['username'] ?? 'Player'}\'s $label reward given! Badges reset.', const Color(0xFF27AE60));
                        final refreshed = await _api.getPlayerBadgeSummary(player['id'].toString());
                        if (refreshed['success'] == true && ctx.mounted) setDS(() => badgeData = refreshed['data'] ?? {});
                      } else {
                        _snack(res['message'] ?? 'Failed to award badge.', Colors.red);
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasPending ? color : Colors.grey.shade300,
                      foregroundColor: hasPending ? Colors.white : Colors.grey.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                    child: Text(hasPending ? 'Give Reward' : 'LOCKED'),
                  ),
                ]),
              ],
            );
          }

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 420, padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Header ──
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.emoji_events, color: Color(0xFFFDD000), size: 28), const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Badge Rewards', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 20)),
                      Text(player['username'] ?? '', style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black45)),
                    ]),
                  ]),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 10),
                diffRow('easy'),
                const SizedBox(height: 12),
                diffRow('average'),
                const SizedBox(height: 12),
                diffRow('difficult'),
                const SizedBox(height: 4),
              ]),
            ),
          );
        }));
  }

  // ═══════════════════════════════════════════════════════════════
  // VIEW PLAYER DIALOG — region/province/city resolved to names
  // ═══════════════════════════════════════════════════════════════

  void _showViewPlayerDialog(Map<String, dynamic> player) async {
    // Show loading while resolving location names
    LoadingHelper.showLoadingDialog(context, message: 'Loading player info...', width: 300, height: 200);

    // Resolve IDs to names
    String regionName = '—', provName = '—', cityName = '—';
    final regionId   = player['region']?.toString();
    final provinceId = player['province']?.toString();
    final cityId     = player['city']?.toString();

    try {
      if (regionId != null && regionId.isNotEmpty && regionId != 'null') {
        final regions = await fetchRegions();
        final r = regions.firstWhere((r) => r['id'] == regionId, orElse: () => {'name': regionId});
        regionName = r['name'] ?? regionId;
        if (provinceId != null && provinceId.isNotEmpty && provinceId != 'null') {
          final provinceList = await fetchProvinces(regionId);
          final p = provinceList.firstWhere((p) => p['id'] == provinceId, orElse: () => {'name': provinceId});
          provName = p['name'] ?? provinceId;
          if (cityId != null && cityId.isNotEmpty && cityId != 'null') {
            final cits = await fetchCities(provinceId);
            final c = cits.firstWhere((c) => c['id'] == cityId, orElse: () => {'name': cityId});
            cityName = c['name'] ?? cityId;
          }
        }
      }
    } catch (_) {}

    final addressParts = [cityName, provName, regionName].where((s) => s != '—' && s.isNotEmpty).toList();
    final address = addressParts.isNotEmpty ? addressParts.join(', ') : '—';

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    LoadingHelper.hideLoading(context);
    // ignore: use_build_context_synchronously
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 400, padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Avatar
          Container(width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF046EB8), width: 3), color: Colors.grey.shade100),
              clipBehavior: Clip.hardEdge,
              child: player['avatar'] != null && (player['avatar'] as String).isNotEmpty
                  ? Image.asset(player['avatar'], fit: BoxFit.cover, width: 100, height: 100, errorBuilder: (ctx, err, st) => const Icon(Icons.person, size: 50, color: Color(0xFF046EB8)))
                  : const Icon(Icons.person, size: 50, color: Color(0xFF046EB8))),
          const SizedBox(height: 12),
          Text(player['username'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          const SizedBox(height: 2),
          Text(player['category'] ?? '', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey.shade500)),
          const Divider(height: 24),
          _viewRow(Icons.school_outlined,     'School',       player['school'] ?? '—'),
          _viewRow(Icons.cake_outlined,        'Age',          player['age'] ?? '—'),
          _viewRow(Icons.wc,                   'Sex',          player['sex'] ?? '—'),
          _viewRow(Icons.category_outlined,    'Category',     player['category'] ?? '—'),
          if ((player['student_category'] ?? '').toString().isNotEmpty)
            _viewRow(Icons.menu_book_outlined, 'Student Type', player['student_category'].toString()),
          _viewRow(Icons.location_on_outlined, 'Address',      address),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF046EB8), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Close', style: TextStyle(fontFamily: 'Poppins')))),
        ]),
      ),
    ));
  }

  Widget _viewRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: const Color(0xFF046EB8)), const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13)),
      Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13))),
    ]),
  );

  // ═══════════════════════════════════════════════════════════════
  // DELETE PLAYER DIALOG
  // ═══════════════════════════════════════════════════════════════

  void _showDeletePlayerDialog(Map<String, dynamic> player) {
    bool deleting = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDS) => Dialog(
      backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 340, padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.delete_forever, size: 26, color: Colors.red)),
          const SizedBox(height: 12),
          const Text('Delete Player?', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
          const SizedBox(height: 8),
          Text('This will permanently delete "${player['username'] ?? ''}".', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), side: BorderSide(color: Colors.grey.shade400)),
                child: const Text('Cancel', style: TextStyle(color: Colors.black, fontFamily: 'Poppins')))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
                onPressed: deleting ? null : () async {
                  setDS(() => deleting = true);
                  LoadingHelper.showLoadingDialog(ctx, message: 'Deleting player...', width: 300, height: 200);
                  final res = await _api.deletePlayer(player['id'].toString());
                  if (!ctx.mounted) return;
                  LoadingHelper.hideLoading(ctx);
                  setDS(() => deleting = false);
                  Navigator.pop(ctx);
                  if (res['success'] == true) { _snack('Player deleted.', Colors.red); _refresh(); }
                  else { _snack(res['message'] ?? 'Failed.', Colors.red); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), elevation: 0),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')))),
          ]),
        ]),
      ),
    )));
  }

  // ═══════════════════════════════════════════════════════════════
  // FILTER & SORT DIALOGS
  // ═══════════════════════════════════════════════════════════════

  void _showFilterDialog() {
    String? tc = filterCategory, ts = filterSex, tsc = filterStudentCategory;

    Widget chip(String label, String? current, void Function(String?) onTap, {String? value}) {
      final selected = current == value;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onTap(selected ? null : value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDD000) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? const Color(0xFFFDD000) : Colors.grey.shade300, width: selected ? 2 : 1),
            ),
            child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? const Color(0xFF816A03) : Colors.black87)),
          ),
        ),
      );
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Dialog(
      backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 440, padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [
              Icon(Icons.filter_list, size: 22, color: Color(0xFF046EB8)), SizedBox(width: 8),
              Text('Filter Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ]),
            MouseRegion(cursor: SystemMouseCursors.click,
                child: IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
          ]),
          const SizedBox(height: 14),

          // Category
          const Text('Category', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF046EB8))),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('All', tc, (v) => set(() { tc = v; if (v != 'Student') tsc = null; }), value: null),
            chip('Student', tc, (v) => set(() => tc = v), value: 'Student'),
            chip('Employee', tc, (v) => set(() { tc = v; tsc = null; }), value: 'Employee'),
            chip('Others', tc, (v) => set(() { tc = v; tsc = null; }), value: 'Others'),
          ]),

          // Student Category (only when Student selected)
          if (tc == 'Student') ...[
            const SizedBox(height: 12),
            const Text('Student Category', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF046EB8))),
            const SizedBox(height: 7),
            Wrap(spacing: 8, runSpacing: 8, children: [
              chip('All', tsc, (v) => set(() => tsc = v), value: null),
              chip('Elementary', tsc, (v) => set(() => tsc = v), value: 'Grade 1-6 (Elementary)'),
              chip('Junior High', tsc, (v) => set(() => tsc = v), value: 'Grade 7-10 (Junior High)'),
              chip('Senior High', tsc, (v) => set(() => tsc = v), value: 'Grade 11-12 (Senior High)'),
              chip('College', tsc, (v) => set(() => tsc = v), value: 'College'),
              chip('Graduate', tsc, (v) => set(() => tsc = v), value: 'Graduate School'),
            ]),
          ],
          const SizedBox(height: 12),

          // Sex
          const Text('Sex', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF046EB8))),
          const SizedBox(height: 7),
          Wrap(spacing: 8, runSpacing: 8, children: [
            chip('All', ts, (v) => set(() => ts = v), value: null),
            chip('Male', ts, (v) => set(() => ts = v), value: 'Male'),
            chip('Female', ts, (v) => set(() => ts = v), value: 'Female'),
          ]),
          const SizedBox(height: 20),

          // Buttons
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            MouseRegion(cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: () => set(() { tc = null; ts = null; tsc = null; }),
                  icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF046EB8)),
                  label: const Text('Clear All', style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF046EB8), fontSize: 13)),
                )),
            Row(children: [
              OutlinedButton(onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.black87, fontSize: 13))),
              const SizedBox(width: 10),
              ElevatedButton(
                  onPressed: () { setState(() { filterCategory = tc; filterSex = ts; filterStudentCategory = tsc; }); Navigator.pop(ctx); _refresh(); },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF046EB8), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                  child: const Text('Apply', style: TextStyle(fontFamily: 'Poppins', fontSize: 13))),
            ]),
          ]),
        ]),
      ),
    )));
  }

  void _showSortDialog() {
    String ts = sortBy; bool ta = sortAscending;
    const sortOpts = {
      'username': 'Username', 'category': 'Category', 'sex': 'Sex',
      'school': 'School', 'age': 'Age', 'region': 'Region',
      'province': 'Province', 'city': 'City',
    };

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFDD000) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? const Color(0xFFFDD000) : Colors.grey.shade300, width: selected ? 2 : 1),
            ),
            child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? const Color(0xFF816A03) : Colors.black87)),
          ),
        ),
      );
    }

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Dialog(
      backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(width: 420, padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [
              Icon(Icons.sort, size: 22, color: Color(0xFF046EB8)), SizedBox(width: 8),
              Text('Sort Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            ]),
            MouseRegion(cursor: SystemMouseCursors.click,
                child: IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints())),
          ]),
          const SizedBox(height: 16),

          // Sort field
          const Text('Sort by', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF046EB8))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: sortOpts.entries.map((e) =>
              chip(e.value, ts == e.key, () => set(() => ts = e.key)),
          ).toList()),
          const SizedBox(height: 16),

          // Direction
          const Text('Order', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF046EB8))),
          const SizedBox(height: 8),
          Row(children: [
            chip('↑  Ascending', ta, () => set(() => ta = true)),
            const SizedBox(width: 8),
            chip('↓  Descending', !ta, () => set(() => ta = false)),
          ]),
          const SizedBox(height: 20),

          // Buttons
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: Colors.black87, fontSize: 13))),
            const SizedBox(width: 10),
            ElevatedButton(
                onPressed: () { setState(() { sortBy = ts; sortAscending = ta; }); Navigator.pop(ctx); _refresh(); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF046EB8), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
                child: const Text('Apply', style: TextStyle(fontFamily: 'Poppins', fontSize: 13))),
          ]),
        ]),
      ),
    )));
  }

  // ═══════════════════════════════════════════════════════════════
  // TABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _actionBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) => InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Tooltip(message: tooltip, child: Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)),
          child: Icon(icon, size: 17, color: color))));

  Color _catColor(String? c) { switch(c) { case 'Student': return const Color(0xFF046EB8); case 'Employee': return const Color(0xFF27AE60); default: return Colors.grey; } }

  Widget _buildAddressCell(Map<String, dynamic> p) {
    final city     = p['city_name']     as String?;
    final province = p['province_name'] as String?;
    final region   = p['region_name']   as String?;

    final parts = [city, province, region].where((s) => s != null && s.isNotEmpty).toList();
    if (parts.isEmpty) return const Text('—', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.grey));

    return Tooltip(
      message: parts.join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (city != null && city.isNotEmpty)
            Text(city, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          if (province != null && province.isNotEmpty)
            Text(province, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF555555)), overflow: TextOverflow.ellipsis),
          if (region != null && region.isNotEmpty)
            Text(region, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF888888)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Map<String, dynamic> p, bool even) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
    color: even ? Colors.grey.shade50 : Colors.white,
    child: Row(children: [
      SizedBox(width: 60, child: Center(child: ClipOval(
        child: Container(width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF046EB8), width: 2), color: Colors.grey.shade100),
            child: p['avatar'] != null && (p['avatar'] as String).isNotEmpty
                ? Image.asset(p['avatar'], fit: BoxFit.cover, width: 44, height: 44, errorBuilder: (ctx, err, st) => const Icon(Icons.person, size: 22, color: Color(0xFF046EB8)))
                : const Icon(Icons.person, size: 22, color: Color(0xFF046EB8))),
      ))),
      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(left: 12), child: Text(p['username'] ?? '', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))),
      Expanded(flex: 2, child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _catColor(p['category']).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Text(p['category'] ?? '', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _catColor(p['category']), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)))),
      Expanded(flex: 2, child: Text(p['school'] ?? '—', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13), overflow: TextOverflow.ellipsis)),
      Expanded(flex: 4, child: _buildAddressCell(p)),
      Expanded(flex: 1, child: Center(child: Text(p['age'] ?? '—', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)))),
      Expanded(flex: 1, child: Center(child: Text(p['sex'] ?? '—', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)))),
      SizedBox(width: 170, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _actionBtn(Icons.visibility,   Colors.blue,             'View',         () => _showViewPlayerDialog(p)),
        const SizedBox(width: 6),
        _actionBtn(Icons.edit,         Colors.green,            'Edit',         () => _showEditPlayerDialog(p)),
        const SizedBox(width: 6),
        _actionBtn(Icons.emoji_events, const Color(0xFFF39C12), 'Award Badge',  () => _showAwardBadgeDialog(p)),
        const SizedBox(width: 6),
        _actionBtn(Icons.delete,       Colors.red,              'Delete',       () => _showDeletePlayerDialog(p)),
      ])),
    ]),
  );

  Widget _buildTable() {
    if (isLoading) { return const Center(child: CircularProgressIndicator(color: Color(0xFF046EB8))); }
    if (errorMessage != null) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300), const SizedBox(height: 16),
      Text(errorMessage!, style: const TextStyle(fontSize: 16, fontFamily: 'Poppins', color: Colors.red)), const SizedBox(height: 16),
      ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
    ])); }
    return LayoutBuilder(builder: (context, tc) {
      final isMobileTable = tc.maxWidth < 700;
      Widget table = Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))),
              child: const Row(children: [
                SizedBox(width: 60, child: Center(child: Text('Avatar',   style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
                Expanded(flex: 2, child: Padding(padding: EdgeInsets.only(left: 12), child: Text('Username',  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
                Expanded(flex: 2, child: Center(child: Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
                Expanded(flex: 2, child: Text('School',    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins'))),
                Expanded(flex: 4, child: Text('Address',   style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins'))),
                Expanded(flex: 1, child: Center(child: Text('Age',      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
                Expanded(flex: 1, child: Center(child: Text('Sex',      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
                SizedBox(width: 170, child: Center(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')))),
              ])),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(child: playersData.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]), const SizedBox(height: 16),
            Text('No players found', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontFamily: 'Poppins')),
          ]))
              : ListView.separated(itemCount: playersData.length,
              separatorBuilder: (ctx, i) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (_, i) => _buildPlayerRow(playersData[i], i.isEven))),
        ]),
      );
      if (isMobileTable) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: 750, child: table),
        );
      }
      return table;
    });
  }

  Widget _buildPagination() {
    const perPageOptions = [10, 25, 50, 100];

    // Page number button builder
    Widget pageBtn(int p) => GestureDetector(
      onTap: () => _loadPlayers(page: p),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: p == currentPage ? const Color(0xFF046EB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p == currentPage ? const Color(0xFF046EB8) : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text('$p', style: TextStyle(
          fontFamily: 'Poppins', fontSize: 13,
          color: p == currentPage ? Colors.white : Colors.black87,
          fontWeight: p == currentPage ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );

    // Build visible page numbers with ellipsis
    List<Widget> pageButtons = [];
    for (int p = 1; p <= totalPages; p++) {
      if (p == 1 || p == totalPages || (p >= currentPage - 1 && p <= currentPage + 1)) {
        pageButtons.add(pageBtn(p));
      } else if ((p == currentPage - 2 && currentPage > 3) || (p == currentPage + 2 && currentPage < totalPages - 2)) {
        pageButtons.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('…', style: TextStyle(fontFamily: 'Poppins', color: Colors.grey)),
        ));
      }
    }

    return Row(children: [
      // Left: Page X of Y
      Text(
        'Page $currentPage of $totalPages',
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black54),
      ),

      // Center: prev + page numbers + next
      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: currentPage > 1 ? () => _loadPlayers(page: currentPage - 1) : null,
          icon: Icon(Icons.chevron_left, color: currentPage > 1 ? Colors.black87 : Colors.grey.shade300),
          splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        ...pageButtons,
        IconButton(
          onPressed: currentPage < totalPages ? () => _loadPlayers(page: currentPage + 1) : null,
          icon: Icon(Icons.chevron_right, color: currentPage < totalPages ? Colors.black87 : Colors.grey.shade300),
          splashRadius: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ])),

      // Right: Show X dropdown
      Row(children: [
        const Text('Show:', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black54)),
        const SizedBox(width: 8),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: perPageOptions.contains(perPage) ? perPage : 10,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87),
              isDense: true,
              items: perPageOptions.map((n) => DropdownMenuItem(
                value: n,
                child: Text('$n', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
              )).toList(),
              onChanged: (n) {
                if (n == null) return;
                setState(() => perPage = n);
                _loadPlayers(page: 1);
              },
            ),
          ),
        ),
      ]),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override Widget build(BuildContext context) => Container(
    color: const Color(0xFF94D2FD), padding: const EdgeInsets.all(24),
    child: Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, hc) {
          final isNarrow = hc.maxWidth < 750;
          if (isNarrow) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title row
              Row(children: [
                const Icon(Icons.people, size: 24), const SizedBox(width: 8),
                const Text('List of Players', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF046EB8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('$totalPlayers total', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF046EB8)))),
              ]),
              const SizedBox(height: 10),
              // Search bar full width
              Container(height: 42, padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(25)),
                  child: Row(children: [
                    const Icon(Icons.search, color: Color(0xFF858585), size: 20), const SizedBox(width: 8),
                    Expanded(child: TextField(controller: searchController,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                        decoration: const InputDecoration(hintText: 'Search players...', hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                        onChanged: (v) { setState(() => searchQuery = v); _refresh(); })),
                    if (searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear, size: 20, color: Color(0xFF858585)),
                        onPressed: () { searchController.clear(); setState(() => searchQuery = ''); _refresh(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ])),
              const SizedBox(height: 10),
              // Action buttons row
              Wrap(spacing: 8, runSpacing: 8, children: [
                ElevatedButton.icon(onPressed: _showAddPlayerDialog,
                    icon: const Icon(Icons.person_add, size: 16), label: const Text('Add Player', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF046EB8), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 0)),
                OutlinedButton.icon(onPressed: _showSortDialog,
                    icon: const Icon(Icons.sort, size: 16), label: const Text('Sort', style: TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                OutlinedButton.icon(onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list, size: 16),
                    label: Text('Filter${(filterCategory != null || filterSex != null) ? " •" : ""}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: (filterCategory != null || filterSex != null) ? const Color(0xFF046EB8) : Colors.black87,
                        side: BorderSide(color: (filterCategory != null || filterSex != null) ? const Color(0xFF046EB8) : Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, size: 20),
                    style: IconButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: const CircleBorder()), tooltip: 'Refresh'),
              ]),
            ]);
          }
          return Row(children: [
            const Icon(Icons.people, size: 28), const SizedBox(width: 12),
            const Text('List of Players', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF046EB8).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('$totalPlayers total', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF046EB8)))),
            const SizedBox(width: 24),
            Expanded(child: Container(height: 45, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(25)),
                child: Row(children: [
                  const Icon(Icons.search, color: Color(0xFF858585), size: 20), const SizedBox(width: 8),
                  Expanded(child: TextField(controller: searchController,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Search players...', hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14), border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true),
                      onChanged: (v) { setState(() => searchQuery = v); _refresh(); })),
                  if (searchQuery.isNotEmpty) IconButton(icon: const Icon(Icons.clear, size: 20, color: Color(0xFF858585)),
                      onPressed: () { searchController.clear(); setState(() => searchQuery = ''); _refresh(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]))),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: _showAddPlayerDialog,
                icon: const Icon(Icons.person_add, size: 18), label: const Text('Add Player', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF046EB8), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), elevation: 0)),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _showSortDialog,
                icon: const Icon(Icons.sort, size: 18), label: const Text('Sort', style: TextStyle(fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            const SizedBox(width: 8),
            OutlinedButton.icon(onPressed: _showFilterDialog,
                icon: const Icon(Icons.filter_list, size: 18),
                label: Text('Filter${(filterCategory != null || filterSex != null) ? " •" : ""}', style: const TextStyle(fontFamily: 'Poppins')),
                style: OutlinedButton.styleFrom(
                    foregroundColor: (filterCategory != null || filterSex != null) ? const Color(0xFF046EB8) : Colors.black87,
                    side: BorderSide(color: (filterCategory != null || filterSex != null) ? const Color(0xFF046EB8) : Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            const SizedBox(width: 8),
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, size: 20),
                style: IconButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: const CircleBorder()), tooltip: 'Refresh'),
          ]);
        }),
        const SizedBox(height: 16),
        Expanded(child: _buildTable()),
        if (!isLoading && playersData.isNotEmpty) ...[const SizedBox(height: 12), _buildPagination()],
      ]),
    ),
  );
}