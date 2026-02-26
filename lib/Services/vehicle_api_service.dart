// import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VehicleApiService {

//Android Emulator → PC localhost
static const String baseUrl = "http://10.0.2.2/test-2/vehicle";


  // For real device testing, use your PC's local network IP address
  // static const String baseUrl = "http://
static Future<List<Map<String, dynamic>>> fetchShuttleTrips({
    required String employeeId,
    required String status,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/get_shuttle_trips.php?employee_id=$employeeId&status=$status",
    );

    final res = await http.get(uri);

    if (res.body.trim().isEmpty) {
      throw Exception("Server returned EMPTY response");
    }

    final json = jsonDecode(res.body);

    if (json["success"] != true) {
      throw Exception(json["message"] ?? "API error");
    }

    final List list = json["data"] ?? [];
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchTransferTrips({
    required String employeeId,
    required String status,
  }) async {
    final uri = Uri.parse(
      "$baseUrl/get_transfer_trips.php?employee_id=$employeeId&status=$status",
    );

    final res = await http.get(uri);

    if (res.body.trim().isEmpty) {
      throw Exception("Server returned EMPTY response");
    }

    final json = jsonDecode(res.body);

    if (json["success"] != true) {
      throw Exception(json["message"] ?? "API error");
    }

    final List list = json["data"] ?? [];
    return list
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }

}