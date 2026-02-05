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
}
