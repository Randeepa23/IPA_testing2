import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  //Android Emulator → PC localhost
static const String baseUrl = "http://10.0.2.2/test-1/api";

  static Future<List<dynamic>> fetchEmployees() async {

    // final res = await http.get(Uri.parse("$baseUrl/employees"), headers: {"Accept": "application/json"},
    final res = await http.get(Uri.parse("$baseUrl/get_users.php"),headers: {"Accept": "application/json"},

    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      // Laravel response: { success: true, data: [...] }
      if (decoded is Map<String, dynamic> && decoded["data"] is List) {
        return decoded["data"] as List<dynamic>;
      }

      // If API returns plain list
      if (decoded is List) {
        return decoded;
      }

      throw Exception("Unexpected response format: ${res.body}");
    }

    throw Exception("API error ${res.statusCode}: ${res.body}");
  }

      //POST: login (use this in LoginScreen)
      static Future<Map<String, dynamic>> login({
        required String email,
        required String password,
      }) async {
        final url = Uri.parse("$baseUrl/login.php");

        final res = await http.post(
          url,
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        );

        debugPrint("LOGIN URL: $url");
        debugPrint("LOGIN STATUS: ${res.statusCode}");
        debugPrint("LOGIN BODY: '${res.body}'");

        if (res.body.trim().isEmpty) {
          throw Exception("Server returned EMPTY response (check PHP / URL).");
        }

        try {
          final decoded = jsonDecode(res.body);
          return Map<String, dynamic>.from(decoded);
        } catch (_) {
          throw Exception("Server did not return JSON. Body: ${res.body}");
        }
      }


    static Future<Map<String, dynamic>> getLeaveBalance({
    required String employeeId,
    }) async {
      final url = Uri.parse("$baseUrl/get_leave_balance.php");

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: jsonEncode({"employeeId": employeeId}),
      );

      debugPrint("LEAVE URL: $url");
      debugPrint("LEAVE STATUS: ${res.statusCode}");
      debugPrint("LEAVE BODY: '${res.body}'");

      if (res.body.trim().isEmpty) {
        throw Exception("Server returned EMPTY response (check PHP / URL).");
      }

      final decoded = jsonDecode(res.body);
      return Map<String, dynamic>.from(decoded);
    }

  static Future<Map<String, dynamic>> applyLeaveRequest({
    required String employeeId,
    required int leavePolicyId,
    required String startDate, // yyyy-MM-dd
    required String endDate,   // yyyy-MM-dd
    required double numberOfDays,
    required String reason,
    String? overseeMemberId, // nullable
    required bool isSpecialRequest,
    String? address,
  }) async {
    final url = Uri.parse("$baseUrl/apply_leave_request.php");

    final body = {
      "employeeId": employeeId,
      "leavePolicyId": leavePolicyId,
      "startDate": startDate,
      "endDate": endDate,
      "numberOfDays": numberOfDays,
      "reason": reason,
      "overseeMemberId": overseeMemberId ?? "",
      "isSpecialRequest": isSpecialRequest ? 1 : 0,
      "address": address ?? "",
    };

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode(body),
    );

    if (res.body.trim().isEmpty) {
      throw Exception("EMPTY response");
    }

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }



    static Future<Map<String, dynamic>> getRelievers({
    required String employeeId,
    required String departmentId,
    required String fromDate,
    required String toDate,
  }) async {
    final url = Uri.parse("$baseUrl/get_relievers.php");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({
        "employeeId": employeeId,
        "departmentId": departmentId,
        "fromDate": fromDate,
        "toDate": toDate,
      }),
    );

    if (res.body.trim().isEmpty) throw Exception("EMPTY response");
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

    static Future<Map<String, dynamic>> getLeaveHistory({required String employeeId}) async {
    final url = Uri.parse("$baseUrl/get_leave_history.php");
    final res = await http.post(url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"employeeId": employeeId}),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

static Future<Map<String, dynamic>> cancelLeaveRequest({
  required String employeeId,
  required int leaveRequestId,
}) async {
  final url = Uri.parse("$baseUrl/cancel_leave_request.php");

  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json", "Accept": "application/json"},
    body: jsonEncode({"employeeId": employeeId, "leaveRequestId": leaveRequestId}),
  );

  debugPrint("CANCEL URL: $url");
  debugPrint("CANCEL STATUS: ${res.statusCode}");
  debugPrint("CANCEL BODY: '${res.body}'");

  if (res.body.trim().isEmpty) {
    throw Exception("Server returned EMPTY response (check PHP path / fatal error).");
  }

  final decoded = jsonDecode(res.body);
  return Map<String, dynamic>.from(decoded);
}

static Future<Map<String, dynamic>> getRelieverRequests({
  required String employeeId,
}) async {
  final url = Uri.parse("$baseUrl/get_reliever_requests.php");

  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json", "Accept": "application/json"},
    body: jsonEncode({"employeeId": employeeId}),
  );

  if (res.body.trim().isEmpty) {
    throw Exception("Server returned EMPTY response.");
  }

  final decoded = jsonDecode(res.body);
  return Map<String, dynamic>.from(decoded);
}

//Create New Password API (use this in CreateNewPasswordScreen)
static Future<Map<String, dynamic>> updatePassword({

  required String email,
  required String newPassword,
  required String recoveryKey,

}) async {
  final url = Uri.parse("$baseUrl/create_new_password.php");

  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "email": email,
      "newPassword": newPassword,
      "recovery_key": recoveryKey,
    }),
  );

  return jsonDecode(res.body) as Map<String, dynamic>;
}

static Future<Map<String, dynamic>> forgotPassword({
  required String email,
  required String recoveryKey,
  required String newPassword,
}) async {
  final url = Uri.parse("$baseUrl/forgot_password.php");

  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "email": email,
      "recovery_key": recoveryKey, // MUST match PHP
      "newPassword": newPassword,
    }),
  );

  return jsonDecode(res.body) as Map<String, dynamic>;
}


static Future<Map<String, dynamic>> relieverAccept({
  required int leaveRequestId,
  required String relieverId,
  required String comment,
}) async {
  final url = Uri.parse("$baseUrl/reliever_accept.php");
  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "leaveRequestId": leaveRequestId,
      "relieverId": relieverId,
      "comment": comment,
    }),
  );
  return jsonDecode(res.body);
}

static Future<Map<String, dynamic>> relieverDecline({
  required int leaveRequestId,
  required String relieverId,
  required String comment,
}) async {
  final url = Uri.parse("$baseUrl/reliever_decline.php");
  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "leaveRequestId": leaveRequestId,
      "relieverId": relieverId,
      "comment": comment,
    }),
  );
  return jsonDecode(res.body);
}


}
