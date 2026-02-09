import 'dart:convert';
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
          required String username,
          required String password,
        }) async {
          final res = await http.post(
            Uri.parse("$baseUrl/login.php"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({"username": username, "password": password}),
          );

          // debugPrint("LOGIN STATUS: ${res.statusCode}");
          // debugPrint("LOGIN BODY: ${res.body}");

          final decoded = jsonDecode(res.body);
          return Map<String, dynamic>.from(decoded);
        }


      static Future<Map<String, dynamic>> fetchLeaveBalance({
      required int employeeId,
      }) async {
      final res = await http.get(
        Uri.parse("$baseUrl/get_leave_balance.php?employee_id=$employeeId&year=2026"),
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        return decoded["data"];
      }

      throw Exception("Failed to load leave balance");
    }

    static Future<Map<String, dynamic>> applyLeave({
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/apply_leave.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    return jsonDecode(response.body);
  }


}
