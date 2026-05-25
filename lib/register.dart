import 'audio_service.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'admin_login.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'loading_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  int step = 0;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController schoolController = TextEditingController();

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

  bool usernameError = false;
  bool passwordError = false;
  bool confirmPasswordError = false;
  bool schoolError = false;
  bool ageError = false;
  bool avatarError = false;
  bool categoryError = false;
  bool studentCategoryError = false;
  bool sexError = false;
  bool regionError = false;
  bool provinceError = false;
  bool cityError = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool _hasFormChanged = false;

  List<Map<String, String>> region = [];
  List<Map<String, String>> province = [];
  List<Map<String, String>> city = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScale;

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    usernameController
        .addListener(() => setState(() => _hasFormChanged = true));
    passwordController
        .addListener(() => setState(() => _hasFormChanged = true));
    confirmPasswordController
        .addListener(() => setState(() => _hasFormChanged = true));
    schoolController
        .addListener(() => setState(() => _hasFormChanged = true));

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _buttonScaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _buttonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
          parent: _buttonScaleController, curve: Curves.easeInOut),
    );

    fetchRegions();
    _fadeController.forward();
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    schoolController.dispose();
    _fadeController.dispose();
    _buttonScaleController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      usernameError = false;
      passwordError = false;
      confirmPasswordError = false;
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

  void _playClickSound() async {
    try {
      await AudioService().playClickSound();
    } catch (e) {
      debugPrint('Click sound error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  String? _validateUsername(String username) {
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 20)
      return 'Username must not exceed 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username))
      return 'Username can only contain letters, numbers, and underscores';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.length < 8)
      return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]')))
      return 'Password must contain at least one uppercase letter';
    if (!password.contains(RegExp(r'[a-z]')))
      return 'Password must contain at least one lowercase letter';
    if (!password.contains(RegExp(r'[0-9]')))
      return 'Password must contain at least one number';
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')))
      return 'Password must contain at least one special character';
    return null;
  }

  String? _validateSchool(String school) {
    if (school.length < 3) return 'School name must be at least 3 characters';
    if (school.length > 100) return 'School name is too long';
    return null;
  }

  bool _validateStep1() {
    _clearErrors();
    bool hasError = false;
    if (usernameController.text.trim().isEmpty) {
      setState(() => usernameError = true);
      hasError = true;
    }
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = true);
      hasError = true;
    }
    if (confirmPasswordController.text.isEmpty) {
      setState(() => confirmPasswordError = true);
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
    if (hasError) {
      _showError('Please fill in all required fields');
      return false;
    }
    String? usernameErrorMsg =
        _validateUsername(usernameController.text);
    if (usernameErrorMsg != null) {
      setState(() => usernameError = true);
      _showError(usernameErrorMsg);
      return false;
    }
    String? passwordErrorMsg =
        _validatePassword(passwordController.text);
    if (passwordErrorMsg != null) {
      setState(() => passwordError = true);
      _showError(passwordErrorMsg);
      return false;
    }
    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        passwordError = true;
        confirmPasswordError = true;
      });
      _showError('Passwords do not match');
      return false;
    }
    return true;
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────

  double _dialogWidth(BuildContext context) =>
      MediaQuery.of(context).size.width < 600
          ? MediaQuery.of(context).size.width * 0.88
          : 420;

  Widget _dialogHeader(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF046EB8)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showAvatarPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: _dialogWidth(context),
          // CHANGE: taller avatar dialog
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Choose Your Avatar"),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    // CHANGE: slightly taller cells for icon+text
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _getAvatarList().length,
                  itemBuilder: (context, index) {
                    final avatarName = _getAvatarList()[index];
                    final avatarPath =
                        "assets/images-avatars/$avatarName.png";
                    final isSelected = selectedAvatar == avatarPath;
                    return _AvatarGridItem(
                      avatarName: avatarName,
                      avatarPath: avatarPath,
                      isSelected: isSelected,
                      onTap: () {
                        _playClickSound();
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

  void _showAgePickerDialog() {
    final ageRanges = ["0-12", "13-17", "18-22", "23-29", "30-39", "40+"];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          // CHANGE: narrower age dialog
          width: (_dialogWidth(context) * 0.75).clamp(260.0, 340.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Age Range"),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  // CHANGE: smaller, more compact cells
                  childAspectRatio: 2.8,
                ),
                itemCount: ageRanges.length,
                itemBuilder: (context, index) {
                  final age = ageRanges[index];
                  return _SelectionGridItem(
                    label: age,
                    isSelected: selectedAge == age,
                    onTap: () {
                      _playClickSound();
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

  void _showSexPickerDialog() {
    final sexOptions = ["Male", "Female", "Prefer Not to Say"];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          // CHANGE: narrower, taller sex dialog
          width: (_dialogWidth(context) * 0.65).clamp(220.0, 300.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Sex"),
              const SizedBox(height: 12),
              Column(
                children: sexOptions
                    .map((sex) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          // CHANGE: taller sex option items
                          child: _SelectionGridItemTall(
                            label: sex,
                            isSelected: selectedSex == sex,
                            onTap: () {
                              _playClickSound();
                              setState(() {
                                selectedSex = sex;
                                sexError = false;
                                _hasFormChanged = true;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ))
                    .toList(),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          // CHANGE: narrower category dialog
          width: (_dialogWidth(context) * 0.70).clamp(240.0, 320.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Category"),
              const SizedBox(height: 12),
              Column(
                children: categories
                    .map((category) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SelectionGridItem(
                            label: category,
                            isSelected: selectedCategory == category,
                            onTap: () {
                              _playClickSound();
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
                        ))
                    .toList(),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (_dialogWidth(context) * 0.80).clamp(260.0, 360.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Student Category"),
              const SizedBox(height: 12),
              Column(
                children: studentCategories
                    .map((category) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SelectionGridItem(
                            label: category,
                            isSelected:
                                selectedStudentCategory == category,
                            onTap: () {
                              _playClickSound();
                              setState(() {
                                selectedStudentCategory = category;
                                studentCategoryError = false;
                                _hasFormChanged = true;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegionPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          // CHANGE: narrower region/province/city dialogs
          width: (_dialogWidth(context) * 0.75).clamp(260.0, 360.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Region"),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: region.length,
                  itemBuilder: (context, index) {
                    final reg = region[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SelectionGridItem(
                        label: reg['name']!,
                        isSelected: selectedRegionId == reg['id'],
                        onTap: () {
                          _playClickSound();
                          Navigator.pop(context);
                          setState(() {
                            selectedRegionId = reg['id'];
                            selectedRegionName = reg['name'];
                            selectedProvinceId = null;
                            selectedProvinceName = null;
                            selectedCityId = null;
                            selectedCityName = null;
                            province = [];
                            city = [];
                            regionError = false;
                            _hasFormChanged = true;
                          });
                          fetchProvinces(reg['id']!);
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

  void _showProvincePickerDialog() {
    if (province.isEmpty) {
      _showError('Please select a region first');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (_dialogWidth(context) * 0.75).clamp(260.0, 360.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select Province"),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: province.length,
                  itemBuilder: (context, index) {
                    final prov = province[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SelectionGridItem(
                        label: prov['name']!,
                        isSelected: selectedProvinceId == prov['id'],
                        onTap: () {
                          _playClickSound();
                          Navigator.pop(context);
                          setState(() {
                            selectedProvinceId = prov['id'];
                            selectedProvinceName = prov['name'];
                            selectedCityId = null;
                            selectedCityName = null;
                            city = [];
                            provinceError = false;
                            _hasFormChanged = true;
                          });
                          fetchCities(prov['id']!);
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

  void _showCityPickerDialog() {
    if (city.isEmpty) {
      _showError('Please select a province first');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: (_dialogWidth(context) * 0.75).clamp(260.0, 360.0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(context, "Select City"),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.45,
                child: ListView.builder(
                  itemCount: city.length,
                  itemBuilder: (context, index) {
                    final cty = city[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SelectionGridItem(
                        label: cty['name']!,
                        isSelected: selectedCityId == cty['id'],
                        onTap: () {
                          _playClickSound();
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

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> fetchRegions() async {
    if (!mounted) return;
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/region'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          region = data
              .map((r) => {
                    'id': r['id'].toString(),
                    'name': r['name'].toString(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching regions: $e');
    }
  }

  Future<void> fetchProvinces(String regionId) async {
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context,
        message: 'Loading provinces...', width: 300, height: 200);
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/province/$regionId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          province = data
              .map((p) => {
                    'id': p['id'].toString(),
                    'name': p['name'].toString(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching provinces: $e');
    } finally {
      if (mounted) LoadingHelper.hideLoading(context);
    }
  }

  Future<void> fetchCities(String provinceId) async {
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context,
        message: 'Loading cities...', width: 300, height: 200);
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/city/$provinceId'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          city = data
              .map((c) => {
                    'id': c['id'].toString(),
                    'name': c['name'].toString(),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching cities: $e');
    } finally {
      if (mounted) LoadingHelper.hideLoading(context);
    }
  }

  // ── Stepper ───────────────────────────────────────────────────────────────

  Widget _buildStepper() {
    return Column(
      children: [
        Row(
          children: [
            _buildStepCircle(0),
            Expanded(
              child: Container(
                height: 2,
                color: step >= 1
                    ? const Color(0xFF046EB8)
                    : Colors.grey.shade400,
              ),
            ),
            _buildStepCircle(1),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Privacy Notice",
                textAlign: TextAlign.left,
                style: TextStyle(
                    fontSize: _isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                "Personal Information",
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: _isMobile ? 11 : 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepCircle(int stepIndex) {
    final bool isCompleted = step > stepIndex;
    final bool isActive =
        step == stepIndex || (stepIndex == 1 && step >= 1);
    final Color circleColor =
        (isActive || isCompleted) ? const Color(0xFF046EB8) : Colors.grey.shade400;
    return CircleAvatar(radius: 7, backgroundColor: circleColor);
  }

  List<String> _getAvatarList() {
    return const [
      "Adventurer", "Astronaut", "Boy", "Brainy", "Cool-Monkey",
      "Cute-Elephant", "Doctor-Boy", "Doctor-Girl", "Engineer-Boy",
      "Engineer-Girl", "Girl", "Hacker", "Leonel", "Scientist-Boy",
      "Scientist-Girl", "Sly-Fox", "Sneaky-Snake", "Teacher-Boy",
      "Teacher-Girl", "Twirky", "Whiz-Achiever", "Whiz-Busy",
      "Whiz-Happy", "Whiz-Ready", "Wise-Turtle",
    ];
  }

  // ── Register API ──────────────────────────────────────────────────────────

  Future<void> registerUser() async {
    if (!_hasFormChanged) {
      _showError('No changes have been made');
      return;
    }
    _playClickSound();
    await _buttonScaleController.forward();
    await _buttonScaleController.reverse();
    _clearErrors();
    bool hasError = false;

    if (usernameController.text.trim().isEmpty) {
      setState(() => usernameError = true);
      hasError = true;
    }
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = true);
      hasError = true;
    }
    if (confirmPasswordController.text.isEmpty) {
      setState(() => confirmPasswordError = true);
      hasError = true;
    }
    if (selectedAvatar == null) {
      setState(() => avatarError = true);
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
    if (schoolController.text.trim().isEmpty) {
      setState(() => schoolError = true);
      hasError = true;
    }
    if (selectedCategory == null) {
      setState(() => categoryError = true);
      hasError = true;
    }
    if (selectedCategory == "Student" && selectedStudentCategory == null) {
      setState(() => studentCategoryError = true);
      hasError = true;
    }
    if (selectedRegionId == null) {
      setState(() => regionError = true);
      hasError = true;
    }
    if (selectedProvinceId == null) {
      setState(() => provinceError = true);
      hasError = true;
    }
    if (selectedCityId == null) {
      setState(() => cityError = true);
      hasError = true;
    }

    if (hasError) {
      _showError('Please fill in all required fields');
      return;
    }

    String? usernameErrorMsg =
        _validateUsername(usernameController.text);
    if (usernameErrorMsg != null) {
      setState(() => usernameError = true);
      _showError(usernameErrorMsg);
      return;
    }
    String? passwordErrorMsg =
        _validatePassword(passwordController.text);
    if (passwordErrorMsg != null) {
      setState(() => passwordError = true);
      _showError(passwordErrorMsg);
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        passwordError = true;
        confirmPasswordError = true;
      });
      _showError('Passwords do not match');
      return;
    }
    String? schoolErrorMsg = _validateSchool(schoolController.text);
    if (schoolErrorMsg != null) {
      setState(() => schoolError = true);
      _showError(schoolErrorMsg);
      return;
    }

    final payload = {
      "username": usernameController.text.trim(),
      "password": passwordController.text,
      "school": schoolController.text.trim(),
      "age": selectedAge ?? "",
      "avatar": selectedAvatar ?? "",
      "category": selectedCategory ?? "",
      "student_category":
          selectedCategory == "Student" ? selectedStudentCategory : null,
      "sex": selectedSex ?? "",
      "region": selectedRegionId,
      "province": selectedProvinceId,
      "city": selectedCityId,
    };

    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context,
        message: 'Creating account...', width: 300, height: 200);

    final url = Uri.parse('${AppConfig.baseUrl}/user/register');
    try {
      final resp = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode(payload));
      if (mounted) LoadingHelper.hideLoading(context);

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: _isMobile
                  ? MediaQuery.of(context).size.width * 0.82
                  : 340,
              padding: EdgeInsets.symmetric(
                  horizontal: _isMobile ? 20 : 28,
                  vertical: _isMobile ? 24 : 32),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CHANGE: "Registration Successful!" text ABOVE the check icon
                  const Text("Registration Successful!",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xDD000000))),
                  const SizedBox(height: 14),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: Colors.green, size: 50),
                  ),
                  const SizedBox(height: 14),
                  Text("Welcome, ${usernameController.text.trim()}!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text(
                      "Your account has been created. Please log in to continue.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xCF000000))),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _playClickSound();
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDD000),
                        foregroundColor: const Color(0xFF816A03),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("Go to Login",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        if (mounted) LoadingHelper.hideLoading(context);
        String message = 'Registration failed';
        try {
          final jsonBody = jsonDecode(resp.body);
          if (jsonBody is Map) {
            if (jsonBody['errors'] != null) {
              final errors = jsonBody['errors'] as Map<String, dynamic>;
              final firstError = errors.values.first;
              message = firstError is List
                  ? firstError.first
                  : firstError.toString();
            } else if (jsonBody['message'] != null) {
              message = jsonBody['message'];
            }
          }
        } catch (_) {
          message = resp.body;
        }
        if (!mounted) return;
        _showError(message);
      }
    } catch (e) {
      if (mounted) LoadingHelper.hideLoading(context);
      if (!mounted) return;
      _showError('Network error. Please check your connection.');
    }
  }


  // ── Error indicator widget ────────────────────────────────────────────────
  Widget _buildErrorMessage(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            message,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Form widgets ──────────────────────────────────────────────────────────

  // CHANGE: all text fields scaled to 90%
  Widget _buildTextField(IconData icon, String hint,
      {TextEditingController? controller,
      bool hasError = false,
      void Function(String)? onChanged}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _isMobile ? 5 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            style: const TextStyle(fontSize: 12, fontFamily: "Poppins"),
            decoration: _inputDecoration(hint, icon: icon, hasError: hasError),
            onChanged: onChanged,
          ),
          // CHANGE: ! error indicator below field on page 3 (school)
          if (hasError)
            _buildErrorMessage('Required'),
        ],
      ),
    );
  }

  Widget _buildPasswordField(
      IconData icon,
      String hint,
      bool hide,
      void Function(bool) toggle,
      TextEditingController controller,
      bool hasError,
      {void Function(String)? onChanged}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _isMobile ? 5 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            obscureText: hide,
            style: const TextStyle(fontSize: 12, fontFamily: "Poppins"),
            decoration: _inputDecoration(hint, icon: icon, hasError: hasError)
                .copyWith(
              suffixIcon: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: Icon(hide ? Icons.visibility : Icons.visibility_off,
                      size: 18, color: hasError ? Colors.red : null),
                  onPressed: () => toggle(!hide),
                ),
              ),
            ),
            onChanged: onChanged,
          ),
          if (hasError)
            _buildErrorMessage('Required'),
        ],
      ),
    );
  }

  // CHANGE: clickable fields with ! error indicator and pointer cursor
  Widget _buildClickableField(String label, String? value, VoidCallback onTap,
      {bool hasError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: hasError ? Colors.red : Colors.grey,
                      width: hasError ? 2 : 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        value ?? label,
                        style: TextStyle(
                            fontSize: 12,
                            color: value != null ? Colors.black : Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (hasError)
            _buildErrorMessage('Required'),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint,
      {IconData? icon, bool hasError = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          fontSize: 12,
          fontFamily: "Poppins",
          color: hasError ? Colors.red.shade300 : null),
      prefixIcon: icon != null
          ? Icon(icon, size: 17, color: hasError ? Colors.red : null)
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
              color: hasError ? Colors.red : Colors.grey,
              width: hasError ? 2 : 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
              color: hasError ? Colors.red : const Color(0xFF046EB8),
              width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.red, width: 2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.red, width: 2)),
      // CHANGE: slightly reduced content padding for 90% feel
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    );
  }

  void _handleBack(BuildContext context) {
    if (step > 0) {
      setState(() => step--);
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  Widget _buildOutlinedButton(String label, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF046EB8), width: 1),
          padding: EdgeInsets.symmetric(
              horizontal: _isMobile ? 22 : 32,
              vertical: _isMobile ? 9 : 11),
        ),
        onPressed: () {
          _playClickSound();
          onPressed();
        },
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: _isMobile ? 12 : 13)),
      ),
    );
  }

  // ── Step content ──────────────────────────────────────────────────────────

  Widget _buildPrivacyStepContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text("Register",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  // CHANGE: 90% of original sizes
                  fontSize: _isMobile ? 14 : 18,
                  color: const Color(0xFF046EB8))),
        ),
        SizedBox(height: _isMobile ? 4 : 8),
        Center(
          child: Image.asset("assets/images-logo/bird1.png",
              // CHANGE: 90% of original heights
              height: _isMobile ? 76 : 99),
        ),
        SizedBox(height: _isMobile ? 4 : 8),
        Center(
          child: Text("Terms and Conditions",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: _isMobile ? 12 : 13.5)),
        ),
        SizedBox(height: _isMobile ? 4 : 6),
        Text(
          "By accessing STARBOOKS WHIZ CHALLENGE, you agree to these terms and conditions. "
          "We collect personal information and usage data to improve our services and efficiency. "
          "We prioritize data security and do not share personal information with third parties without consent, "
          "except as required by law. Users must provide accurate information and comply with all laws while using our site. "
          "For questions, contact us at support@starbookswhizbee.com",
          // CHANGE: 90% font size
          style: TextStyle(fontSize: _isMobile ? 11 : 12, height: 1.5),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _buildPersonalInfoContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Personal Information",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _isMobile ? 14 : 18,
                  color: const Color(0xFF046EB8))),
          SizedBox(height: _isMobile ? 8 : 14),

          // ── Avatar + fields ──────────────────────────────────────────
          if (_isMobile) ...[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _showAvatarPickerDialog,
                child: CircleAvatar(
                  // CHANGE: smaller avatar on mobile
                  radius: 40,
                  backgroundColor:
                      avatarError ? Colors.red : const Color(0xFFFDD000),
                  child: CircleAvatar(
                    radius: 37,
                    backgroundColor: Colors.white,
                    backgroundImage: selectedAvatar != null
                        ? AssetImage(selectedAvatar!)
                        : null,
                    child: selectedAvatar == null
                        ? const Icon(Icons.person, size: 33, color: Colors.grey)
                        : null,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 2,
              ),
              child: const Text("Select Avatar",
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            if (avatarError)
              _buildErrorMessage('Required'),
            const SizedBox(height: 12),
            _buildTextField(Icons.person, "Username",
                controller: usernameController,
                hasError: usernameError,
                onChanged: (_) =>
                    setState(() => usernameError = false)),
            _buildPasswordField(
                Icons.lock,
                "Password",
                hidePassword,
                (val) => setState(() => hidePassword = !hidePassword),
                passwordController,
                passwordError,
                onChanged: (_) =>
                    setState(() => passwordError = false)),
            _buildPasswordField(
                Icons.lock,
                "Confirm Password",
                hideConfirmPassword,
                (val) => setState(
                    () => hideConfirmPassword = !hideConfirmPassword),
                confirmPasswordController,
                confirmPasswordError,
                onChanged: (_) =>
                    setState(() => confirmPasswordError = false)),
          ] else ...[
            // DESKTOP: avatar left, fields right
            Row(
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
                          child: CircleAvatar(
                            // CHANGE: smaller avatar circle (90% → ~58 from 70 would be 63)
                            radius: 58,
                            backgroundColor: avatarError
                                ? Colors.red
                                : const Color(0xFFFDD000),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white,
                              backgroundImage: selectedAvatar != null
                                  ? AssetImage(selectedAvatar!)
                                  : null,
                              child: selectedAvatar == null
                                  ? const Icon(Icons.person,
                                      size: 50, color: Colors.grey)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      // CHANGE: reduced spacing between avatar and button
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _showAvatarPickerDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDD000),
                          foregroundColor: const Color(0xFF816A03),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 2,
                        ),
                        child: const Text("Select Avatar",
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (avatarError)
                        _buildErrorMessage('Required'),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _buildTextField(Icons.person, "Username",
                          controller: usernameController,
                          hasError: usernameError,
                          onChanged: (_) =>
                              setState(() => usernameError = false)),
                      _buildPasswordField(
                          Icons.lock,
                          "Password",
                          hidePassword,
                          (val) => setState(
                              () => hidePassword = !hidePassword),
                          passwordController,
                          passwordError,
                          onChanged: (_) =>
                              setState(() => passwordError = false)),
                      _buildPasswordField(
                          Icons.lock,
                          "Confirm Password",
                          hideConfirmPassword,
                          (val) => setState(() =>
                              hideConfirmPassword = !hideConfirmPassword),
                          confirmPasswordController,
                          confirmPasswordError,
                          onChanged: (_) => setState(
                              () => confirmPasswordError = false)),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          // CHANGE: Age & Sex row — fixed alignment/spacing
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Age field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _showAgePickerDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: ageError ? Colors.red : Colors.grey,
                                width: ageError ? 2 : 1),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedAge ?? "Age",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: selectedAge != null
                                          ? Colors.black
                                          : Colors.grey)),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (ageError) _buildErrorMessage('Required'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Sex field — CHANGE: same height as age, consistent alignment
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _showSexPickerDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sexError ? Colors.red : Colors.grey,
                                width: sexError ? 2 : 1),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedSex ?? "Sex",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: selectedSex != null
                                          ? Colors.black
                                          : Colors.grey)),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (sexError) _buildErrorMessage('Required'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolLocationContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Personal Information",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _isMobile ? 14 : 18,
                  color: const Color(0xFF046EB8))),
          SizedBox(height: _isMobile ? 8 : 14),
          _buildTextField(Icons.school, "School",
              controller: schoolController,
              hasError: schoolError,
              onChanged: (_) => setState(() => schoolError = false)),
          _buildClickableField(
              "Category", selectedCategory, _showCategoryPickerDialog,
              hasError: categoryError),
          if (selectedCategory == "Student")
            _buildClickableField("Student Category",
                selectedStudentCategory, _showStudentCategoryPickerDialog,
                hasError: studentCategoryError)
          else
            Opacity(
              opacity: 0.4,
              child: IgnorePointer(
                child: _buildClickableField(
                    "Student Category", null, () {},
                    hasError: false),
              ),
            ),
          const SizedBox(height: 4),
          // Region / Province / City
          if (_isMobile) ...[
            _buildClickableField(
                "Region", selectedRegionName, _showRegionPickerDialog,
                hasError: regionError),
            _buildClickableField("Province", selectedProvinceName,
                _showProvincePickerDialog,
                hasError: provinceError),
            _buildClickableField(
                "City", selectedCityName, _showCityPickerDialog,
                hasError: cityError),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildClickableField("Region",
                        selectedRegionName, _showRegionPickerDialog,
                        hasError: regionError)),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildClickableField("Province",
                        selectedProvinceName, _showProvincePickerDialog,
                        hasError: provinceError)),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildClickableField("City",
                        selectedCityName, _showCityPickerDialog,
                        hasError: cityError)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation:
          Listenable.merge([_buttonScaleController, _fadeController]),
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF94D2FD),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            toolbarHeight: 48,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset("assets/images-logo/starbooksnewlogo.png",
                    height: 38),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminLoginPage()),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.person,
                            color: Color(0xFF046EB8), size: 16),
                        SizedBox(width: 4),
                        Text("ADMIN",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF046EB8))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Stack(
            children: [
              Image.asset("assets/images-icons/background1.png",
                  width: screenWidth,
                  height: screenHeight,
                  fit: BoxFit.cover),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Container(
                    // CHANGE: 90% width of original
                    width: screenWidth * 0.83,
                    constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.84),
                    padding: EdgeInsets.symmetric(
                        horizontal: _isMobile ? 14 : 22,
                        vertical: _isMobile ? 11 : 16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStepper(),
                        const SizedBox(height: 10),
                        Flexible(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                    opacity: animation, child: child),
                            child: step == 0
                                ? SingleChildScrollView(
                                    key: const ValueKey(0),
                                    child: _buildPrivacyStepContent(),
                                  )
                                : SingleChildScrollView(
                                    key: ValueKey(step),
                                    child: step == 1
                                        ? _buildPersonalInfoContent()
                                        : _buildSchoolLocationContent(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _buildOutlinedButton(
                                "Back", () => _handleBack(context)),
                            if (step == 0)
                              _buildOutlinedButton("Proceed", () {
                                _fadeController.reset();
                                setState(() => step = 1);
                                _fadeController.forward();
                              })
                            else if (step == 1)
                              _buildOutlinedButton("Next", () {
                                if (_validateStep1()) {
                                  _fadeController.reset();
                                  setState(() => step = 2);
                                  _fadeController.forward();
                                }
                              })
                            else
                              Transform.scale(
                                scale: _buttonScale.value,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFFDD000),
                                      foregroundColor:
                                          const Color(0xFFAC8337),
                                      padding: EdgeInsets.symmetric(
                                          horizontal:
                                              _isMobile ? 25 : 40,
                                          vertical:
                                              _isMobile ? 9 : 11),
                                    ),
                                    onPressed: (!_hasFormChanged)
                                        ? null
                                        : registerUser,
                                    child: Text(
                                      _hasFormChanged
                                          ? "REGISTER"
                                          : "NO CHANGES",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize:
                                              _isMobile ? 12 : 13),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _AvatarGridItem extends StatefulWidget {
  final String avatarName;
  final String avatarPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarGridItem(
      {required this.avatarName,
      required this.avatarPath,
      required this.isSelected,
      required this.onTap});

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
                color: widget.isSelected
                    ? const Color(0xFFFDD000)
                    : Colors.transparent,
                width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withValues(alpha: _isHovered ? 0.1 : 0.05),
                  blurRadius: _isHovered ? 6 : 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          // CHANGE: bigger icon and text in avatar grid
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(widget.avatarPath,
                  width: 46, height: 46, fit: BoxFit.contain),
              const SizedBox(height: 4),
              Text(
                widget.avatarName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 600 ? 7.5 : 10,
                    fontWeight: FontWeight.w500),
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

  const _SelectionGridItem(
      {required this.label,
      required this.isSelected,
      required this.onTap});

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
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFFDD000)
                : _isHovered
                    ? const Color(0xFFFDD000).withValues(alpha: 0.5)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFDD000)
                    : Colors.transparent,
                width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withValues(alpha: _isHovered ? 0.1 : 0.05),
                  blurRadius: _isHovered ? 6 : 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

// CHANGE: New taller variant for the Sex picker items
class _SelectionGridItemTall extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionGridItemTall(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  State<_SelectionGridItemTall> createState() =>
      _SelectionGridItemTallState();
}

class _SelectionGridItemTallState extends State<_SelectionGridItemTall> {
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
          // CHANGE: taller padding for sex picker
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFFDD000)
                : _isHovered
                    ? const Color(0xFFFDD000).withValues(alpha: 0.5)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFFFDD000)
                    : Colors.transparent,
                width: 3),
            boxShadow: [
              BoxShadow(
                  color: Colors.black
                      .withValues(alpha: _isHovered ? 0.1 : 0.05),
                  blurRadius: _isHovered ? 6 : 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Center(
            child: Text(widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}