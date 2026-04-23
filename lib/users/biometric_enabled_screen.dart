import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../Services/api_service.dart';
import '../Services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _rememberCredentials = false;
  bool _isLoading = false;

  final _biometricService = BiometricService();
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      _rememberCredentials =
          prefs.getBool('remember_credentials_enabled') ?? false;
    });
  }

  Future<void> _toggleRememberCredentials(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final email = await _storage.read(key: 'email');
      final name = await _storage.read(key: 'name');
      if (email == null || name == null) {
        if (!mounted) return;
        setState(() => _rememberCredentials = false);
        _showStyledSnackBar(
          message:
              "Please log in first, then enable credential saving from settings.",
          type: _SnackType.info,
        );
        return;
      }

      if (!mounted) return;
      final credentials = await _showCredentialInputDialog(defaultEmail: email);
      if (credentials == null) {
        await prefs.setBool('remember_credentials_enabled', false);
        await _storage.delete(key: 'saved_email');
        await _storage.delete(key: 'saved_password');
        if (!mounted) return;
        setState(() => _rememberCredentials = false);
        _showStyledSnackBar(
          message: "Credential saving is disabled.",
          type: _SnackType.info,
        );
        return;
      }

      await _storage.write(key: 'saved_email', value: credentials['email']);
      await _storage.write(
        key: 'saved_password',
        value: credentials['password'],
      );
      await prefs.setBool('remember_credentials_enabled', true);
      if (!mounted) return;
      setState(() => _rememberCredentials = true);
      _showStyledSnackBar(
        message: "Credentials saved securely for autofill.",
        type: _SnackType.success,
      );
      return;
    }

    await prefs.setBool('remember_credentials_enabled', false);
    await _storage.delete(key: 'saved_email');
    await _storage.delete(key: 'saved_password');
    if (!mounted) return;
    setState(() => _rememberCredentials = false);
    _showStyledSnackBar(
      message: "Saved credentials removed.",
      type: _SnackType.info,
    );
  }

  Future<Map<String, String>?> _showCredentialInputDialog({
    required String defaultEmail,
  }) async {
    String enteredEmail = defaultEmail;
    String enteredPassword = '';
    String? localError;
    bool isVerifying = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Save credentials'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: defaultEmail,
                    onChanged: (value) => enteredEmail = value,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    onChanged: (value) => enteredPassword = value,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(context),
                  child: const Text('Never'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                    final trimmedEmail = enteredEmail.trim();
                    final trimmedPassword = enteredPassword.trim();
                    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
                      setModalState(() {
                        localError = "Please enter username and password.";
                      });
                      return;
                    }
                    setModalState(() {
                      localError = null;
                      isVerifying = true;
                    });

                    try {
                      final data = await ApiService.login(
                        email: trimmedEmail,
                        password: trimmedPassword,
                      );

                      if (data["success"] == true) {
                        if (!context.mounted) return;
                        Navigator.pop(
                          context,
                          {'email': trimmedEmail, 'password': trimmedPassword},
                        );
                      } else {
                        setModalState(() {
                          localError = data["message"]?.toString() ??
                              "Invalid username or password.";
                          isVerifying = false;
                        });
                      }
                    } catch (_) {
                      setModalState(() {
                        localError =
                            "Unable to verify password now. Check internet and try again.";
                        isVerifying = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0060A6),
                    foregroundColor: Colors.white,
                  ),
                  child: isVerifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  void _showStyledSnackBar({
    required String message,
    required _SnackType type,
  }) {
    final IconData icon;
    final Color color;

    switch (type) {
      case _SnackType.success:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF2E7D32);
        break;
      case _SnackType.error:
        icon = Icons.cancel_rounded;
        color = const Color(0xFFC62828);
        break;
      case _SnackType.info:
        icon = Icons.info_rounded;
        color = Colors.blue;
        break;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(bool value) async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (value) {
        final canUse = await _biometricService.canUseBiometric();
        if (!canUse) {
          if (!mounted) return;
          _showStyledSnackBar(
            message: "Biometric authentication is not supported on this device.",
            type: _SnackType.error,
          );
          return;
        }

        final email = await _storage.read(key: 'email');
        final name = await _storage.read(key: 'name');

        if (email == null || name == null) {
          if (!mounted) return;
          _showStyledSnackBar(
            message: "Please log out and log back in before enabling biometrics.",
            type: _SnackType.info,
          );
          return;
        }

        final success = await _biometricService.authenticate();
        if (!mounted) return;

        if (success) {
          await prefs.setBool('biometric_enabled', true);
          setState(() => _biometricEnabled = true);
          _showStyledSnackBar(
            message: "Biometric login enabled successfully.",
            type: _SnackType.success,
          );
        } else {
          _showStyledSnackBar(
            message: "Biometric authentication failed. Please try again.",
            type: _SnackType.error,
          );
        }
      } else {
        await prefs.setBool('biometric_enabled', false);
        setState(() => _biometricEnabled = false);
        if (!mounted) return;
        _showStyledSnackBar(
          message: "Biometric login has been disabled.",
          type: _SnackType.info,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFF4F6FA),
        elevation: 0.5,
        shadowColor: Colors.black12,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionLabel("Security"),
          const SizedBox(height: 10),
          _buildBiometricCard(),
          const SizedBox(height: 12),
          _buildRememberCredentialsCard(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildBiometricCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Image.asset(
                Theme.of(context).platform == TargetPlatform.iOS
                    ? 'assets/faceId.png'
                    : 'assets/fingerId.png',
                color: Colors.black,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Biometric Login",
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Use Face ID or Fingerprint to sign in",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Switch.adaptive(
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                    activeColor: Colors.blue,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildRememberCredentialsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Image.asset(
                'assets/credentials.png',
                color: Colors.black,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Remember Credentials",
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Save username and password securely for autofill",
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _rememberCredentials,
              onChanged: _toggleRememberCredentials,
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

enum _SnackType { success, error, info }
