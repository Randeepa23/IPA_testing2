import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureRecovery = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Individual error messages for each field (only for validation issues, not empty)
  String? _emailError;
  String? _recoveryKeyError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String? _generalError; // General error shown at bottom for empty fields
  bool _isSubmitting = false; // Show loading state while submitting

  @override
  void dispose() {
    _emailController.dispose();
    _recoveryKeyController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear all previous errors
    setState(() {
      _emailError = null;
      _recoveryKeyError = null;
      _newPasswordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });

    final email = _emailController.text.trim();
    final recoveryKey = _recoveryKeyController.text.trim();
    final newPassword = _newPassController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    // Check if any field is empty - show general error at bottom
    if (email.isEmpty || recoveryKey.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _generalError = "All fields are required. Please fill in all fields.";
      });
      return;
    }

    bool hasError = false;

    // Validate email format (only if not empty)
    if (!email.contains('@')) {
      setState(() {
        _emailError = "Please enter a valid email address.";
      });
      hasError = true;
    }

    // Validate new password (only if not empty)
    if (newPassword.length < 6) {
      setState(() {
        _newPasswordError = "Password must be at least 6 characters.";
      });
      hasError = true;
    } else if (newPassword == "Test@123") {
      setState(() {
        _newPasswordError = "Cannot use default password. Please choose a different password.";
      });
      hasError = true;
    }

    // Validate confirm password matches (only if not empty)
    if (newPassword != confirmPassword) {
      setState(() {
        _confirmPasswordError = "Passwords do not match. Please check and try again.";
      });
      hasError = true;
    }

    if (hasError) return;

    // Also validate form
    if (!_formKey.currentState!.validate()) return;

    try {
      // Start loading state
      setState(() {
        _isSubmitting = true;
      });

      // Call API
      final res = await ApiService.forgotPassword(
        email: email,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      );

      if (!mounted) return;

      if (res["success"] == true) {

        TopBanner.show(
          context,
          title: "Success",
          message: "Password updated successfully! Please login again.",
          icon: Icons.check_circle,
          rightButtonText: "OK",
        );

        // Brief loading delay so user can see success, then navigate
        await Future.delayed(const Duration(milliseconds: 900));

        // Go back to a fresh login screen (clear stack) with username pre-filled
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              initialUsername: email,
            ),
          ),
          (route) => false,
        );
      } else {
        // Show API error - check if it's email/user related or recovery key related
        final errorMsg = res["message"]?.toString().toLowerCase() ?? "";
        final errorMsgOriginal = res["message"]?.toString() ?? "Failed to update password. Please check your information and try again.";
        
        // Check if error is related to user/email not found
        if (errorMsg.contains("user not found") || 
            errorMsg.contains("email not found") || 
            errorMsg.contains("user does not exist") ||
            errorMsg.contains("invalid email") ||
            errorMsg.contains("email")) {
          setState(() {
            _emailError = errorMsgOriginal;
            _isSubmitting = false;
          });
        } else {
          // Otherwise show on recovery key field (recovery key mismatch)
          setState(() {
            _recoveryKeyError = errorMsgOriginal;
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Show generic connectivity error at the bottom (not under a single field)
        _generalError = "Unable to reset password right now. Please check your internet connection and try again.";
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // responsive values (same style as your login)
    final horizontalPad = w > 600 ? 32.0 : 24.0;
    final topGap = (h * 0.05).clamp(18.0, 40.0);
    final sectionGap = (h * 0.02).clamp(14.0, 28.0);
    final logoWidth = (w * 0.65).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topGap),

                        //Logo
                        Center(
                          child: Image.asset(
                            'assets/ExploreHoldingLogo.png',
                            width: logoWidth,
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(height: 40),

                        Text(
                          "Reset Password",
                          style: GoogleFonts.actor(
                            fontSize: (w * 0.07).clamp(22.0, 28.0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Enter your email and recovery key to reset your password.",
                          style: GoogleFonts.actor(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        SizedBox(height: sectionGap),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_emailError != null || _generalError != null) {
                              setState(() {
                                _emailError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email address',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Email is required";
                            if (!value.contains('@')) return "Please enter a valid email";
                            return null;
                          },
                        ),
                        if (_emailError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _emailError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Recovery Key Field
                        TextFormField(
                          controller: _recoveryKeyController,
                          obscureText: _obscureRecovery,
                          onChanged: (_) {
                            if (_recoveryKeyError != null || _generalError != null) {
                              setState(() {
                                _recoveryKeyError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Recovery Key',
                            hintText: 'Enter your recovery key',
                            prefixIcon: const Icon(Icons.key_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureRecovery ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscureRecovery = !_obscureRecovery);
                              },
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Recovery key is required";
                            return null;
                          },
                        ),
                        if (_recoveryKeyError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _recoveryKeyError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // New Password Field
                        TextFormField(
                          controller: _newPassController,
                          obscureText: _obscureNew,
                          onChanged: (_) {
                            if (_newPasswordError != null || _generalError != null) {
                              setState(() {
                                _newPasswordError = null;
                                _generalError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Enter a new password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNew ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscureNew = !_obscureNew);
                              },
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "New password is required";
                            if (value.length < 6) return "Minimum 6 characters";
                            if (value == "Test@123") {
                              return "Cannot use default password";
                            }
                            return null;
                          },
                        ),
                        if (_newPasswordError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _newPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPassController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            hintText: 'Re-enter new password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _obscureConfirm = !_obscureConfirm);
                              },
                            ),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return "Confirm password is required";
                            if (value != _newPassController.text.trim()) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_confirmPasswordError != null || _generalError != null) {
                              setState(() {
                                _confirmPasswordError = null;
                                _generalError = null;
                              });
                            }
                          },
                        ),
                        if (_confirmPasswordError != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _confirmPasswordError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // General error message at bottom (for empty fields) - simple style like login screen
                        if (_generalError != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _generalError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ] else
                          const SizedBox(height: 8),

                        SizedBox(height: sectionGap),

                        //Submit Button
                        Center(
                          child: SizedBox(
                            width: (w * 0.70).clamp(220.0, 360.0),
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0060A6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Reset Password',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Info notice about recovery key (card at bottom)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              color: const Color(0xFFF5F9FF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFCCE0F4),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: Color(0xFF0060A6),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Forgot your password?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF003863),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Contact your HR department to retrieve your recovery key. Make sure to create a strong password that only you know.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4A4A4A),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Footer (same style)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: const [
                              Expanded(
                                child: Divider(
                                  color: Color(0xFF0060A6),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Explore Holdings',
                                  style: TextStyle(
                                    color: Color(0xFF0060A6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Color(0xFF0060A6),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
