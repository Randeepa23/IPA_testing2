import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {


//Android Emulator → PC localhost
static const String baseUrl = "http://172.20.10.10/test-1/api";


  // File upload API (use this in LeaveFormScreen after applying leave request)
  static Future<void> uploadLeaveDocument({
    required int leaveRequestId,
    required File file,
  }) async {
    final uri = Uri.parse("$baseUrl/upload_leave_document.php");

    final req = http.MultipartRequest("POST", uri);
    req.fields["leave_request_id"] = leaveRequestId.toString();
    req.files.add(await http.MultipartFile.fromPath("document", file.path));

    final res = await req.send();
    final bodyStr = await res.stream.bytesToString();

    if (res.statusCode != 200) throw Exception(bodyStr);
  }

  // Fetch Manager's Leave Requests API (use this in ManagerLeaveRequestsScreen)
  static Future<List<Map<String, dynamic>>> fetchManagerLeaveRequests({
    required String managerId,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/get_manager_leave_requests.php?manager_id=$managerId",
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final body = json.decode(res.body);
    if (body["success"] != true) {
      throw Exception(body["message"] ?? "Unknown error");
    }

    final List data = body["data"] ?? [];

    return data.map<Map<String, dynamic>>((x) {
      final isSpecial = x["is_special_request"].toString() == "1";
      final overseeName = (x["oversee_name"] ?? "").toString().trim();
      final relieverComment = (x["reliever_comment"] ?? "").toString().trim();

      return {
        "leave_request_id": x["leave_request_id"],

        "employeeName": x["employee_name"] ?? "",
        "position": x["job_title_name"] ?? "—",

        // your UI uses employeeId field -> map to employee_code
        "employeeId": x["employee_code"] ?? x["employee_id"],

        "leaveType": "Leave Policy #${x["leave_policy_id"]}",
        "from": (x["leave_start_date"] ?? "").toString(),
        "to": (x["leave_end_date"] ?? "").toString(),
        "days": (x["number_of_days"] ?? "").toString(),
        "reason": x["reason"] ?? "",

        "coveringOfficer": (!isSpecial && overseeName.isNotEmpty)
            ? {
                "name": overseeName,
                "note": relieverComment.isNotEmpty ? relieverComment : "—",
              }
            : null,

        //"attachmentName": null,
        "attachmentName": x["attachment_name"],
        "attachmentPath": x["attachment_path"],

        "is_special_request": x["is_special_request"],
        "status": x["status"],
      };
    }).toList();
  }


  // Approve Leave API (use this in ManagerLeaveRequestsScreen)
  static Future<void> approveLeave({
    required String managerId,
    required int leaveRequestId,
  }) async {
    final uri = Uri.parse("$baseUrl/approve_leave.php");

    final res = await http.post(uri, body: {
      "manager_id": managerId,
      "leave_request_id": leaveRequestId.toString(),
    });

    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final body = json.decode(res.body);
    if (body["success"] != true) {
      throw Exception(body["message"] ?? "Approve failed");
    }
  }

  // Add comment parameter for rejection reason
  static Future<void> rejectLeave({
    required String managerId,
    required int leaveRequestId,
    required String comment,
  }) async {
    final uri = Uri.parse("$baseUrl/reject_leave.php");

    final res = await http.post(uri, body: {
      "manager_id": managerId,
      "leave_request_id": leaveRequestId.toString(),
      "comment": comment,
    });

    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    final body = json.decode(res.body);
    if (body["success"] != true) {
      throw Exception(body["message"] ?? "Reject failed");
    }
  }


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


    //Get Leave Balance API (use this in LeaveFormScreen when user selects leave type)
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

  //Apply Leave API (use this in LeaveFormScreen)
  static Future<Map<String, dynamic>> applyLeaveRequest({
    required String employeeId,
    required int leavePolicyId,
    required String startDate,
    required String endDate,
    required double numberOfDays,
    required String reason,
    String? overseeMemberId,
    required bool isSpecialRequest,
    String? address,

    String? halfDaySession, // MORNING / EVENING
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

      "halfDaySession": halfDaySession ?? "",
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


    //Get Relievers API (use this in LeaveForm when user selects dates and # of days)
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


    //Get Leave History API (use this in LeaveHistoryScreen)
    static Future<Map<String, dynamic>> getLeaveHistory({required String employeeId}) async {
    final url = Uri.parse("$baseUrl/get_leave_history.php");
    final res = await http.post(url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"employeeId": employeeId}),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

    //Get Recent Leave History API (use this in DashboardScreen)
    static Future<Map<String, dynamic>> getRecentLeaveHistory({required String employeeId}) async {
    final url = Uri.parse("$baseUrl/get_recent_leaves.php");
    final res = await http.post(url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"employeeId": employeeId}),
    );
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  // Cancel Leave Request API (use this in LeaveHistoryScreen for cancel button)
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

  // Get Reliever Requests API (use this in RelieverRequestsScreen)
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

  // Forgot Password API (use this in ForgotPasswordScreen)
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

  // Reliever Accept API (use this in RelieverRequestsScreen)
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

  // Reliever Decline API (use this in RelieverRequestsScreen)
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
