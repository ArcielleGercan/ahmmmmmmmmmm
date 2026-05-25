import 'package:flutter/material.dart';
import 'package:flutter_projects/change_password.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'audio_service.dart';
import 'homepage.dart'; // contains UserProfile class
import 'loading_page.dart'; // ✅ ADDED: Loading screen
import 'config.dart';

class EditProfileDialog extends StatefulWidget {
  final UserProfile profile;

  const EditProfileDialog({super.key, required this.profile});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  // Page control
  int _currentPage = 0;
  final PageController _pageController = PageController();

  late TextEditingController usernameController;
  late TextEditingController schoolController;

  String? selectedAvatar;
  String? selectedAge;
  String? selectedCategory;
  String? selectedStudentCategory;
  String? selectedSex;
  String? selectedRegionId;
  String? selectedProvinceId;
  String? selectedCityId;
  String? selectedRegionName;
  String? selectedProvinceName;
  String? selectedCityName;

  // Error tracking
  bool usernameError = false;
  bool schoolError = false;
  bool ageError = false;
  bool avatarError = false;
  bool categoryError = false;
  bool studentCategoryError = false;
  bool sexError = false;
  bool regionError = false;
  bool provinceError = false;
  bool cityError = false;

  List<Map<String, String>> regions = [];
  List<Map<String, String>> provinces = [];
  List<Map<String, String>> cities = [];

  bool saving = false;
  bool showSuccess = false;
  double successOpacity = 1.0;
  bool _hasFormChanged = false;

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.contains(' ')) {
      return 'Username cannot contain spaces';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.trim().length > 20) {
      return 'Username must not exceed 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validateSchool(String school) {
    if (school.length < 3) {
      return 'School name must be at least 3 characters';
    }
    if (school.length > 100) {
      return 'School name is too long';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearErrors() {
    setState(() {
      usernameError = false;
      schoolError = false;
      ageError = false;
      avatarError = false;
      categoryError = false;
      studentCategoryError = false;
      sexError = false;
      regionError = false;
      provinceError = false;
      cityError = false;
    });
  }

  final List<String> avatarPaths = [
    "assets/images-avatars/Adventurer.png",
    "assets/images-avatars/Astronaut.png",
    "assets/images-avatars/Boy.png",
    "assets/images-avatars/Brainy.png",
    "assets/images-avatars/Cool-Monkey.png",
    "assets/images-avatars/Cute-Elephant.png",
    "assets/images-avatars/Doctor-Boy.png",
    "assets/images-avatars/Doctor-Girl.png",
    "assets/images-avatars/Engineer-Boy.png",
    "assets/images-avatars/Engineer-Girl.png",
    "assets/images-avatars/Girl.png",
    "assets/images-avatars/Hacker.png",
    "assets/images-avatars/Leonel.png",
    "assets/images-avatars/Scientist-Boy.png",
    "assets/images-avatars/Scientist-Girl.png",
    "assets/images-avatars/Sly-Fox.png",
    "assets/images-avatars/Sneaky-Snake.png",
    "assets/images-avatars/Teacher-Boy.png",
    "assets/images-avatars/Teacher-Girl.png",
    "assets/images-avatars/Twirky.png",
    "assets/images-avatars/Whiz-Achiever.png",
    "assets/images-avatars/Whiz-Busy.png",
    "assets/images-avatars/Whiz-Happy.png",
    "assets/images-avatars/Whiz-Ready.png",
    "assets/images-avatars/Wise-Turtle.png",
  ];

  late final List<String> avatarNames = avatarPaths
      .map(
        (path) => path.split('/').last.replaceAll('.png', '').replaceAll('-', ' '),
  )
      .toList();

  @override
  void initState() {
    super.initState();

    usernameController = TextEditingController(text: widget.profile.username);
    schoolController = TextEditingController(text: widget.profile.school);

    usernameController.addListener(() => setState(() => _hasFormChanged = true));
    schoolController.addListener(() => setState(() => _hasFormChanged = true));

    selectedAvatar = widget.profile.avatar;
    selectedAge = widget.profile.age;
    selectedCategory = widget.profile.category;
    selectedStudentCategory = widget.profile.studentCategory;
    selectedSex = widget.profile.sex;

    // Store the current location names (don't fetch data yet - lazy load on click)
    selectedRegionName = widget.profile.region;
    selectedProvinceName = widget.profile.province;
    selectedCityName = widget.profile.city;

    // Debug print to verify the value is loaded
    debugPrint('Loaded student category: ${widget.profile.studentCategory}');
    debugPrint('Selected student category: $selectedStudentCategory');
  }

  @override
  void dispose() {
    usernameController.dispose();
    schoolController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0) {
      // Validate page 1 fields before proceeding
      _clearErrors();
      bool hasError = false;

      if (usernameController.text.trim().isEmpty) {
        setState(() => usernameError = true);
        hasError = true;
      }
      if (schoolController.text.trim().isEmpty) {
        setState(() => schoolError = true);
        hasError = true;
      }
      if (selectedAge == null) {
        setState(() => ageError = true);
        hasError = true;
      }
      if (selectedSex == null) {
        setState(() => sexError = true);
        hasError = true;
      }
      if (selectedAvatar == null) {
        setState(() => avatarError = true);
        hasError = true;
      }

      String? usernameValidationError = _validateUsername(usernameController.text);
      if (usernameValidationError != null) {
        setState(() => usernameError = true);
        _showError(usernameValidationError);
        hasError = true;
      }

      String? schoolErrorMsg = _validateSchool(schoolController.text);
      if (schoolErrorMsg != null) {
        setState(() => schoolError = true);
        _showError(schoolErrorMsg);
        hasError = true;
      }

      if (hasError) {
        _showError('Please fill in all required fields on this page');
        return;
      }

      AudioService().playClickSound();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = 1);
    }
  }

  void _previousPage() {
    AudioService().playClickSound();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = 0);
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon, bool hasError = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13,
        fontFamily: "Poppins",
        color: hasError ? Colors.red.shade300 : null,
      ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildTextField(
      IconData icon,
      String hint, {
        TextEditingController? controller,
        bool hasError = false,
        void Function(String)? onChanged,
      }) {
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

  Widget _buildClickableField(
      String label,
      String? value,
      VoidCallback onTap, {
        bool hasError = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasError ? Colors.red : Colors.grey,
                    width: hasError ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      value ?? label,
                      style: TextStyle(
                        fontSize: 13,
                        color: value != null ? Colors.black : Colors.grey,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  void _showAvatarPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (_isMobile ? MediaQuery.of(context).size.width * 0.88 : 500.0).clamp(260.0, 520.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Choose Your Avatar",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: _isMobile ? MediaQuery.of(context).size.height * 0.45 : 400,
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _isMobile ? 3 : 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: avatarPaths.length,
                  itemBuilder: (context, index) {
                    final avatarPath = avatarPaths[index];
                    final avatarName = avatarNames[index];
                    final isSelected = selectedAvatar == avatarPath;

                    return _AvatarGridItem(
                      avatarName: avatarName,
                      avatarPath: avatarPath,
                      isSelected: isSelected,
                      onTap: () {
                        AudioService().playClickSound();
                        setState(() {
                          selectedAvatar = avatarPath;
                          avatarError = false;
                          _hasFormChanged = true;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> fetchRegions() async {
    // ✅ SHOW LOADING DIALOG - Loading regions
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Loading regions...', width: 300, height: 200);

    try {
      final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/region'));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        regions = data
            .map<Map<String, String>>(
              (e) => {
            'id': e['id'].toString(),
            'name': (e['region_name'] ?? e['name']).toString(),
          },
        )
            .toList();
        setState(() {});
      }
    } catch (_) {
    } finally {
      // ✅ HIDE LOADING after regions are loaded
      if (mounted) LoadingHelper.hideLoading(context);
    }
  }

  Future<void> fetchProvinces(String regionId) async {
    // ✅ SHOW LOADING DIALOG - Loading provinces
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Loading provinces...', width: 300, height: 200);

    try {
      final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/province/$regionId'));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        provinces = data
            .map<Map<String, String>>(
              (e) => {
            'id': e['id'].toString(),
            'name': (e['province_name'] ?? e['name']).toString(),
          },
        )
            .toList();
        setState(() {});
      }
    } catch (_) {
    } finally {
      // ✅ HIDE LOADING after provinces are loaded
      if (mounted) LoadingHelper.hideLoading(context);
    }
  }

  Future<void> fetchCities(String provinceId) async {
    // ✅ SHOW LOADING DIALOG - Loading cities
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Loading cities...', width: 300, height: 200);

    try {
      final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/city/$provinceId'));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        cities = data
            .map<Map<String, String>>(
              (e) => {
            'id': e['id'].toString(),
            'name': (e['city_name'] ?? e['name']).toString(),
          },
        )
            .toList();
        setState(() {});
      }
    } catch (_) {
    } finally {
      // ✅ HIDE LOADING after cities are loaded
      if (mounted) LoadingHelper.hideLoading(context);
    }
  }

  /// Resolves region/province/city IDs from their names when user hasn't
  /// changed location (IDs are null but names are available from profile).
  Future<bool> _resolveLocationIds() async {
    try {
      // ── Region ──────────────────────────────────────────────────────────
      if (selectedRegionId == null && selectedRegionName != null) {
        final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/region'));
        if (resp.statusCode == 200) {
          final List data = jsonDecode(resp.body);
          final match = data.firstWhere(
                (e) => (e['region_name'] ?? e['name']).toString() == selectedRegionName,
            orElse: () => null,
          );
          if (match == null) {
            _showError('Could not resolve region. Please re-select your region.');
            return false;
          }
          selectedRegionId = match['id'].toString();
        } else {
          _showError('Failed to load regions. Please try again.');
          return false;
        }
      }

      // ── Province ─────────────────────────────────────────────────────────
      if (selectedProvinceId == null && selectedProvinceName != null && selectedRegionId != null) {
        final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/province/$selectedRegionId'));
        if (resp.statusCode == 200) {
          final List data = jsonDecode(resp.body);
          final match = data.firstWhere(
                (e) => (e['province_name'] ?? e['name']).toString() == selectedProvinceName,
            orElse: () => null,
          );
          if (match == null) {
            _showError('Could not resolve province. Please re-select your province.');
            return false;
          }
          selectedProvinceId = match['id'].toString();
        } else {
          _showError('Failed to load provinces. Please try again.');
          return false;
        }
      }

      // ── City ─────────────────────────────────────────────────────────────
      if (selectedCityId == null && selectedCityName != null && selectedProvinceId != null) {
        final resp = await http.get(Uri.parse('${AppConfig.baseUrl}/city/$selectedProvinceId'));
        if (resp.statusCode == 200) {
          final List data = jsonDecode(resp.body);
          final match = data.firstWhere(
                (e) => (e['city_name'] ?? e['name']).toString() == selectedCityName,
            orElse: () => null,
          );
          if (match == null) {
            _showError('Could not resolve city. Please re-select your city.');
            return false;
          }
          selectedCityId = match['id'].toString();
        } else {
          _showError('Failed to load cities. Please try again.');
          return false;
        }
      }

      return true;
    } catch (e) {
      _showError('Error resolving location. Please re-select your location.');
      return false;
    }
  }

  Future<void> saveProfile() async {
    if (!_hasFormChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No changes have been made'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _clearErrors();
    bool hasError = false;

    // Validate all fields
    if (selectedCategory == null) {
      setState(() => categoryError = true);
      hasError = true;
    }
    if (selectedCategory == "Student" && selectedStudentCategory == null) {
      setState(() => studentCategoryError = true);
      hasError = true;
    }
    // Allow saving if either ID or Name is present (user may not have changed their location)
    if (selectedRegionId == null && (selectedRegionName == null || selectedRegionName!.isEmpty)) {
      setState(() => regionError = true);
      hasError = true;
    }
    if (selectedProvinceId == null && (selectedProvinceName == null || selectedProvinceName!.isEmpty)) {
      setState(() => provinceError = true);
      hasError = true;
    }
    if (selectedCityId == null && (selectedCityName == null || selectedCityName!.isEmpty)) {
      setState(() => cityError = true);
      hasError = true;
    }

    if (hasError) {
      _showError('Please fill in all required fields');
      return;
    }

    // ✅ SHOW LOADING DIALOG - Resolving location IDs then updating profile
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Updating profile...', width: 300, height: 200);

    setState(() => saving = true);

    // Resolve IDs from names if the user didn't change their location
    final resolved = await _resolveLocationIds();
    if (!resolved) {
      if (mounted) LoadingHelper.hideLoading(context);
      setState(() => saving = false);
      return;
    }

    try {
      final resp = await http.put(
        Uri.parse('${AppConfig.baseUrl}/user/update/${widget.profile.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'school': schoolController.text.trim(),
          'age': selectedAge,
          'category': selectedCategory,
          'student_category': selectedCategory == "Student" ? selectedStudentCategory : null,
          'sex': selectedSex,
          'avatar': selectedAvatar,
          'region': selectedRegionId ?? selectedRegionName,
          'province': selectedProvinceId ?? selectedProvinceName,
          'city': selectedCityId ?? selectedCityName,
        }),
      );

      final data = jsonDecode(resp.body);

      // ✅ HIDE LOADING before showing results
      if (mounted) LoadingHelper.hideLoading(context);

      if (resp.statusCode == 200 && data['success'] == true) {
        if (data['no_changes'] == true) {
          setState(() => saving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No changes were made'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        final updatedProfile = widget.profile.copyWith(
          username: usernameController.text.trim(),
          school: schoolController.text.trim(),
          age: selectedAge,
          category: selectedCategory,
          studentCategory: selectedCategory == "Student" ? selectedStudentCategory : null,
          sex: selectedSex,
          avatar: selectedAvatar,
          region: selectedRegionName,
          province: selectedProvinceName,
          city: selectedCityName,
        );

        // Play success sound
        AudioService().playClickSound();

        setState(() {
          showSuccess = true;
          saving = false;
        });

        await Future.delayed(const Duration(seconds: 4));
        if (!mounted) return;
        setState(() => successOpacity = 0.0);
        await Future.delayed(const Duration(seconds: 1));

        if (mounted) Navigator.pop(context, updatedProfile);
      } else {
        setState(() => saving = false);

        if (resp.statusCode == 422) {
          final errors = data['errors'] as Map<String, dynamic>?;
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors.values.first;
            final errorMessage = firstError is List ? firstError.first : firstError.toString();
            if (mounted) _showError(errorMessage);
          } else {
            if (mounted) _showError(data['message'] ?? 'Validation failed');
          }
        } else {
          if (mounted) _showError(data['message'] ?? 'Failed to update profile');
        }
      }
    } catch (e) {
      // ✅ HIDE LOADING on error
      if (mounted) LoadingHelper.hideLoading(context);

      setState(() => saving = false);
      if (mounted) _showError('Network error. Please check your connection.');
    }
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    // On mobile: fill the screen minus the inset padding (auto height).
    // On desktop: use fixed sizes.
    final dialogHeight = showSuccess
        ? (_isMobile ? 300.0 : 360.0)
        : (_isMobile ? sh * 0.72 : 420.0);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: _isMobile ? 12 : 20,
        vertical: _isMobile ? 60 : 20,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: showSuccess ? (_isMobile ? sw * 0.88 : 420.0) : (_isMobile ? sw * 0.92 : 600.0),
        height: dialogHeight,
        padding: EdgeInsets.all(_isMobile ? 18 : 30),
        child: showSuccess
            ? AnimatedOpacity(
          opacity: successOpacity,
          duration: const Duration(seconds: 1),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images-logo/bird1.png",
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const Text(
                  "Profile Updated!",
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your profile has been saved successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Poppins",
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        )
            : Form(
          key: _formKey,
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Colors.black, size: _isMobile ? 20 : 26),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: _isMobile ? 17 : 22,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      AudioService().playClickSound();
                      showDialog(
                        context: context,
                        builder: (_) => ChangePasswordDialog(
                          userId: widget.profile.id,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.vpn_key,
                      color: Color(0xFF046EB8),
                    ),
                    label: Text(
                      _isMobile ? 'Password' : 'Change Password',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: _isMobile ? 11 : 14,
                        color: Color(0xFF046EB8),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF046EB8),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: _isMobile ? 10 : 16,
                        vertical: _isMobile ? 8 : 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // PageView (form content) - NOW FIRST
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPage1(),
                    _buildPage2(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Page Indicator MOVED HERE (before navigation buttons)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage == 0 ? const Color(0xFFFDD000) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _currentPage == 1 ? const Color(0xFFFDD000) : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Navigation Buttons - NOW LAST
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage == 0)
                    TextButton(
                      onPressed: () {
                        AudioService().playClickSound();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF046EB8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                        side: const BorderSide(
                          color: Color(0xFF046EB8),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Cancel'),
                    )
                  else
                    TextButton(
                      onPressed: _previousPage,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF046EB8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                        side: const BorderSide(
                          color: Color(0xFF046EB8),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Back'),
                    ),

                  if (_currentPage == 0)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _nextPage,
                      child: const Text('NEXT'),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: "Poppins",
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: (saving || !_hasFormChanged)
                          ? null
                          : () {
                        AudioService().playClickSound();
                        saveProfile();
                      },
                      child: saving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : Text(_hasFormChanged ? 'SAVE CHANGES' : 'NO CHANGES'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage1() {
    return SingleChildScrollView(
      child: _isMobile
          // MOBILE: avatar centered on top, fields below
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _showAvatarPickerDialog,
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: avatarError ? Colors.red : const Color(0xFFFDD000),
                      child: CircleAvatar(
                        radius: 39,
                        backgroundColor: Colors.white,
                        backgroundImage: selectedAvatar != null ? AssetImage(selectedAvatar!) : null,
                        child: selectedAvatar == null ? const Icon(Icons.person, size: 34, color: Colors.grey) : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: _showAvatarPickerDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDD000),
                    foregroundColor: const Color(0xFF816A03),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                  child: const Text("Select Avatar",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                if (avatarError)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11)),
                  ),
                const SizedBox(height: 10),
                _buildTextField(Icons.person, "Username",
                  controller: usernameController,
                  hasError: usernameError,
                  onChanged: (_) => setState(() { usernameError = false; _hasFormChanged = true; }),
                ),
                _buildTextField(Icons.school, "School",
                  controller: schoolController,
                  hasError: schoolError,
                  onChanged: (_) => setState(() { schoolError = false; _hasFormChanged = true; }),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _buildClickableField("Age", selectedAge, _showAgePickerDialog, hasError: ageError)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildClickableField("Sex", selectedSex, _showSexPickerDialog, hasError: sexError)),
                  ],
                ),
              ],
            )
          // DESKTOP: avatar left, fields right
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _showAvatarPickerDialog,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: CircleAvatar(
                              radius: 70,
                              backgroundColor: avatarError ? Colors.red : const Color(0xFFFDD000),
                              child: CircleAvatar(
                                radius: 67,
                                backgroundColor: Colors.white,
                                backgroundImage: selectedAvatar != null ? AssetImage(selectedAvatar!) : null,
                                child: selectedAvatar == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _showAvatarPickerDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDD000),
                          foregroundColor: const Color(0xFF816A03),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                        child: const Text("Select Avatar",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      if (avatarError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Required', style: TextStyle(color: Colors.red, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _buildTextField(Icons.person, "Username",
                        controller: usernameController,
                        hasError: usernameError,
                        onChanged: (_) => setState(() { usernameError = false; _hasFormChanged = true; }),
                      ),
                      _buildTextField(Icons.school, "School",
                        controller: schoolController,
                        hasError: schoolError,
                        onChanged: (_) => setState(() { schoolError = false; _hasFormChanged = true; }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildClickableField("Age", selectedAge, _showAgePickerDialog, hasError: ageError)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildClickableField("Sex", selectedSex, _showSexPickerDialog, hasError: sexError)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }


  Widget _buildPage2() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildClickableField("Category", selectedCategory, _showCategoryPickerDialog, hasError: categoryError),
          if (selectedCategory == "Student")
            _buildClickableField("Student Category", selectedStudentCategory, _showStudentCategoryPickerDialog, hasError: studentCategoryError),
          const SizedBox(height: 6),
          // On mobile: stack Region/Province/City vertically; desktop: 3 columns
          if (_isMobile) ...[
            _buildClickableField("Region", selectedRegionName, _showRegionPickerDialog, hasError: regionError),
            _buildClickableField("Province", selectedProvinceName, _showProvincePickerDialog, hasError: provinceError),
            _buildClickableField("City", selectedCityName, _showCityPickerDialog, hasError: cityError),
          ] else
            Row(
              children: [
                Expanded(child: _buildClickableField("Region", selectedRegionName, _showRegionPickerDialog, hasError: regionError)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("Province", selectedProvinceName, _showProvincePickerDialog, hasError: provinceError)),
                const SizedBox(width: 10),
                Expanded(child: _buildClickableField("City", selectedCityName, _showCityPickerDialog, hasError: cityError)),
              ],
            ),
        ],
      ),
    );
  }

  // Picker dialog methods
  void _showAgePickerDialog() {
    final ageRanges = ["0-12", "13-17", "18-22", "23-29", "30-39", "40+"];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Age Range",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: ageRanges.length,
                itemBuilder: (context, index) {
                  final age = ageRanges[index];
                  final isSelected = selectedAge == age;
                  return _SelectionGridItem(
                    label: age,
                    isSelected: isSelected,
                    onTap: () {
                      AudioService().playClickSound();
                      setState(() {
                        selectedAge = age;
                        ageError = false;
                        _hasFormChanged = true;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPickerDialog() {
    final categories = [
      "Student",
      "Government Employee",
      "Private Employee",
      "Self-Employed",
      "Not Employed",
      "Others"
    ];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Category",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: categories.map((category) {
                  final isSelected = selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelectionGridItem(
                      label: category,
                      isSelected: isSelected,
                      onTap: () {
                        AudioService().playClickSound();
                        setState(() {
                          selectedCategory = category;
                          categoryError = false;
                          _hasFormChanged = true;
                          if (category != "Student") {
                            selectedStudentCategory = null;
                            studentCategoryError = false;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentCategoryPickerDialog() {
    final studentCategories = [
      "Grade 1-6 (Elementary)",
      "Grade 7-10 (Junior High)",
      "Grade 11-12 (Senior High)",
      "College",
      "Graduate School"
    ];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Student Category",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: studentCategories.map((category) {
                  final isSelected = selectedStudentCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelectionGridItem(
                      label: category,
                      isSelected: isSelected,
                      onTap: () {
                        AudioService().playClickSound();
                        setState(() {
                          selectedStudentCategory = category;
                          studentCategoryError = false;
                          _hasFormChanged = true;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSexPickerDialog() {
    final sexOptions = ["Male", "Female", "Prefer not to say"];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Sex",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: sexOptions.map((sex) {
                  final isSelected = selectedSex == sex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SelectionGridItem(
                      label: sex,
                      isSelected: isSelected,
                      onTap: () {
                        AudioService().playClickSound();
                        setState(() {
                          selectedSex = sex;
                          sexError = false;
                          _hasFormChanged = true;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegionPickerDialog() async {
    // Lazy load: Only fetch regions when user clicks to change region
    if (regions.isEmpty) {
      // Check mounted before using context
      if (!mounted) return;

      // Show loading dialog while fetching
      LoadingHelper.showLoadingDialog(
        context,
        message: 'Loading regions...',
        width: 300,
        height: 200,
      );

      await fetchRegions();

      // Find and set the current region ID if it exists
      if (selectedRegionName != null && selectedRegionName!.isNotEmpty) {
        selectedRegionId = regions.firstWhere(
              (r) => r['name'] == selectedRegionName,
          orElse: () => {'id': ''},
        )['id'];
      }

      if (mounted) {
        LoadingHelper.hideLoading(context);
      }
    }

    // Check mounted before showing dialog after async operation
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Region",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final reg = regions[index];
                    final isSelected = selectedRegionId == reg['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SelectionGridItem(
                        label: reg['name']!,
                        isSelected: isSelected,
                        onTap: () {
                          AudioService().playClickSound();
                          setState(() {
                            selectedRegionId = reg['id'];
                            selectedRegionName = reg['name'];
                            selectedProvinceId = null;
                            selectedProvinceName = null;
                            selectedCityId = null;
                            selectedCityName = null;
                            provinces = [];
                            cities = [];
                            regionError = false;
                            _hasFormChanged = true;
                          });
                          fetchProvinces(reg['id']!);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProvincePickerDialog() async {
    // Check if region is selected
    if (selectedRegionId == null || selectedRegionId!.isEmpty) {
      _showError('Please select a region first');
      return;
    }

    // Lazy load: Only fetch provinces when user clicks to change province
    if (provinces.isEmpty) {
      // Check mounted before using context
      if (!mounted) return;

      LoadingHelper.showLoadingDialog(
        context,
        message: 'Loading provinces...',
        width: 300,
        height: 200,
      );

      await fetchProvinces(selectedRegionId!);

      // Find and set the current province ID if it exists
      if (selectedProvinceName != null && selectedProvinceName!.isNotEmpty) {
        selectedProvinceId = provinces.firstWhere(
              (p) => p['name'] == selectedProvinceName,
          orElse: () => {'id': ''},
        )['id'];
      }

      if (mounted) {
        LoadingHelper.hideLoading(context);
      }
    }

    // Check mounted before showing dialog after async operation
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Province",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: provinces.length,
                  itemBuilder: (context, index) {
                    final prov = provinces[index];
                    final isSelected = selectedProvinceId == prov['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SelectionGridItem(
                        label: prov['name']!,
                        isSelected: isSelected,
                        onTap: () {
                          AudioService().playClickSound();
                          setState(() {
                            selectedProvinceId = prov['id'];
                            selectedProvinceName = prov['name'];
                            selectedCityId = null;
                            selectedCityName = null;
                            cities = [];
                            provinceError = false;
                            _hasFormChanged = true;
                          });
                          fetchCities(prov['id']!);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCityPickerDialog() async {
    // Check if province is selected
    if (selectedProvinceId == null || selectedProvinceId!.isEmpty) {
      _showError('Please select a province first');
      return;
    }

    // Lazy load: Only fetch cities when user clicks to change city
    if (cities.isEmpty) {
      // Check mounted before using context
      if (!mounted) return;

      LoadingHelper.showLoadingDialog(
        context,
        message: 'Loading cities...',
        width: 300,
        height: 200,
      );

      await fetchCities(selectedProvinceId!);

      // Find and set the current city ID if it exists
      if (selectedCityName != null && selectedCityName!.isNotEmpty) {
        selectedCityId = cities.firstWhere(
              (c) => c['name'] == selectedCityName,
          orElse: () => {'id': ''},
        )['id'];
      }

      if (mounted) {
        LoadingHelper.hideLoading(context);
      }
    }

    // Check mounted before showing dialog after async operation
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 420.0),
          padding: EdgeInsets.all(_isMobile ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select City",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF046EB8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: cities.length,
                  itemBuilder: (context, index) {
                    final cty = cities[index];
                    final isSelected = selectedCityId == cty['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SelectionGridItem(
                        label: cty['name']!,
                        isSelected: isSelected,
                        onTap: () {
                          AudioService().playClickSound();
                          setState(() {
                            selectedCityId = cty['id'];
                            selectedCityName = cty['name'];
                            cityError = false;
                            _hasFormChanged = true;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable grid item widgets
class _AvatarGridItem extends StatefulWidget {
  final String avatarName;
  final String avatarPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarGridItem({
    required this.avatarName,
    required this.avatarPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AvatarGridItem> createState() => _AvatarGridItemState();
}

class _AvatarGridItemState extends State<_AvatarGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFFDD000)
                : _isHovered
                ? const Color(0xFFFDD000).withValues(alpha: 0.5)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFFFDD000) : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05),
                blurRadius: _isHovered ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(widget.avatarPath, width: 50, height: 50, fit: BoxFit.contain),
              const SizedBox(height: 4),
              Text(
                widget.avatarName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionGridItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionGridItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SelectionGridItem> createState() => _SelectionGridItemState();
}

class _SelectionGridItemState extends State<_SelectionGridItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFFDD000)
                : _isHovered
                ? const Color(0xFFFDD000).withValues(alpha: 0.5)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isSelected ? const Color(0xFFFDD000) : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05),
                blurRadius: _isHovered ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}