import 'dart:convert';
import 'package:http/http.dart' as http;

class MeetingAndEventService {

  static const String baseUrl = "http://10.0.2.2/mobile-api/meetings";
  //static const String baseUrl = "https://exploresuite.lk/mobile-api/api";

  //Get All Staff API (use this in CreateEventScreen)
  static Future<Map<String, dynamic>> getAllStaff() async {
    final url = Uri.parse("$baseUrl/get_all_staff.php");

    final res = await http.get(
      url,
      headers: {
        "Accept": "application/json",
      },
    ).timeout(const Duration(seconds: 12));

    if (res.body.trim().isEmpty) {
      throw Exception("EMPTY response");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception("Invalid JSON format");
    }

    return decoded;
  }


}