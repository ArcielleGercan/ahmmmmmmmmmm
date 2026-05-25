import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:web/web.dart' as web;
import 'admin_leaderboard.dart';
import 'admin_login.dart';
import 'admin_users_players.dart';
import 'admin_users_admins.dart';
import 'admin_questions.dart';
import 'admin_difficulty.dart';
import 'loading_page.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic>? adminData;
  const AdminDashboard({super.key, this.adminData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _usersExpanded = false;
  final Map<String, GlobalKey> _chartKeys = {
    'Total Registered Players': GlobalKey(),
    'Average Player Rating': GlobalKey(),
    'Male vs Female Registered Players': GlobalKey(),
    'Age Distribution of Players': GlobalKey(),
    'Registered Players by Region': GlobalKey(),
    'Male vs Female Players Per Game Mode': GlobalKey(),
    'Rewards Distribution By Gender and Level': GlobalKey(),
    'Most Played Game Mode By Age': GlobalKey(),
  };
  bool _quizContentExpanded = false;
  final Map<String, bool> _sortAscending = {};
  bool _isSidebarCollapsed = false;

  // ── Live analytics data from /api/admin/analytics ─────────────────────────
  Map<String, dynamic>? _analytics;
  bool _analyticsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);
    try {
      final token = widget.adminData?['token'] as String? ?? '';
      final res = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/admin/analytics'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          setState(() {
            _analytics = body['data'] as Map<String, dynamic>;
            _analyticsLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Analytics load error: $e');
    }
    setState(() => _analyticsLoading = false);
  }

  Future<void> _logoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
              Image.asset(
                "assets/images-icons/sadlogout.png",
                width: 80,
                height: 80,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.logout,
                    size: 80,
                    color: Color(0xFF046EB8),
                  );
                },
              ),
              const SizedBox(height: 15),
              const Text(
                "Logout Confirmation",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Are you sure you want to log out?",
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
                        side: const BorderSide(
                          color: Color(0xFF046EB8),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF046EB8),
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
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Logout",
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
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF94D2FD),
      body: Stack(
        children: [
          Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: _buildMainContent(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _isSidebarCollapsed ? 70 : 230,
              color: const Color(0xFF1C2736),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hamburger + logo row
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _isSidebarCollapsed = !_isSidebarCollapsed;
                        if (_isSidebarCollapsed) {
                          _usersExpanded = false;
                          _quizContentExpanded = false;
                        }
                      }),
                      child: SizedBox(
                        height: 60,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _isSidebarCollapsed
                              ? Center(child: _buildHamburger())
                              : Row(
                            children: [
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: SizedBox(
                                  width: 140,
                                  child: Image.asset(
                                    'assets/images-logo/newhomepagelogo.png',
                                    fit: BoxFit.contain,
                                    alignment: Alignment.centerLeft,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              _buildHamburger(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Menu items
                  _buildMenuItem(Icons.analytics_outlined, 'Analytics', 0),
                  const SizedBox(height: 4),
                  _buildMenuItem(Icons.leaderboard_outlined, 'Leaderboard', 1),

                  const SizedBox(height: 4),
                  // Users
                  _isSidebarCollapsed
                      ? _buildCollapsedDropdownMenu(
                    Icons.people_outline,
                    'Users',
                    [
                      {
                        'icon': Icons.person_outline,
                        'title': 'Players',
                        'index': 3,
                      },
                      {
                        'icon': Icons.admin_panel_settings_outlined,
                        'title': 'Admins',
                        'index': 4,
                      },
                    ],
                  )
                      : _buildExpandableMenuItem(
                    Icons.people_outline,
                    'Users',
                    2,
                    _usersExpanded,
                        () {
                      setState(() {
                        _usersExpanded = !_usersExpanded;
                      });
                    },
                  ),

                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      heightFactor: _usersExpanded && !_isSidebarCollapsed
                          ? 1.0
                          : 0.0,
                      child: Column(
                        children: [
                          _buildSubMenuItem(Icons.person_outline, 'Players', 3),
                          _buildSubMenuItem(
                            Icons.admin_panel_settings_outlined,
                            'Admins',
                            4,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                  // Quiz Content
                  _isSidebarCollapsed
                      ? _buildCollapsedDropdownMenu(
                    Icons.quiz_outlined,
                    'Quiz Content',
                    [
                      {
                        'icon': Icons.question_answer_outlined,
                        'title': 'Questions',
                        'index': 6,
                      },
                      {
                        'icon': Icons.speed_outlined,
                        'title': 'Difficulty',
                        'index': 7,
                      },
                    ],
                  )
                      : _buildExpandableMenuItem(
                    Icons.quiz_outlined,
                    'Quiz Content',
                    5,
                    _quizContentExpanded,
                        () {
                      setState(() {
                        _quizContentExpanded = !_quizContentExpanded;
                      });
                    },
                  ),

                  ClipRect(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      heightFactor: _quizContentExpanded && !_isSidebarCollapsed
                          ? 1.0
                          : 0.0,
                      child: Column(
                        children: [
                          _buildSubMenuItem(
                            Icons.question_answer_outlined,
                            'Questions',
                            6,
                          ),
                          _buildSubMenuItem(
                            Icons.speed_outlined,
                            'Difficulty',
                            7,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Profile section at bottom
                  Container(
                    decoration: !_isSidebarCollapsed
                        ? const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Color(0xFF2A3A52),
                          width: 1,
                        ),
                      ),
                    )
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFDD000),
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: widget.adminData?['image'] != null
                                ? Image.network(
                              widget.adminData!['image'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Color(0xFF046EB8),
                                size: 24,
                              ),
                            )
                                : const Icon(
                              Icons.person,
                              color: Color(0xFF046EB8),
                              size: 24,
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: !_isSidebarCollapsed
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 12),
                              AnimatedOpacity(
                                duration: const Duration(
                                  milliseconds: 250,
                                ),
                                opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                                child: Text(
                                  widget.adminData?['username'] ?? 'Admin',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),


          ],
        );
      },
    );
  }

  Widget _buildHamburger() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 16, height: 2, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.80), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        Container(width: 16, height: 2, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.80), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 4),
        Container(width: 16, height: 2, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.80), borderRadius: BorderRadius.circular(2))),
      ],
    );
  }

  Widget _buildCollapsedDropdownMenu(
      IconData icon,
      String title,
      List<Map<String, dynamic>> items,
      ) {
    return PopupMenuButton<int>(
      tooltip: title,
      offset: const Offset(70, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      color: const Color(0xFF1C2736),
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<int>(
            value: item['index'],
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item['icon'], size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  item['title'],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      onSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(icon, color: const Color(0xFFFFFFFF), size: 20),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          if (index == 0 || index == 1) {
            _usersExpanded = false;
            _quizContentExpanded = false;
          }
        });
      },
      child: Tooltip(
        message: _isSidebarCollapsed ? title : '',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF046EB8) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: _isSidebarCollapsed
              ? Center(child: Icon(icon, color: const Color(0xFFFFFFFF), size: 20))
              : Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(icon, color: const Color(0xFFFFFFFF), size: 20),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: 1.0,
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem(
      IconData icon,
      String title,
      int index,
      bool isExpanded,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Icon(icon, color: const Color(0xFFFFFFFF), size: 20),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: !_isSidebarCollapsed
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _isSidebarCollapsed ? 0.0 : 1.0,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 13,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ],
              )
                  : const SizedBox.shrink(),
            ),
            const Spacer(),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isSidebarCollapsed ? 0.0 : 1.0,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: isExpanded ? 0.5 : 0,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFFFFFFFF),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubMenuItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(left: 24, right: 8, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF046EB8) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: 1.0,
              child: Icon(icon, color: const Color(0xFFFFFFFF), size: 18),
            ),
            const SizedBox(width: 12),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: 1.0,
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 12,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          // Centered logo
          Center(
            child: Image.asset(
              'assets/images-logo/newhomepagelogo.png',
              height: 35,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/splashscreen/starbooks.png',
                  height: 35,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                );
              },
            ),
          ),

          // Right side buttons
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                // Export button
                if (_selectedIndex == 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextButton.icon(
                      onPressed: _showExportDialog,
                      icon: const Icon(
                        Icons.upload_outlined,
                        size: 16,
                        color: Colors.black87,
                      ),
                      label: const Text(
                        'Export',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],

                // Profile circle with logout functionality
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _logoutDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFDD000),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: () {
                          final img = widget.adminData?['image'];
                          if (img != null && (img as String).isNotEmpty) {
                            final imageUrl = (img.startsWith('http://') || img.startsWith('https://'))
                                ? img
                                : 'http://127.0.0.1:8000/$img';
                            return Image.network(
                              imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Color(0xFF046EB8),
                                size: 24,
                              ),
                            );
                          }
                          return const Icon(
                            Icons.person,
                            color: Color(0xFF046EB8),
                            size: 24,
                          );
                        }(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Show leaderboard when index is 1
    if (_selectedIndex == 1) {
      return const AdminLeaderboard();
    }

    // Show players list when index is 3
    if (_selectedIndex == 3) {
      return const AdminPlayersPage();
    }

    // Show admins list when index is 4
    if (_selectedIndex == 4) {
      return AdminUsersAdminsPage(
        currentAdminId: widget.adminData?['id']?.toString(),
      );
    }

    // Questions (index 6)
    if (_selectedIndex == 6) {
      return const AdminQuizQuestionsPage();
    }

    // Difficulty (index 7)
    if (_selectedIndex == 7) {
      return const AdminQuizDifficultyPage();
    }

    // Show analytics for all other cases (index 0 or others)
    if (_analyticsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF046EB8)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Top stat cards
          Row(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Total Registered Players'],
                  child: _buildStatCard(
                    _analytics?['total_players']?.toString() ?? '—',
                    'Total Registered Players',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Average Player Rating'],
                  child: _buildRatingStatCard(
                    _analytics?['average_rating']?.toString() ?? '—',
                    'Average Player Rating',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // First row of charts
          Row(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Male vs Female Registered Players'],
                  child: _buildChartCard(
                    'Male vs Female Registered Players',
                    _buildPieChart(isAscending: _sortAscending.containsKey('Male vs Female Registered Players')
                        ? _sortAscending['Male vs Female Registered Players']
                        : null),
                    legends: [
                      {'color': const Color(0xFF046EB8), 'label': 'Male'},
                      {'color': const Color(0xFF00C9B1), 'label': 'Female'},
                    ],
                    sortable: true,
                    // Pie: index 0=Male(75%), index 1=Female(25%), starting from top (-π/2)
                    hitTest: (pos, size) {
                      final cx = size.width / 2, cy = size.height / 2;
                      final r = size.height / 2 * 0.7;
                      final dx = pos.dx - cx, dy = pos.dy - cy;
                      if (dx * dx + dy * dy > r * r) return -1;
                      final angle = (math.atan2(dy, dx) + math.pi / 2 + math.pi * 2) % (math.pi * 2);
                      final isAsc = _sortAscending['Male vs Female Registered Players'];
                      // ASC: Female(25%) drawn first, then Male; DESC/default: Male(75%) first
                      if (isAsc == true) return angle < 0.25 * math.pi * 2 ? 1 : 0;
                      return angle < 0.75 * math.pi * 2 ? 0 : 1;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Age Distribution of Players'],
                  child: _buildChartCard(
                    'Age Distribution of Players',
                    _buildBarChart(isAscending: _sortAscending.containsKey('Age Distribution of Players')
                        ? _sortAscending['Age Distribution of Players']!
                        : null),
                    legends: [
                      {'color': const Color(0xFF4A90D9), 'label': 'Number of Players'},
                    ],
                    sortable: true,
                    // 7 bars: barWidth = width/(7*2), bar i starts at i*bw*2 + bw/2
                    hitTest: (pos, size) {
                      const labelH = 18.0;
                      if (pos.dy > size.height - labelH) return -1;
                      final bw = size.width / 14;
                      for (int i = 0; i < 7; i++) {
                        final x = i * bw * 2 + bw / 2;
                        if (pos.dx >= x && pos.dx <= x + bw) return i;
                      }
                      return -1;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Second row of charts
          Row(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Registered Players by Region'],
                  child: _buildChartCard(
                    'Registered Players by Region',
                    _buildHorizontalBarChart(isAscending: _sortAscending.containsKey('Registered Players by Region')
                        ? _sortAscending['Registered Players by Region']!
                        : null),
                    legends: [
                      {'color': const Color(0xFF5B6FE8), 'label': 'Players per Region'},
                    ],
                    sortable: true,
                    // 10 horizontal bars: barHeight = height/(10*1.5), row i at y=i*bh*1.5
                    hitTest: (pos, size) {
                      final bh = size.height / 15;
                      for (int i = 0; i < 10; i++) {
                        final y = i * bh * 1.5;
                        if (pos.dy >= y && pos.dy <= y + bh) return i;
                      }
                      return -1;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Male vs Female Players Per Game Mode'],
                  child: _buildChartCard(
                    'Male vs Female Players Per Game Mode',
                    _buildGroupedBarChart(isAscending: _sortAscending.containsKey('Male vs Female Players Per Game Mode')
                        ? _sortAscending['Male vs Female Players Per Game Mode']
                        : null),
                    legends: [
                      {'color': const Color(0xFF046EB8), 'label': 'Male'},
                      {'color': const Color(0xFF27AE60), 'label': 'Female'},
                    ],
                    sortable: true,
                    // 4 groups × 2 bars: barWidth = width/(4*3)
                    // group i at x=i*bw*3; male=[x..x+bw], female=[x+bw..x+2bw]
                    hitTest: (pos, size) {
                      const labelH = 18.0;
                      if (pos.dy > size.height - labelH) return -1;
                      final bw = size.width / 12;
                      for (int i = 0; i < 4; i++) {
                        final gx = i * bw * 3;
                        if (pos.dx >= gx && pos.dx < gx + bw) return i * 2;       // Male
                        if (pos.dx >= gx + bw && pos.dx < gx + bw * 2) return i * 2 + 1; // Female
                      }
                      return -1;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Third row of charts
          Row(
            children: [
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Rewards Distribution By Gender and Level'],
                  child: _buildChartCard(
                    'Rewards Distribution By Gender and Level',
                    _buildStackedBarChart(isAscending: _sortAscending.containsKey('Rewards Distribution By Gender and Level')
                        ? _sortAscending['Rewards Distribution By Gender and Level']
                        : null),
                    legends: [
                      {'color': const Color(0xFF046EB8), 'label': 'Male'},
                      {'color': const Color(0xFF9B59B6), 'label': 'Female'},
                    ],
                    sortable: true,
                    // 3 groups, barWidth = width/(3*2), bar at x=i*bw*2+bw/2
                    // Male fills full height, Female overlaid on top portion
                    // maleFracs=[0.7,0.55,0.4], femaleFracs=[0.4,0.3,0.2]
                    hitTest: (pos, size) {
                      const labelH = 18.0;
                      final chartH = size.height - labelH;
                      if (pos.dy > chartH) return -1;
                      final bw = size.width / 6;
                      const maleFracs = [0.7, 0.55, 0.4];
                      const femaleFracs = [0.4, 0.3, 0.2];
                      for (int i = 0; i < 3; i++) {
                        final x = i * bw * 2 + bw / 2;
                        if (pos.dx >= x && pos.dx < x + bw) {
                          // Female overlay sits at top of male bar
                          final femaleTop = chartH - chartH * maleFracs[i];
                          final femaleBot = femaleTop + chartH * femaleFracs[i];
                          if (pos.dy >= femaleTop && pos.dy <= femaleBot) return i * 2 + 1;
                          return i * 2; // Male base
                        }
                      }
                      return -1;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RepaintBoundary(
                  key: _chartKeys['Most Played Game Mode By Age'],
                  child: _buildChartCard(
                    'Most Played Game Mode By Age',
                    _buildMultiColorBarChart(isAscending: _sortAscending.containsKey('Most Played Game Mode By Age')
                        ? _sortAscending['Most Played Game Mode By Age']
                        : null),
                    legends: [
                      {'color': const Color(0xFFFDD000), 'label': 'Easy'},
                      {'color': const Color(0xFF4A90D9), 'label': 'Average'},
                      {'color': const Color(0xFF9B59B6), 'label': 'Difficult'},
                      {'color': const Color(0xFFE67E22), 'label': 'Battle'},
                    ],
                    sortable: true,
                    // 4 age groups × 4 mode bars: groupWidth=width/4, barWidth=gw/5
                    // bar j in group i at x = i*gw + j*bw
                    hitTest: (pos, size) {
                      const labelH = 18.0;
                      if (pos.dy > size.height - labelH) return -1;
                      final gw = size.width / 4;
                      final bw = gw / 5;
                      for (int i = 0; i < 4; i++) {
                        for (int j = 0; j < 4; j++) {
                          final x = i * gw + j * bw;
                          if (pos.dx >= x && pos.dx < x + bw * 0.85) return i * 4 + j;
                        }
                      }
                      return -1;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFDD000), size: 32),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontFamily: 'Poppins',
            )),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, {List<Map<String, dynamic>>? legends, bool sortable = false, ChartHitTest? hitTest}) {
    final isSorted = sortable && _sortAscending.containsKey(title);
    final isAscending = _sortAscending[title] ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              Row(
                children: [
                  if (sortable) ...[
                    Tooltip(
                      message: isSorted
                          ? (isAscending ? 'Ascending — click for Descending' : 'Descending — click for Ascending')
                          : 'Sort',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _toggleSort(title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSorted
                                    ? (isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                                    : Icons.swap_vert_rounded,
                                size: 18,
                                color: isSorted ? const Color(0xFF046EB8) : Colors.black45,
                              ),
                              if (isSorted) ...[
                                const SizedBox(width: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF046EB8).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAscending ? 'ASC' : 'DESC',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF046EB8),
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Tooltip(
                    message: 'Export chart',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _exportChart(title),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.upload_outlined,
                          size: 18,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: InteractiveChart(title: title, chart: chart, hitTest: hitTest),
          ),
          if (legends != null && legends.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: legends.map((l) =>
                  _buildLegendDot(l['color'] as Color, l['label'] as String)
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleSort(String chartTitle) {
    setState(() {
      _sortAscending[chartTitle] = !(_sortAscending[chartTitle] ?? false);
    });
  }

  void _showExportDialog() {
    final List<String> chartTitles = [
      'Total Registered Players',
      'Average Player Rating',
      'Male vs Female Registered Players',
      'Age Distribution of Players',
      'Registered Players by Region',
      'Male vs Female Players Per Game Mode',
      'Rewards Distribution By Gender and Level',
      'Most Played Game Mode By Age',
    ];

    Map<String, bool> selectedCharts = {
      for (var title in chartTitles) title: false,
    };
    bool selectAll = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Charts',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select charts to export',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    title: const Text(
                      'Select All',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    value: selectAll,
                    onChanged: (value) {
                      setDialogState(() {
                        selectAll = value ?? false;
                        for (var key in selectedCharts.keys) {
                          selectedCharts[key] = selectAll;
                        }
                      });
                    },
                    activeColor: const Color(0xFF046EB8),
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Column(
                        children: chartTitles.map((title) {
                          return CheckboxListTile(
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                              ),
                            ),
                            value: selectedCharts[title],
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCharts[title] = value ?? false;
                                selectAll = selectedCharts.values.every((v) => v);
                              });
                            },
                            activeColor: const Color(0xFF046EB8),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Export Format',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExport(selectedCharts, 'PNG', context),
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text('PNG', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExport(selectedCharts, 'PDF', context),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('PDF', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _performExport(selectedCharts, 'CSV', context),
                          icon: const Icon(Icons.table_chart, size: 18),
                          label: const Text('CSV', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF046EB8),
                            side: const BorderSide(color: Color(0xFF046EB8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Color(0xFF046EB8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _performExport(Map<String, bool> selectedCharts, String format, BuildContext dialogContext) {
    final selected = selectedCharts.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one chart to export',
              style: TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    _showLoadingAndExport(selected, format, dialogContext);
  }

  Future<Uint8List?> _captureWidget(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  void _showLoadingAndExport(List<String> selected, String format, BuildContext dialogContext) {
    Navigator.pop(dialogContext);
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Center(
        child: LoadingWidget(message: 'Preparing $format export...', width: 380, height: 240),
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        if (format == 'CSV') {
          await _downloadCSV(selected);
        } else if (format == 'PNG') {
          await _downloadPNG(selected);
        } else if (format == 'PDF') {
          await _downloadPDF(selected);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  void _triggerBrowserDownload(Uint8List bytes, String filename, String mimeType) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..setAttribute('download', filename);
    web.document.body!.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }

  Future<void> _downloadPNG(List<String> selected) async {
    final List<Uint8List> chartBytes = [];
    final List<String> captured = [];
    for (final name in selected) {
      final key = _chartKeys[name];
      if (key == null) continue;
      final bytes = await _captureWidget(key);
      if (bytes != null) {
        chartBytes.add(bytes);
        captured.add(name);
      }
    }
    if (chartBytes.isEmpty) return;

    // Decode chart images
    final List<ui.Image> chartImages = [];
    for (final b in chartBytes) {
      final codec = await ui.instantiateImageCodec(b);
      final frame = await codec.getNextFrame();
      chartImages.add(frame.image);
    }

    // For each chart, render a count summary beneath it using Canvas text
    const double padding = 20.0;       // gap between charts
    const double tablePad = 14.0;      // inner padding of data table
    const double rowH = 18.0;          // height per data row
    const double dotSize = 8.0;
    const double headerH = 22.0;       // "Data Summary" label row
    const double dividerH = 1.0;
    const double fontSize = 11.0;

    // We'll draw everything into one tall canvas
    final List<double> blockHeights = [];
    for (int i = 0; i < chartImages.length; i++) {
      final entries = _chartTooltipData[captured[i]] ?? [];
      final tableH = entries.isEmpty
          ? 0.0
          : tablePad * 2 + headerH + dividerH + 4 + entries.length * rowH;
      blockHeights.add(chartImages[i].height.toDouble() + (entries.isEmpty ? 0 : tableH + 12));
    }

    final int totalWidth = chartImages.map((img) => img.width).reduce((a, b) => a > b ? a : b);
    final double totalHeight =
        blockHeights.reduce((a, b) => a + b) + padding * (chartImages.length - 1) + padding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, totalWidth.toDouble(), totalHeight),
      Paint()..color = Colors.white,
    );

    double offsetY = padding;

    for (int i = 0; i < chartImages.length; i++) {
      final img = chartImages[i];
      final chartName = captured[i];
      final entries = _chartTooltipData[chartName] ?? [];

      // Draw chart image
      canvas.drawImage(img, Offset(0, offsetY), Paint());
      offsetY += img.height.toDouble();

      if (entries.isNotEmpty) {
        offsetY += 12;

        // Table background
        final tableH = tablePad * 2 + headerH + dividerH + 4 + entries.length * rowH;
        final tableRect = Rect.fromLTWH(tablePad, offsetY, totalWidth - tablePad * 2, tableH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(tableRect, const Radius.circular(8)),
          Paint()..color = const Color(0xFFF5F7FA),
        );
        // Border
        canvas.drawRRect(
          RRect.fromRectAndRadius(tableRect, const Radius.circular(8)),
          Paint()
            ..color = const Color(0xFFDDE3EC)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );

        // "Data Summary" header
        double ty = offsetY + tablePad;
        _drawText(canvas, 'Data Summary',
            Offset(tablePad * 2, ty),
            fontSize: 10,
            color: const Color(0xFF6B7280),
            bold: true,
            maxWidth: totalWidth - tablePad * 4);
        ty += headerH;

        // Divider
        canvas.drawLine(
          Offset(tablePad * 2, ty),
          Offset(totalWidth - tablePad * 2, ty),
          Paint()..color = const Color(0xFFDDE3EC)..strokeWidth = 0.8,
        );
        ty += dividerH + 4;

        // Data rows
        final double halfW = (totalWidth - tablePad * 4) / 2;

        // Clean special characters that Canvas TextPainter can't render
        String cl(String s) => s
            .replaceAll('\u2013', '-').replaceAll('\u2014', '-')
            .replaceAll('\u2022', '*').replaceAll('\u2019', "'")
            .replaceAll('\u2026', '...').trim();

        for (int r = 0; r < entries.length; r += 2) {
          final left = entries[r];
          final right = r + 1 < entries.length ? entries[r + 1] : null;

          // Left entry
          _drawDot(canvas, Offset(tablePad * 2 + dotSize / 2, ty + rowH / 2), left.color);
          _drawText(canvas, cl(left.label),
              Offset(tablePad * 2 + dotSize + 6, ty + (rowH - fontSize) / 2),
              fontSize: fontSize, color: const Color(0xFF6B7280), maxWidth: halfW - 90);
          _drawText(canvas, left.value,
              Offset(tablePad * 2 + halfW - 60, ty + (rowH - fontSize) / 2),
              fontSize: fontSize, color: const Color(0xFF111827), bold: true, maxWidth: 80);

          // Right entry
          if (right != null) {
            final rx = tablePad * 2 + halfW + 12;
            _drawDot(canvas, Offset(rx + dotSize / 2, ty + rowH / 2), right.color);
            _drawText(canvas, cl(right.label),
                Offset(rx + dotSize + 6, ty + (rowH - fontSize) / 2),
                fontSize: fontSize, color: const Color(0xFF6B7280), maxWidth: halfW - 90);
            _drawText(canvas, right.value,
                Offset(rx + halfW - 60, ty + (rowH - fontSize) / 2),
                fontSize: fontSize, color: const Color(0xFF111827), bold: true, maxWidth: 80);
          }

          ty += rowH;
        }

        offsetY += tableH;
      }

      offsetY += padding;
    }

    final picture = recorder.endRecording();
    final stitched = await picture.toImage(totalWidth, totalHeight.ceil());
    final byteData = await stitched.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    _triggerBrowserDownload(
      byteData.buffer.asUint8List(),
      'starbooks_analytics_${DateTime.now().millisecondsSinceEpoch}.png',
      'image/png',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Downloaded ${selected.length} chart(s) as one PNG!',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  /// Helper: draw a filled circle dot at [center] with [color].
  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 4, Paint()..color = color);
  }

  /// Helper: draw text using [TextPainter].
  void _drawText(
      Canvas canvas,
      String text,
      Offset offset, {
        double fontSize = 11,
        Color color = const Color(0xFF111827),
        bool bold = false,
        double maxWidth = 200,
      }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  Future<void> _downloadPDF(List<String> selected) async {
    final List<Uint8List> images = [];
    final List<String> captured = [];
    for (final name in selected) {
      final key = _chartKeys[name];
      if (key == null) continue;
      final bytes = await _captureWidget(key);
      if (bytes != null) {
        images.add(bytes);
        captured.add(name);
      }
    }
    if (images.isEmpty) return;

    final pdf = pw.Document();
    final pwImages = images.map((b) => pw.MemoryImage(b)).toList();

    // PdfColor helper from hex int
    PdfColor hexToPdf(int hex) => PdfColor(
      ((hex >> 16) & 0xFF) / 255,
      ((hex >> 8) & 0xFF) / 255,
      (hex & 0xFF) / 255,
    );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (ctx) => [
        // ── Header ──────────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: hexToPdf(0xFF046EB8),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Starbooks Whiz Challenge',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              ),
              pw.Text(
                'Analytics Report',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Generated: ${DateTime.now().toString().substring(0, 19)}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 20),

        // ── One block per chart ──────────────────────────────────────────
        ...List.generate(pwImages.length, (i) {
          final chartName = captured[i];
          final entries = _chartTooltipData[chartName] ?? [];

          // Helper: clean label of special chars that don't render in default PDF font
          String cleanLabel(String s) => s
              .replaceAll('\u2013', '-')   // en-dash
              .replaceAll('\u2014', '-')   // em-dash
              .replaceAll('\u2022', '*')   // bullet
              .replaceAll('\u2019', "'")   // right single quote
              .replaceAll('\u00e2', '')    // corrupted UTF artifact
              .replaceAll('\u2026', '...') // ellipsis
              .trim();

          // Build two-column grid for the data rows (max 2 per row)
          final List<pw.Widget> dataRows = [];
          for (int r = 0; r < entries.length; r += 2) {
            final left = entries[r];
            final right = r + 1 < entries.length ? entries[r + 1] : null;

            // Use rounded rect instead of circle — PDF circle rendering can corrupt
            pw.Widget colorDot(Color c) => pw.Container(
              width: 8, height: 8,
              decoration: pw.BoxDecoration(
                color: hexToPdf(c.value & 0xFFFFFF),
                borderRadius: pw.BorderRadius.circular(4),
              ),
            );

            dataRows.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  children: [
                    // left cell
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          colorDot(left.color),
                          pw.SizedBox(width: 5),
                          pw.Expanded(
                            child: pw.Text(
                              cleanLabel(left.label),
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            left.value,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    // right cell (may be empty)
                    pw.Expanded(
                      child: right == null
                          ? pw.SizedBox()
                          : pw.Row(
                        children: [
                          colorDot(right.color),
                          pw.SizedBox(width: 5),
                          pw.Expanded(
                            child: pw.Text(
                              cleanLabel(right.label),
                              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                            ),
                          ),
                          pw.SizedBox(width: 4),
                          pw.Text(
                            right.value,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 28),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Chart title bar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border(left: pw.BorderSide(color: hexToPdf(0xFF046EB8), width: 3)),
                  ),
                  child: pw.Text(
                    chartName,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 8),

                // Chart image
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(pwImages[i], fit: pw.BoxFit.contain, height: 180),
                ),

                // Data counts table
                if (entries.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Data Summary',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(height: 0.5, color: PdfColors.grey300),
                        pw.SizedBox(height: 6),
                        ...dataRows,
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    ));

    final pdfBytes = await pdf.save();
    _triggerBrowserDownload(
      pdfBytes,
      'starbooks_analytics_${DateTime.now().millisecondsSinceEpoch}.pdf',
      'application/pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Downloaded ${selected.length} chart(s) as one PDF!',
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  Future<void> _downloadCSV(List<String> selected) async {
    // Build CSV rows directly from _chartTooltipData so it's always accurate & complete
    final buffer = StringBuffer();
    buffer.writeln('Starbooks Whiz Challenge - Analytics Export');
    buffer.writeln('"Generated","${DateTime.now().toString().substring(0, 19)}"');
    buffer.writeln();

    // Static stat cards
    if (selected.contains('Total Registered Players')) {
      buffer.writeln('"=== Total Registered Players ==="');
      buffer.writeln('"Metric","Value"');
      buffer.writeln('"Total Registered Players","${_analytics?['total_players'] ?? '—'}"');
      buffer.writeln();
    }
    if (selected.contains('Average Feedback')) {
      buffer.writeln('"=== Average Feedback ==="');
      buffer.writeln('"Metric","Value"');
      buffer.writeln('"Average Feedback","${_analytics?['average_rating'] ?? '—'}"');
      buffer.writeln();
    }

    // Chart cards — pull every entry from _chartTooltipData
    final chartKeys = [
      'Male vs Female Registered Players',
      'Age Distribution of Players',
      'Registered Players by Region',
      'Male vs Female Players Per Game Mode',
      'Rewards Distribution By Gender and Level',
      'Most Played Game Mode By Age',
    ];

    for (final name in chartKeys) {
      if (!selected.contains(name)) continue;
      final entries = _chartTooltipData[name] ?? [];
      if (entries.isEmpty) continue;

      buffer.writeln('"=== $name ==="');
      buffer.writeln('"Label","Value"');
      for (final e in entries) {
        // Clean label: remove bullet characters, trim spaces
        final cleanLabel = e.label.replaceAll('•', '-').trim();
        // Clean value: strip non-numeric suffix for the number column
        buffer.writeln('"$cleanLabel","${e.value}"');
      }
      buffer.writeln();
    }

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    _triggerBrowserDownload(
      bytes,
      'starbooks_charts_${DateTime.now().millisecondsSinceEpoch}.csv',
      'text/csv',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('CSV downloaded!', style: TextStyle(fontFamily: 'Poppins')),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _exportChart(String chartTitle) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Chart',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                chartTitle,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export Format',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              // PNG
              _exportOptionBlue(
                icon: Icons.image_outlined,
                label: 'Export as PNG',
                onTap: () => _showLoadingAndExport([chartTitle], 'PNG', dialogCtx),
              ),
              const SizedBox(height: 10),
              // PDF
              _exportOptionBlue(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Export as PDF',
                onTap: () => _showLoadingAndExport([chartTitle], 'PDF', dialogCtx),
              ),
              const SizedBox(height: 10),
              // CSV
              _exportOptionBlue(
                icon: Icons.table_chart_outlined,
                label: 'Export as CSV',
                onTap: () => _showLoadingAndExport([chartTitle], 'CSV', dialogCtx),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Color(0xFF046EB8),
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

  Widget _exportOptionBlue({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    const color = Color(0xFF046EB8);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart({bool? isAscending}) {
    final gender = (_analytics?['gender_distribution'] as List<dynamic>?) ?? [];
    final male   = (gender.firstWhere((g) => g['label'] == 'Male',   orElse: () => {'count': 0})['count'] as num).toDouble();
    final female = (gender.firstWhere((g) => g['label'] == 'Female', orElse: () => {'count': 0})['count'] as num).toDouble();
    return CustomPaint(
      painter: PieChartPainter(isAscending: isAscending, male: male, female: female),
      child: Container(),
    );
  }

  Widget _buildBarChart({bool? isAscending}) {
    final ages = (_analytics?['age_distribution'] as List<dynamic>?) ?? [];
    return CustomPaint(
      painter: BarChartPainter(isAscending: isAscending, data: ages),
      child: Container(),
    );
  }

  Widget _buildHorizontalBarChart({bool? isAscending}) {
    final regions = (_analytics?['players_by_region'] as List<dynamic>?) ?? [];
    return CustomPaint(
      painter: HorizontalBarChartPainter(isAscending: isAscending, data: regions),
      child: Container(),
    );
  }

  Widget _buildGroupedBarChart({bool? isAscending}) {
    final modes = (_analytics?['gender_by_game_mode'] as List<dynamic>?) ?? [];
    return CustomPaint(
      painter: GroupedBarChartPainter(isAscending: isAscending, data: modes),
      child: Container(),
    );
  }

  Widget _buildStackedBarChart({bool? isAscending}) {
    final badges = (_analytics?['badges_by_gender_level'] as List<dynamic>?) ?? [];
    return CustomPaint(
      painter: StackedBarChartPainter(isAscending: isAscending, data: badges),
      child: Container(),
    );
  }

  Widget _buildMultiColorBarChart({bool? isAscending}) {
    final byAge = (_analytics?['game_mode_by_age'] as List<dynamic>?) ?? [];
    return CustomPaint(
      painter: MultiColorBarChartPainter(isAscending: isAscending, data: byAge),
      child: Container(),
    );
  }
}

// ── Tooltip data definitions ─────────────────────────────────────────────────

const _chartTooltipData = {
  'Male vs Female Registered Players': [
    _TooltipEntry(label: 'Male', value: '1,200 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Female', value: '1,148 players', color: Color(0xFF00C9B1)),
  ],
  'Age Distribution of Players': [
    _TooltipEntry(label: '7–9',   value: '280 players',  color: Color(0xFF046EB8)),
    _TooltipEntry(label: '10–12', value: '470 players',  color: Color(0xFF27AE60)),
    _TooltipEntry(label: '13–15', value: '850 players',  color: Color(0xFFE67E22)),
    _TooltipEntry(label: '16–18', value: '380 players',  color: Color(0xFF9B59B6)),
    _TooltipEntry(label: '19–21', value: '200 players',  color: Color(0xFFFDD000)),
    _TooltipEntry(label: '22–25', value: '110 players',  color: Color(0xFF4A90D9)),
    _TooltipEntry(label: '26+',   value: '58 players',   color: Color(0xFF00C9B1)),
  ],
  'Registered Players by Region': [
    _TooltipEntry(label: 'NCR',        value: '520 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'CAR',        value: '384 players', color: Color(0xFF27AE60)),
    _TooltipEntry(label: 'Region I',   value: '329 players', color: Color(0xFFE67E22)),
    _TooltipEntry(label: 'Region II',  value: '302 players', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: 'Region III', value: '275 players', color: Color(0xFF4A90D9)),
    _TooltipEntry(label: 'Region IV-A', value: '247 players', color: Color(0xFFFDD000)),
    _TooltipEntry(label: 'Region V',   value: '220 players', color: Color(0xFF5B6FE8)),
    _TooltipEntry(label: 'Region VI',  value: '192 players', color: Color(0xFF00C9B1)),
    _TooltipEntry(label: 'Region VII', value: '165 players', color: Color(0xFFE67E22)),
    _TooltipEntry(label: 'Region VIII', value: '55 players',  color: Color(0xFF046EB8)),
  ],
  'Male vs Female Players Per Game Mode': [
    _TooltipEntry(label: 'Easy — Male',       value: '480 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Easy — Female',     value: '620 players', color: Color(0xFF27AE60)),
    _TooltipEntry(label: 'Average — Male',    value: '570 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Average — Female',  value: '525 players', color: Color(0xFF27AE60)),
    _TooltipEntry(label: 'Difficult — Male',  value: '380 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Difficult — Female', value: '430 players', color: Color(0xFF27AE60)),
    _TooltipEntry(label: 'Battle — Male',     value: '335 players', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Battle — Female',   value: '286 players', color: Color(0xFF27AE60)),
  ],
  'Rewards Distribution By Gender and Level': [
    _TooltipEntry(label: 'Easy — Male',       value: '350 rewards', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Easy — Female',     value: '200 rewards', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: 'Average — Male',    value: '275 rewards', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Average — Female',  value: '150 rewards', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: 'Difficult — Male',  value: '200 rewards', color: Color(0xFF046EB8)),
    _TooltipEntry(label: 'Difficult — Female', value: '100 rewards', color: Color(0xFF9B59B6)),
  ],
  'Most Played Game Mode By Age': [
    _TooltipEntry(label: '7–10  • Easy',      value: '400 plays', color: Color(0xFFFDD000)),
    _TooltipEntry(label: '7–10  • Average',   value: '300 plays', color: Color(0xFF4A90D9)),
    _TooltipEntry(label: '7–10  • Difficult', value: '200 plays', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: '7–10  • Battle',    value: '150 plays', color: Color(0xFFE67E22)),
    _TooltipEntry(label: '11–13 • Easy',      value: '500 plays', color: Color(0xFFFDD000)),
    _TooltipEntry(label: '11–13 • Average',   value: '550 plays', color: Color(0xFF4A90D9)),
    _TooltipEntry(label: '11–13 • Difficult', value: '300 plays', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: '11–13 • Battle',    value: '250 plays', color: Color(0xFFE67E22)),
    _TooltipEntry(label: '14–18 • Easy',      value: '350 plays', color: Color(0xFFFDD000)),
    _TooltipEntry(label: '14–18 • Average',   value: '600 plays', color: Color(0xFF4A90D9)),
    _TooltipEntry(label: '14–18 • Difficult', value: '650 plays', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: '14–18 • Battle',    value: '400 plays', color: Color(0xFFE67E22)),
    _TooltipEntry(label: '19+   • Easy',      value: '200 plays', color: Color(0xFFFDD000)),
    _TooltipEntry(label: '19+   • Average',   value: '350 plays', color: Color(0xFF4A90D9)),
    _TooltipEntry(label: '19+   • Difficult', value: '500 plays', color: Color(0xFF9B59B6)),
    _TooltipEntry(label: '19+   • Battle',    value: '550 plays', color: Color(0xFFE67E22)),
  ],
};

class _TooltipEntry {
  final String label;
  final String value;
  final Color color;
  const _TooltipEntry({required this.label, required this.value, required this.color});
}

// ── InteractiveChart ─────────────────────────────────────────────────────────

/// Returns the index of the hovered element, or -1 if none.
typedef ChartHitTest = int Function(Offset pos, Size size);

class InteractiveChart extends StatefulWidget {
  final String title;
  final Widget chart;
  final ChartHitTest? hitTest;
  const InteractiveChart({super.key, required this.title, required this.chart, this.hitTest});

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  bool _hovering = false;
  Offset _mousePos = Offset.zero;
  Size _chartSize = Size.zero;

  @override
  Widget build(BuildContext context) {
    final allEntries = _chartTooltipData[widget.title] ?? [];

    // Determine which single entry to show based on hovered element
    _TooltipEntry? visible;
    if (_hovering && allEntries.isNotEmpty && widget.hitTest != null && _chartSize != Size.zero) {
      final idx = widget.hitTest!(_mousePos, _chartSize);
      if (idx >= 0 && idx < allEntries.length) visible = allEntries[idx];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      onHover: (e) => setState(() => _mousePos = e.localPosition),
      child: GestureDetector(
        onTapDown: (d) => setState(() {
          _hovering = true;
          _mousePos = d.localPosition;
        }),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _chartSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: widget.chart),
                if (visible != null)
                  Positioned(
                    left: _tooltipLeft(_mousePos.dx, constraints.maxWidth),
                    top:  _tooltipTop(_mousePos.dy),
                    child: _buildTooltip(visible!),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _tooltipLeft(double x, double chartWidth) {
    const w = 180.0;
    return (x + 12 + w > chartWidth) ? x - w - 8 : x + 12;
  }

  double _tooltipTop(double y) => (y - 10).clamp(0.0, double.infinity);

  Widget _buildTooltip(_TooltipEntry e) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2736),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${e.label}  ',
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 10, color: Colors.white60,
                      ),
                    ),
                    TextSpan(
                      text: e.value,
                      style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 10,
                        fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class PieChartPainter extends CustomPainter {
  final bool? isAscending;
  final double male;
  final double female;
  const PieChartPainter({this.isAscending, this.male = 0, this.female = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 * 0.7;

    final total = male + female;
    final maleValue  = total > 0 ? male / total  : 0.75;
    final femaleValue = total > 0 ? female / total : 0.25;

    final sorted = isAscending == null
        ? [
      {'color': const Color(0xFF046EB8), 'sweep': maleValue},
      {'color': const Color(0xFF00C9B1), 'sweep': femaleValue},
    ]
        : (isAscending!
        ? [
      {'color': const Color(0xFF00C9B1), 'sweep': femaleValue},
      {'color': const Color(0xFF046EB8), 'sweep': maleValue},
    ]
        : [
      {'color': const Color(0xFF046EB8), 'sweep': maleValue},
      {'color': const Color(0xFF00C9B1), 'sweep': femaleValue},
    ]);

    double startAngle = -1.57;
    for (final slice in sorted) {
      paint.color = slice['color'] as Color;
      final sweep = (slice['sweep'] as double) * 2 * 3.1416;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweep, true, paint,
      );
      startAngle += sweep;
    }

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant PieChartPainter old) =>
      old.isAscending != isAscending || old.male != male || old.female != female;
}

// Custom painter for the upload icon
class UploadIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw arrow shaft
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.8),
      Offset(size.width / 2, size.height * 0.2),
      paint,
    );

    // Draw arrow head (left side)
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.2),
      Offset(size.width * 0.3, size.height * 0.4),
      paint,
    );

    // Draw arrow head (right side)
    canvas.drawLine(
      Offset(size.width / 2, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.4),
      paint,
    );

    // Draw base line
    paint.strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.9),
      Offset(size.width * 0.8, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BarChartPainter extends CustomPainter {
  final bool? isAscending;
  final List<dynamic> data; // age_distribution from API
  const BarChartPainter({this.isAscending, this.data = const []});

  @override
  void paint(Canvas canvas, Size size) {
    const allColors = [
      Color(0xFF046EB8), Color(0xFF27AE60), Color(0xFFE67E22),
      Color(0xFF9B59B6), Color(0xFFFDD000), Color(0xFF4A90D9), Color(0xFF00C9B1),
    ];

    final source = data.isNotEmpty ? data : [
      {'range': '0-12', 'count': 0}, {'range': '13-17', 'count': 0},
      {'range': '18-22', 'count': 0}, {'range': '23-29', 'count': 0},
      {'range': '30-39', 'count': 0}, {'range': '40+', 'count': 0},
    ];

    final maxCount = source.fold<double>(1, (m, e) => math.max(m, ((e['count'] ?? 0) as num).toDouble()));

    final items = source.asMap().entries.map((entry) => {
      'label': entry.value['range'] as String? ?? '',
      'value': ((entry.value['count'] ?? 0) as num).toDouble() / maxCount,
      'color': allColors[entry.key % allColors.length],
    }).toList();

    if (isAscending != null) {
      items.sort((a, b) => isAscending!
          ? (a['value'] as double).compareTo(b['value'] as double)
          : (b['value'] as double).compareTo(a['value'] as double));
    }

    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final barWidth = size.width / (items.length * 2);

    for (int i = 0; i < items.length; i++) {
      final paint = Paint()..color = items[i]['color'] as Color;
      final x = i * barWidth * 2 + barWidth / 2;
      final barH = chartHeight * (items[i]['value'] as double);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartHeight - barH, barWidth, barH),
          const Radius.circular(4),
        ),
        paint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: items[i]['label'] as String,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 8.5, fontFamily: 'Poppins'),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth * 2);
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter old) =>
      old.isAscending != isAscending || old.data != data;
}

class HorizontalBarChartPainter extends CustomPainter {
  final bool? isAscending;
  final List<dynamic> data; // players_by_region from API
  const HorizontalBarChartPainter({this.isAscending, this.data = const []});

  @override
  void paint(Canvas canvas, Size size) {
    const allColors = [
      Color(0xFF046EB8), Color(0xFF27AE60), Color(0xFFE67E22),
      Color(0xFF9B59B6), Color(0xFF4A90D9), Color(0xFFFDD000),
      Color(0xFF5B6FE8), Color(0xFF00C9B1), Color(0xFFE67E22), Color(0xFF046EB8),
    ];

    final source = data.isNotEmpty ? data : <dynamic>[];
    final maxCount = source.fold<double>(1, (m, e) => math.max(m, ((e['count'] ?? 0) as num).toDouble()));

    final items = source.asMap().entries.map((entry) => {
      'label': entry.value['region'] as String? ?? '',
      'value': ((entry.value['count'] ?? 0) as num).toDouble() / maxCount,
      'color': allColors[entry.key % allColors.length],
    }).toList();

    if (isAscending != null) {
      items.sort((a, b) => isAscending!
          ? (a['value'] as double).compareTo(b['value'] as double)
          : (b['value'] as double).compareTo(a['value'] as double));
    }

    if (items.isEmpty) return;

    const labelWidth = 68.0;
    final chartWidth = size.width - labelWidth;
    final barHeight = size.height / (items.length * 1.5);

    for (int i = 0; i < items.length; i++) {
      final y = i * barHeight * 1.5;
      final tp = TextPainter(
        text: TextSpan(
          text: items[i]['label'] as String,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 8.0, fontFamily: 'Poppins'),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 4);
      tp.paint(canvas, Offset(0, y + barHeight / 2 - tp.height / 2));

      final paint = Paint()..color = items[i]['color'] as Color;
      final barW = chartWidth * (items[i]['value'] as double);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(labelWidth, y, barW, barHeight), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HorizontalBarChartPainter old) =>
      old.isAscending != isAscending || old.data != data;
}

class GroupedBarChartPainter extends CustomPainter {
  final bool? isAscending;
  final List<dynamic> data; // gender_by_game_mode from API
  const GroupedBarChartPainter({this.isAscending, this.data = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final source = data.isNotEmpty ? data : [
      {'mode': 'Easy', 'male': 0, 'female': 0},
      {'mode': 'Average', 'male': 0, 'female': 0},
      {'mode': 'Difficult', 'male': 0, 'female': 0},
      {'mode': 'Battle', 'male': 0, 'female': 0},
    ];

    final maxVal = source.fold<double>(1, (m, e) =>
      math.max(m, math.max(((e['male'] ?? 0) as num).toDouble(), ((e['female'] ?? 0) as num).toDouble())));

    final groups = source.map((e) => {
      'label': e['mode'] as String? ?? '',
      'male':  ((e['male']   ?? 0) as num).toDouble() / maxVal,
      'female':((e['female'] ?? 0) as num).toDouble() / maxVal,
    }).toList();

    if (isAscending != null) {
      groups.sort((a, b) {
        final aT = (a['male'] as double) + (a['female'] as double);
        final bT = (b['male'] as double) + (b['female'] as double);
        return isAscending! ? aT.compareTo(bT) : bT.compareTo(aT);
      });
    }

    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final paint1 = Paint()..color = const Color(0xFF046EB8);
    final paint2 = Paint()..color = const Color(0xFF27AE60);
    final barWidth = size.width / (groups.length * 3);

    for (int i = 0; i < groups.length; i++) {
      final x = i * barWidth * 3;
      final mH = chartHeight * (groups[i]['male'] as double);
      final fH = chartHeight * (groups[i]['female'] as double);

      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - mH, barWidth, mH), const Radius.circular(4)), paint1);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x + barWidth, chartHeight - fH, barWidth, fH), const Radius.circular(4)), paint2);

      final tp = TextPainter(
        text: TextSpan(text: groups[i]['label'] as String,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 8.5, fontFamily: 'Poppins')),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth * 3);
      tp.paint(canvas, Offset(x + barWidth - tp.width / 2, chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(covariant GroupedBarChartPainter old) =>
      old.isAscending != isAscending || old.data != data;
}

class StackedBarChartPainter extends CustomPainter {
  final bool? isAscending;
  final List<dynamic> data; // badges_by_gender_level from API
  const StackedBarChartPainter({this.isAscending, this.data = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final source = data.isNotEmpty ? data : [
      {'level': 'Easy', 'male': 0, 'female': 0},
      {'level': 'Average', 'male': 0, 'female': 0},
      {'level': 'Difficult', 'male': 0, 'female': 0},
    ];

    final maxVal = source.fold<double>(1, (m, e) =>
      math.max(m, ((e['male'] ?? 0) as num).toDouble() + ((e['female'] ?? 0) as num).toDouble()));

    final groups = source.map((e) => {
      'label':  e['level'] as String? ?? '',
      'male':   ((e['male']   ?? 0) as num).toDouble() / maxVal,
      'female': ((e['female'] ?? 0) as num).toDouble() / maxVal,
    }).toList();

    if (isAscending != null) {
      groups.sort((a, b) {
        final aT = (a['male'] as double);
        final bT = (b['male'] as double);
        return isAscending! ? aT.compareTo(bT) : bT.compareTo(aT);
      });
    }

    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final paint1 = Paint()..color = const Color(0xFF046EB8);
    final paint2 = Paint()..color = const Color(0xFF9B59B6);
    final barWidth = size.width / (groups.length * 2);

    for (int i = 0; i < groups.length; i++) {
      final x = i * barWidth * 2 + barWidth / 2;
      final mH = chartHeight * (groups[i]['male'] as double);
      final fH = chartHeight * (groups[i]['female'] as double);

      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - mH, barWidth, mH), const Radius.circular(4)), paint1);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - mH, barWidth, fH), const Radius.circular(4)), paint2);

      final tp = TextPainter(
        text: TextSpan(text: groups[i]['label'] as String,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 8.5, fontFamily: 'Poppins')),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: barWidth * 2);
      tp.paint(canvas, Offset(x + barWidth / 2 - tp.width / 2, chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(covariant StackedBarChartPainter old) =>
      old.isAscending != isAscending || old.data != data;
}

class MultiColorBarChartPainter extends CustomPainter {
  final bool? isAscending;
  final List<dynamic> data; // game_mode_by_age from API
  const MultiColorBarChartPainter({this.isAscending, this.data = const []});

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFFFDD000), Color(0xFF4A90D9), Color(0xFF9B59B6), Color(0xFFE67E22),
    ];

    final source = data.isNotEmpty ? data : <dynamic>[];
    if (source.isEmpty) return;

    final maxVal = source.fold<double>(1, (m, e) {
      final vals = [(e['easy'] ?? 0), (e['average'] ?? 0), (e['difficult'] ?? 0), (e['battle'] ?? 0)];
      return math.max(m, vals.fold<double>(0, (s, v) => s + (v as num).toDouble()));
    });

    final groups = source.map((e) => {
      'label': e['age_range'] as String? ?? '',
      'values': [
        ((e['easy']      ?? 0) as num).toDouble() / maxVal,
        ((e['average']   ?? 0) as num).toDouble() / maxVal,
        ((e['difficult'] ?? 0) as num).toDouble() / maxVal,
        ((e['battle']    ?? 0) as num).toDouble() / maxVal,
      ],
    }).toList();

    if (isAscending != null) {
      groups.sort((a, b) {
        final aT = (a['values'] as List<double>).reduce((s, v) => s + v);
        final bT = (b['values'] as List<double>).reduce((s, v) => s + v);
        return isAscending! ? aT.compareTo(bT) : bT.compareTo(aT);
      });
    }

    const labelHeight = 18.0;
    final chartHeight = size.height - labelHeight;
    final groupWidth = size.width / groups.length;
    final barWidth = groupWidth / 5;

    for (int i = 0; i < groups.length; i++) {
      final values = groups[i]['values'] as List<double>;
      final groupX = i * groupWidth;

      for (int j = 0; j < 4; j++) {
        final paint = Paint()..color = colors[j];
        final h = chartHeight * values[j];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(groupX + j * barWidth, chartHeight - h, barWidth * 0.85, h),
            const Radius.circular(4),
          ),
          paint,
        );
      }

      final tp = TextPainter(
        text: TextSpan(text: groups[i]['label'] as String,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 8.5, fontFamily: 'Poppins')),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupWidth);
      tp.paint(canvas, Offset(groupX + groupWidth / 2 - tp.width / 2, chartHeight + 3));
    }
  }

  @override
  bool shouldRepaint(covariant MultiColorBarChartPainter old) =>
      old.isAscending != isAscending || old.data != data;
}