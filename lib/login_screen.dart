import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
import 'package:test_app/Services/api_service.dart';
import 'create_new_password.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart';
class LoginScreen extends StatefulWidget {
  final String? initialUsername;

  const LoginScreen({Key? key, this.initialUsername}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _loginError; // message shown near the fields
  bool _isLoggingIn = false; // Show loading state while logging in

  @override
  void initState() {
    super.initState();
    // Pre‑fill username if provided (e.g. after password change)
    _usernameController.text = widget.initialUsername ?? '';
  }
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



    Future<void> _loginApi() async {
      final email = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // basic validation – show message near fields instead of snackbar
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _loginError = "Please enter username and password.";
        });
        return;
      }

      try {
        // Start loading state
        setState(() {
          _isLoggingIn = true;
        });

        final data = await ApiService.login(email: email, password: password);

        debugPrint("LOGIN DATA: $data");

        if (data["success"] == true) {
          final user = Map<String, dynamic>.from(data["user"]);
          final name = user["name"] ?? "User";

          // clear any previous error
          setState(() {
            _loginError = null;
          });

          // Brief delay to show success, then navigate
          await Future.delayed(const Duration(milliseconds: 900));

          if (!mounted) return;

          // Check if user is logging in with default HR password (first-time login)
          if (password == "Test@123") {
            // Redirect to create new password screen for first-time login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNewPasswordScreen(
                  userEmail: email,
                  userName: name,
                  userData: user,
                ),
              ),
            );
          } else {
            // Normal login - go to home screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  name: name,
                  user: user,
                  username: user["email"] ?? email,
                  successMessage: "Login successful, $name!",
                ),
              ),
            );
          }
          } else {
          // show server message (like wrong username/password) near fields
          setState(() {
            _isLoggingIn = false;
            _loginError =
                data["message"]?.toString() ?? "Invalid username or password. Please check and try again.";
          });
        }
      } catch (e) {
        debugPrint("LOGIN ERROR: $e");
        setState(() {
          _isLoggingIn = false;
          _loginError = "Unable to login right now. Please check your internet connection and try again.";
        });
      }
    }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    //responsive values
    final horizontalPad = w > 600 ? 32.0 : 24.0;
    final logoWidth = (w * 0.65).clamp(200.0, 320.0);
    final topGap = (h * 0.05).clamp(18.0, 40.0);
    final sectionGap = (h * 0.01).clamp(14.0, 28.0);

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

                      SizedBox(height: sectionGap),

                      //App Name
                      Center(
                        child: Text(
                          'ENEXA',
                          style: TextStyle(
                            fontSize: (w * 0.08).clamp(24.0, 34.0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      SizedBox(height: 80),

                      SizedBox(height: sectionGap),

                      //Username Field
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: "Enter username",
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: Colors.blue, width: 1.2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: (_) {
                          if (_loginError != null) {
                            setState(() {
                              _loginError = null;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "Enter password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_loginError != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _loginError!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Navigate to Forgot Password screen
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Color.fromARGB(255, 216, 108, 108),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: sectionGap),

                      //Login Button
                      Center(
                        child: SizedBox(
                          width: (w * 0.45).clamp(150.0, 220.0),
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : _loginApi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0060A6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoggingIn
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const Spacer(),  
                                     // Short notice so users understand the app
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            'Please log in with your company username and password to access the Explore Holding ERP system.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color.fromARGB(255, 101, 156, 182),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      //Footer stays bottom on big screens, scrolls on small
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
                                'Need Help',
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
            );
          },
        ),
      ),
    );
  }
}
