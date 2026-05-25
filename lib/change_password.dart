import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'audio_service.dart';
import 'loading_page.dart'; // ✅ Loading screen
import 'config.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String userId;

  const ChangePasswordDialog({super.key, required this.userId});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool showOld = false;
  bool showNew = false;
  bool showConfirm = false;
  bool saving = false;
  bool oldPasswordError = false;
  bool newPasswordError = false;
  bool confirmPasswordError = false;
  bool _hasFormChanged = false;

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // Add listeners to track changes
    oldPasswordController.addListener(() => setState(() => _hasFormChanged = true));
    newPasswordController.addListener(() => setState(() => _hasFormChanged = true));
    confirmPasswordController.addListener(() => setState(() => _hasFormChanged = true));
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      oldPasswordError = false;
      newPasswordError = false;
      confirmPasswordError = false;
    });
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
        borderSide: BorderSide(
          color: hasError ? Colors.red : Colors.grey,
          width: hasError ? 2 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: hasError ? Colors.red : const Color(0xFF046EB8),
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: _isMobile ? MediaQuery.of(context).size.width * 0.82 : 350,
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success image
                Image.asset(
                  'assets/images-logo/success.png',
                  width: _isMobile ? 110 : 160,
                  height: _isMobile ? 110 : 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Text(
                  "Password Changed!",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: _isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF046EB8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Your password has been updated successfully.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDD000),
                    foregroundColor: const Color(0xFF816A03),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> updatePassword() async {
    // Check if form has been modified
    if (!_hasFormChanged) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No changes have been made."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final oldPassword = oldPasswordController.text.trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    _clearErrors();

    // Validation
    if (oldPassword.isEmpty) {
      setState(() => oldPasswordError = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your current password."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => newPasswordError = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a new password."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() => confirmPasswordError = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please confirm your new password."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        newPasswordError = true;
        confirmPasswordError = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final passwordError = _validatePassword(newPassword);
    if (passwordError != null) {
      setState(() => newPasswordError = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => saving = true);

    // ✅ SHOW LOADING DIALOG - Changing password
    if (!mounted) return;
    LoadingHelper.showLoadingDialog(context, message: 'Changing password...', width: 300, height: 200);

    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/user/change-password/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        }),
      );

      // ✅ HIDE LOADING before showing results
      if (mounted) LoadingHelper.hideLoading(context);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true ||
            data['message'] == 'Password updated successfully') {
          // ✅ FIXED: Use playClickSound instead of playDialogueSound
          AudioService().playClickSound();

          // Close the change password dialog
          if (!mounted) return;
          Navigator.pop(context);
          // Show success dialog
          await _showSuccessDialog();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Failed to update password."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        final data = jsonDecode(response.body);
        String errorMessage =
            data['message'] ?? "Error updating password. Please try again.";

        // Set error highlighting based on error message
        if (errorMessage.toLowerCase().contains('old password') ||
            errorMessage.toLowerCase().contains('current password')) {
          setState(() => oldPasswordError = true);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // ✅ HIDE LOADING on error
      if (mounted) LoadingHelper.hideLoading(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: _isMobile ? sw * 0.92 : 600,
        padding: EdgeInsets.all(_isMobile ? 18 : 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.vpn_key, color: Colors.black, size: _isMobile ? 20 : 26),
                const SizedBox(width: 8),
                Text(
                  "Change Password",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: _isMobile ? 17 : 22,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            SizedBox(height: _isMobile ? 14 : 20),

            // Old password
            TextField(
              controller: oldPasswordController,
              obscureText: !showOld,
              onChanged: (_) => setState(() => oldPasswordError = false),
              decoration: _inputDecoration(
                "Current Password",
                icon: Icons.lock_outline,
                hasError: oldPasswordError,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    showOld ? Icons.visibility_off : Icons.visibility,
                    color: oldPasswordError ? Colors.red : null,
                  ),
                  onPressed: () => setState(() => showOld = !showOld),
                ),
              ),
            ),
            SizedBox(height: _isMobile ? 10 : 15),

            // New password
            TextField(
              controller: newPasswordController,
              obscureText: !showNew,
              onChanged: (_) => setState(() => newPasswordError = false),
              decoration: _inputDecoration(
                "New Password",
                icon: Icons.lock,
                hasError: newPasswordError,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    showNew ? Icons.visibility_off : Icons.visibility,
                    color: newPasswordError ? Colors.red : null,
                  ),
                  onPressed: () => setState(() => showNew = !showNew),
                ),
              ),
            ),
            SizedBox(height: _isMobile ? 10 : 15),

            // Confirm password
            TextField(
              controller: confirmPasswordController,
              obscureText: !showConfirm,
              onChanged: (_) => setState(() => confirmPasswordError = false),
              decoration: _inputDecoration(
                "Confirm Password",
                icon: Icons.lock,
                hasError: confirmPasswordError,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirm ? Icons.visibility_off : Icons.visibility,
                    color: confirmPasswordError ? Colors.red : null,
                  ),
                  onPressed: () => setState(() => showConfirm = !showConfirm),
                ),
              ),
            ),
            SizedBox(height: _isMobile ? 18 : 25),

            // Buttons (Cancel / Save)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cancel
                TextButton(
                  onPressed: () {
                    AudioService().playClickSound();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF046EB8),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 18 : 24,
                      vertical: _isMobile ? 10 : 12,
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: _isMobile ? 12 : 14,
                    ),
                    side: const BorderSide(color: Color(0xFF046EB8), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),

                // Save (Change Password)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDD000),
                    foregroundColor: const Color(0xFF816A03),
                    padding: EdgeInsets.symmetric(
                      horizontal: _isMobile ? 18 : 24,
                      vertical: _isMobile ? 12 : 14,
                    ),
                    textStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: _isMobile ? 12 : 13,
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
                    updatePassword();
                  },
                  child: saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF816A03),
                      ),
                    ),
                  )
                      : Text(_hasFormChanged ? 'CHANGE PASSWORD' : 'NO CHANGES'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}