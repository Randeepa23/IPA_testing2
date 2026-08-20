import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'exceptions/app_exception.dart';
import 'create_new_password.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/biometric_service.dart';
import 'Services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialUsername;

  const LoginScreen({
    super.key,
    this.initialUsername,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  String? _loginError;
  bool _isLoggingIn = false;

  final _biometricService = BiometricService();
  final _storage = const FlutterSecureStorage();

  bool _showBiometric = false;

  @override
  void initState() {
    super.initState();

    // Load initial username if provided.
    if (widget.initialUsername != null &&
        widget.initialUsername!.trim().isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }

    // Load saved credentials safely.
    _loadSavedCredentials();

    // Check biometric availability.
    _checkBiometric();
  }

  // ---------------------------------------------------------------------------
  // LOAD SAVED CREDENTIALS
  // ---------------------------------------------------------------------------

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final rememberCredentials =
          prefs.getBool('remember_credentials_enabled') ?? false;

      if (!rememberCredentials) {
        return;
      }

      final savedEmail =
          await _storage.read(key: 'saved_email');

      final savedPassword =
          await _storage.read(key: 'saved_password');

      if (!mounted) {
        return;
      }

      /*
       * IMPORTANT:
       *
       * Only load saved credentials if the user has not already
       * entered anything.
       *
       * This prevents the async operation from overwriting text
       * that the user is currently typing.
       */
      if (_usernameController.text.trim().isEmpty &&
          _passwordController.text.isEmpty &&
          savedEmail != null &&
          savedPassword != null) {
        setState(() {
          _usernameController.text = savedEmail;
          _passwordController.text = savedPassword;
        });
      }
    } catch (e) {
      debugPrint("LOAD SAVED CREDENTIALS ERROR: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // BIOMETRIC CHECK
  // ---------------------------------------------------------------------------

  Future<void> _checkBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final enabled =
          prefs.getBool('biometric_enabled') ?? false;

      final canUse =
          await _biometricService.canUseBiometric();

      if (enabled && canUse) {
        if (mounted) {
          setState(() {
            _showBiometric = true;
          });
        }
      }
    } catch (e) {
      debugPrint("BIOMETRIC CHECK ERROR: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // BIOMETRIC LOGIN
  // ---------------------------------------------------------------------------

  Future<void> _biometricLogin() async {
    try {
      final success =
          await _biometricService.authenticate();

      if (!success) {
        return;
      }

      final email =
          await _storage.read(key: 'email');

      final name =
          await _storage.read(key: 'name');

      final userJson =
          await _storage.read(key: 'user');

      debugPrint("BIOMETRIC email: $email");
      debugPrint("BIOMETRIC name: $name");
      debugPrint("BIOMETRIC userJson: $userJson");

      if (email == null || userJson == null) {
        debugPrint(
          "BIOMETRIC FAILED: missing data in storage",
        );
        return;
      }

      final user =
          Map<String, dynamic>.from(
        jsonDecode(userJson),
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            name: name ?? "User",
            user: user,
            username: email,
            successMessage:
                "Login successful, ${name ?? "User"}!",
          ),
        ),
      );
    } catch (e) {
      debugPrint("BIOMETRIC LOGIN ERROR: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // INPUT DECORATION
  // ---------------------------------------------------------------------------

  InputDecoration _loginInputDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,

      labelStyle: TextStyle(
        color: Colors.grey.shade700,
      ),

      hintStyle: TextStyle(
        color: Colors.grey.shade600,
      ),

      prefixIcon: Icon(
        icon,
        color: Colors.grey.shade700,
      ),

      suffixIcon: suffix,

      filled: true,

      fillColor: Colors.white,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.blue,
          width: 1.2,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGIN API
  // ---------------------------------------------------------------------------

  Future<void> _loginApi() async {
    /*
     * If fields are empty, try loading saved credentials once.
     */
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      await _loadSavedCredentials();
    }

    final email =
        _usernameController.text.trim();

    final password =
        _passwordController.text.trim();

    // ---------------------------------------------------------
    // VALIDATION
    // ---------------------------------------------------------

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loginError =
            "Please enter username and password.";
      });

      return;
    }

    // ---------------------------------------------------------
    // START LOGIN
    // ---------------------------------------------------------

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    try {
      // -------------------------------------------------------
      // API LOGIN
      // -------------------------------------------------------

      final data = await ApiService.login(
        email: email,
        password: password,
      );

      debugPrint("LOGIN DATA: $data");

      // -------------------------------------------------------
      // SUCCESS
      // -------------------------------------------------------

      if (data["success"] == true) {
        final user =
            Map<String, dynamic>.from(
          data["user"],
        );

        final name =
            user["name"] ?? "User";

        final prefs =
            await SharedPreferences.getInstance();

        final rememberCredentials =
            prefs.getBool(
                  'remember_credentials_enabled',
                ) ??
                false;

        // -----------------------------------------------------
        // SAVE USER DATA
        // -----------------------------------------------------

        await _storage.write(
          key: 'email',
          value: user["email"] ?? email,
        );

        await _storage.write(
          key: 'name',
          value: name,
        );

        await _storage.write(
          key: 'user',
          value: jsonEncode(user),
        );

        // -----------------------------------------------------
        // REMEMBER CREDENTIALS
        // -----------------------------------------------------

        if (rememberCredentials) {
          await _storage.write(
            key: 'saved_email',
            value: email,
          );

          await _storage.write(
            key: 'saved_password',
            value: password,
          );
        } else {
          await _storage.delete(
            key: 'saved_email',
          );

          await _storage.delete(
            key: 'saved_password',
          );
        }

        if (!mounted) {
          return;
        }

        setState(() {
          _loginError = null;
        });

        // -----------------------------------------------------
        // SMALL DELAY FOR SUCCESS
        // -----------------------------------------------------

        await Future.delayed(
          const Duration(milliseconds: 900),
        );

        if (!mounted) {
          return;
        }

        // -----------------------------------------------------
        // FIREBASE NOTIFICATION PERMISSION
        // -----------------------------------------------------

        try {
          await FirebaseMessaging.instance
              .requestPermission();
        } catch (e) {
          debugPrint(
            "FCM permission request failed: $e",
          );
        }

        // -----------------------------------------------------
        // SAVE FCM TOKEN
        // -----------------------------------------------------

        try {
          final fcmToken =
              await FirebaseMessaging.instance
                  .getToken();

          debugPrint(
            "FCM getToken() result: $fcmToken",
          );

          if (fcmToken != null) {
            await NotificationService.saveFcmToken(
              employeeId:
                  user["employeeId"].toString(),
              fcmToken: fcmToken,
            );
          } else {
            debugPrint(
              "FCM: getToken() returned null",
            );
          }
        } catch (e) {
          debugPrint(
            "FCM: token fetch skipped - $e",
          );
        }

        if (!mounted) {
          return;
        }

        // -----------------------------------------------------
        // FIRST-TIME PASSWORD
        // -----------------------------------------------------

        if (password == "Test@123") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CreateNewPasswordScreen(
                userEmail: email,
                userName: name,
                userData: user,
              ),
            ),
          );

          return;
        }

        // -----------------------------------------------------
        // NORMAL LOGIN
        // -----------------------------------------------------

        await _storage.write(
          key: 'email',
          value: email,
        );

        await _storage.write(
          key: 'name',
          value: name,
        );

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              name: name,
              user: user,
              username:
                  user["email"] ?? email,
              successMessage:
                  "Login successful, $name!",
            ),
          ),
        );
      }

      // -------------------------------------------------------
      // LOGIN FAILED
      // -------------------------------------------------------

      else {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoggingIn = false;

          _loginError =
              data["message"]?.toString() ??
                  "Invalid username or password. "
                  "Please check and try again.";
        });
      }
    } catch (e) {
      debugPrint("LOGIN ERROR: $e");

      if (!mounted) {
        return;
      }

      final err =
          AppException.handle(e);

      setState(() {
        _isLoggingIn = false;
        _loginError = err.message;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.of(context).size;

    final w = size.width;
    final h = size.height;

    // Responsive values
    final horizontalPad =
        w > 600 ? 32.0 : 24.0;

    final logoWidth =
        (w * 0.65).clamp(
      200.0,
      320.0,
    );

    final topGap =
        (h * 0.08).clamp(
      30.0,
      80.0,
    );

    final sectionGap =
        (h * 0.01).clamp(
      14.0,
      28.0,
    );

    return Scaffold(
      backgroundColor: Colors.white,

      // Make sure the screen can receive keyboard input
      resizeToAvoidBottomInset: true,

      body: SafeArea(
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.manual,

              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
              ),

              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight,
                ),

                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      SizedBox(
                        height: topGap,
                      ),

                      // ---------------------------------------------------
                      // LOGO
                      // ---------------------------------------------------

                      Center(
                        child: Image.asset(
                          'assets/ExploreHoldingLogo.png',
                          width: logoWidth,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(
                        height: sectionGap,
                      ),

                      // ---------------------------------------------------
                      // APP NAME
                      // ---------------------------------------------------

                      ShaderMask(
                        shaderCallback:
                            (bounds) =>
                                const RadialGradient(
                          center:
                              Alignment(0.0, 0.3),
                          radius: 1.2,
                          colors: [
                            Color(0xFF42A5F5),
                            Color(0xFF0D47A1),
                          ],
                          stops: [
                            0.2,
                            1.0,
                          ],
                        ).createShader(
                          Rect.fromLTWH(
                            0,
                            0,
                            bounds.width,
                            bounds.height,
                          ),
                        ),

                        child: Center(
                          child: Text(
                            'Enterprise Suite',
                            textAlign:
                                TextAlign.center,
                            style:
                                GoogleFonts
                                    .alfaSlabOne(
                              fontSize:
                                  (w * 0.08)
                                      .clamp(
                                18.0,
                                34.0,
                              ),
                              letterSpacing: 0.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // ---------------------------------------------------
                      // BIOMETRIC SPACING
                      // ---------------------------------------------------

                      if (_showBiometric)
                        SizedBox(
                          height:
                              (h * 0.04).clamp(
                            20.0,
                            60.0,
                          ),
                        )
                      else
                        SizedBox(
                          height:
                              (h * 0.08).clamp(
                            20.0,
                            60.0,
                          ),
                        ),

                      SizedBox(
                        height: sectionGap,
                      ),

                      // ---------------------------------------------------
                      // BIOMETRIC LOGIN
                      // ---------------------------------------------------

                      if (_showBiometric)
                        Center(
                          child: GestureDetector(
                            onTap:
                                _biometricLogin,

                            child: Column(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(
                                    14,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape.circle,
                                    color: Colors
                                        .blue
                                        .shade50,
                                  ),

                                  child:
                                      Image.asset(
                                    Theme.of(context)
                                                .platform ==
                                            TargetPlatform
                                                .iOS
                                        ? 'assets/faceId.png'
                                        : 'assets/fingerId.png',

                                    width: 42,
                                    height: 42,

                                    color:
                                        Colors.black,

                                    colorBlendMode:
                                        BlendMode.srcIn,
                                  ),
                                ),

                                const SizedBox(
                                  height: 8,
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ===================================================
                      // USERNAME FIELD
                      // ===================================================

                      TextField(
                        controller:
                            _usernameController,

                        // Explicitly editable
                        readOnly: false,
                        enabled: true,

                        keyboardType:
                            TextInputType.text,

                        textInputAction:
                            TextInputAction.next,

                        autocorrect: false,

                        enableSuggestions: true,

                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),

                        onChanged: (value) {
                          if (_loginError != null) {
                            setState(() {
                              _loginError = null;
                            });
                          }
                        },

                        decoration:
                            _loginInputDecoration(
                          "Username",
                          Icons.person_outline,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ===================================================
                      // PASSWORD FIELD
                      // ===================================================

                      TextField(
                        controller:
                            _passwordController,

                        // Explicitly editable
                        readOnly: false,
                        enabled: true,

                        obscureText:
                            _obscurePassword,

                        keyboardType:
                            TextInputType.text,

                        textInputAction:
                            TextInputAction.done,

                        autocorrect: false,

                        enableSuggestions: false,

                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),

                        onChanged: (value) {
                          if (_loginError != null) {
                            setState(() {
                              _loginError = null;
                            });
                          }
                        },

                        onSubmitted: (_) {
                          if (!_isLoggingIn) {
                            _loginApi();
                          }
                        },

                        decoration:
                            _loginInputDecoration(
                          "Password",
                          Icons.lock_outline,

                          suffix:
                              IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons
                                      .visibility_off_rounded
                                  : Icons
                                      .visibility_rounded,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),

                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      // ===================================================
                      // LOGIN ERROR
                      // ===================================================

                      if (_loginError != null) ...[
                        const SizedBox(
                          height: 12,
                        ),

                        Align(
                          alignment:
                              Alignment.centerLeft,

                          child: Text(
                            _loginError!,

                            style:
                                const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(
                          height: 8,
                        ),

                      // ===================================================
                      // FORGOT PASSWORD
                      // ===================================================

                      Align(
                        alignment:
                            Alignment.centerRight,

                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ForgotPasswordScreen(),
                              ),
                            );
                          },

                          style:
                              TextButton.styleFrom(
                            padding:
                                EdgeInsets.zero,

                            minimumSize:
                                const Size(
                              50,
                              30,
                            ),

                            tapTargetSize:
                                MaterialTapTargetSize
                                    .shrinkWrap,
                          ),

                          child: const Text(
                            'Forgot Password?',

                            style:
                                TextStyle(
                              color: Color.fromARGB(
                                255,
                                216,
                                108,
                                108,
                              ),
                              fontWeight:
                                  FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(
                        height: sectionGap,
                      ),

                      // ===================================================
                      // LOGIN BUTTON
                      // ===================================================

                      Center(
                        child: SizedBox(
                          width:
                              (w * 0.45).clamp(
                            150.0,
                            220.0,
                          ),

                          height: 48,

                          child: Container(
                            decoration:
                                BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(0xFF0060A6),
                                  Color(0xFF003580),
                                ],
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                              ),

                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),

                            child:
                                ElevatedButton(
                              onPressed:
                                  _isLoggingIn
                                      ? null
                                      : _loginApi,

                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.transparent,

                                disabledBackgroundColor:
                                    Colors.transparent,

                                shadowColor:
                                    Colors.transparent,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    14,
                                  ),
                                ),
                              ),

                              child: _isLoggingIn
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,

                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.5,

                                        valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Login',

                                      style:
                                          TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize:
                                            18,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ===================================================
                      // DESCRIPTION
                      // ===================================================

                      Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(
                            maxWidth: 420,
                          ),

                          child: Text(
                            'Please log in with your company username and password to access the Explore Holding ERP system.',

                            textAlign:
                                TextAlign.center,

                            style:
                                const TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(
                                255,
                                101,
                                156,
                                182,
                              ),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ===================================================
                      // FOOTER
                      // ===================================================

                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 14,
                        ),

                        child: Row(
                          children: const [
                            Expanded(
                              child: Divider(
                                color:
                                    Color(0xFF0060A6),
                                thickness: 1,
                              ),
                            ),

                            Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                horizontal: 8,
                              ),

                              child: Text(
                                'Need Help',

                                style:
                                    TextStyle(
                                  color: Color(
                                    0xFF0060A6,
                                  ),
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Divider(
                                color:
                                    Color(0xFF0060A6),
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
            );
          },
        ),
      ),
    );
  }
}