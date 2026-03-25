import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../Services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricEnabled = false;

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
    });
  }

  Future<void> _toggleBiometric(bool value) async {

    // Get shared preferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // If enabling biometric login, check if device supports it and authenticate user first
    if (value) {
      final canUse = await _biometricService.canUseBiometric();
      if (!canUse) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric not supported on this device")),
        );
        return;
      }

      // FIX: Check if email and name are stored before enabling biometrics
      final email = await _storage.read(key: 'email');
      final name = await _storage.read(key: 'name');

      // FIX: If email or name is missing, prompt user to log out and back in to refresh data
      if (email == null || name == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please log out and log back in before enabling biometrics"),
          ),
        );
        return;
      }

      // Authenticate user before enabling biometric login
      final success = await _biometricService.authenticate();
      if (!mounted) return;

      if (success) {
        await prefs.setBool('biometric_enabled', true);
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric login enabled ✓")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric authentication failed")),
        );
      }
    } else {
      await prefs.setBool('biometric_enabled', false);
      setState(() => _biometricEnabled = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Biometric login disabled")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("Enable Biometric Login"),
              subtitle: const Text("Use Face ID / Fingerprint to login"),
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
            ),
          ],
        ),
      ),
    );
  }
}