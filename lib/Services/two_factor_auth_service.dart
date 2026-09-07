import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../Models/two_factor_challenge.dart';

class TwoFactorAuthService {
  static String get _baseUrl => "${AppConfig.baseUrl}/api";

  /// Friendly error mapper matching app conventions
  static String _friendlyError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Request timed out. Please check your connection and retry.';
    }
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Sends user approval or decline response back to backend
  static Future<Map<String, dynamic>> respondToChallenge({
    required String challengeId,
    required String employeeId,
    required String action, // 'APPROVED' or 'DECLINED'
    bool biometricVerified = false,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/respond_2fa_challenge.php");
      debugPrint("2FA: Submitting response $action for challenge $challengeId");

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "challenge_id": challengeId,
              "employee_id": employeeId,
              "action": action.toUpperCase(),
              "biometric_verified": biometricVerified,
              "responded_at": DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.trim().isEmpty) {
        throw Exception("Empty response from server.");
      }

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 && (json["success"] == true || json["status"] == "success")) {
        return {
          "success": true,
          "message": json["message"] ?? "Response submitted successfully.",
        };
      } else {
        return {
          "success": false,
          "message": json["message"] ?? "Failed to update login verification status.",
        };
      }
    } on TimeoutException {
      return {
        "success": false,
        "message": "Connection timed out. Please verify your internet connection.",
      };
    } catch (e) {
      debugPrint("2FA respond error: $e");
      return {
        "success": false,
        "message": _friendlyError(e),
      };
    }
  }

  /// Fetches currently active pending 2FA challenges for the employee
  static Future<List<TwoFactorChallenge>> getPendingChallenges({
    required String employeeId,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/get_pending_2fa_challenges.php?employee_id=$employeeId");
      final response = await http
          .get(url, headers: {"Accept": "application/json"})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final json = jsonDecode(response.body);
        if (json["success"] == true && json["data"] is List) {
          final List list = json["data"];
          return list
              .map((item) => TwoFactorChallenge.fromJson(Map<String, dynamic>.from(item)))
              .where((c) => !c.isExpired)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint("2FA getPendingChallenges error: $e");
      return [];
    }
  }
}
