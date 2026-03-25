import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/biometric_service.dart';

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

  // Load saved setting
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  // Toggle biometric
  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final canUse = await _biometricService.canUseBiometric();

      if (!canUse) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric not supported on this device")),
        );
        return;
      }

      final success = await _biometricService.authenticate();

      if (success) {
        await prefs.setBool('biometric_enabled', true);

        setState(() {
          _biometricEnabled = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Biometric Enabled")),
        );
      }
    } else {
      await prefs.setBool('biometric_enabled', false);

      setState(() {
        _biometricEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
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