import 'dart:convert';
import 'package:http/http.dart' as http;

class StaffGatePassService {
  //static const String _baseUrl = "http://10.0.2.2/mobile-api/gatepass";
  static const String _baseUrl = "https://exploresuite.lk/mobile-api/gatepass";

  // ── Get all staff ─────────────────────────────────────────────────────────
  /// Returns { "success": true, "members": [...] } from get_all_staff.php
  static Future<Map<String, dynamic>> getAllStaff() async {
    final url = Uri.parse("$_baseUrl/get_all_staff.php");

    final res = await http
        .get(url, headers: {"Accept": "application/json"})
        .timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) {
      throw Exception("Empty response from server");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception("Unexpected response format");
    }

    return decoded;
  }

  // ── Create gate pass ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createGatePass({
    required int    employeeId,
    required String employeeName,
    required String contactNo,
    required int    managerId,
    required String gatePassDate,          // "yyyy-MM-dd"
    required String outTime,               // "HH:mm:ss"
    required String returnTime,            // "HH:mm:ss"
    required String reason,
    String?         vehicleNo,             // null when not provided
    List<int>?      companionEmployeeIds,  // null or empty when no companions
    String?         remark,               // null when not provided
  }) async {
    final url = Uri.parse("$_baseUrl/create_gate_pass.php");

    final body = jsonEncode({
      "employee_id"            : employeeId,
      "employee_name"          : employeeName,
      "contact_no"             : contactNo,
      "manager_id"             : managerId,
      "gate_pass_date"         : gatePassDate,
      "out_time"               : outTime,
      "return_time"            : returnTime,
      "reason"                 : reason,
      "vehicle_no"             : vehicleNo ?? "",
      "companion_employee_ids" : companionEmployeeIds ?? [],
      "remark"                 : remark ?? "",
    });

    final res = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept"       : "application/json",
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) {
      throw Exception("Empty response from server");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception("Unexpected response format");
    }

    return decoded;
  }

    // ── Get gate pass requests ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getGatePassRequests({
    required int employeeId,
  }) async {
    final url = Uri.parse(
        "$_baseUrl/get_gate_pass_request.php?employee_id=$employeeId");
 
    final res = await http
        .get(url, headers: {"Accept": "application/json"})
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
 
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }


  // ── Cancel gate pass request ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> cancelGatePassRequest({
    required int id,
    required int employeeId,
  }) async {
    final url = Uri.parse("$_baseUrl/cancel_gate_pass.php");
 
    final res = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept"       : "application/json",
          },
          body: jsonEncode({
            "id"          : id,
            "employee_id" : employeeId,
          }),
        )
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
 
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }


    // ── Approve gate pass ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> approveGatePassRequest({
    required int id,
    required int managerId,
  }) async {
    final res = await http
        .post(
          Uri.parse("$_baseUrl/approve_gate_pass_request.php"),
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({"id": id, "manager_id": managerId}),
        )
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }
 
  // ── Reject gate pass ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> rejectGatePassRequest({
    required int    id,
    required int    managerId,
    required String rejectReason,
  }) async {
    final res = await http
        .post(
          Uri.parse("$_baseUrl/reject_gate_pass_request.php"),
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({
            "id"           : id,
            "manager_id"   : managerId,
            "reject_reason": rejectReason,
          }),
        )
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

    // ── Get manager pending requests ──────────────────────────────────────────
  static Future<Map<String, dynamic>> getManagerGatePassRequests({
    required int managerId,
    String? status,
  }) async {
    var url = "$_baseUrl/get_manager_gate_pass_request.php?manager_id=$managerId";
    if (status != null) url += "&status=$status";
 
    final res = await http
        .get(Uri.parse(url), headers: {"Accept": "application/json"})
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

    // ── Check out gate pass ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkOutGatePass({
    required int id,
    required int employeeId,
  }) async {
    final res = await http
        .post(
          Uri.parse("$_baseUrl/check_out.php"),
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({"id": id, "employee_id": employeeId}),
        )
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

  // ── Check in gate pass ────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkInGatePass({
    required int id,
    required int employeeId,
  }) async {
    final res = await http
        .post(
          Uri.parse("$_baseUrl/check_in.php"),
          headers: {"Content-Type": "application/json", "Accept": "application/json"},
          body: jsonEncode({"id": id, "employee_id": employeeId}),
        )
        .timeout(const Duration(seconds: 15));
 
    if (res.body.trim().isEmpty) throw Exception("Empty response from server");
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) throw Exception("Unexpected response format");
    return decoded;
  }

}