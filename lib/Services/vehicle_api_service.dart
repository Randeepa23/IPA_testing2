// import 'dart:io';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VehicleApiService {

  //Android Emulator → PC localhost
  static const String baseUrl = "http://10.0.2.2/test-2/vehicle";
  //static const String baseUrl = "https://exploresuite.lk/mobile-api/vehicle";



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


    // For Transfer Trips, we can reuse the same API as Shuttle Trips, just with different endpoint and parameters.
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

    // API to generate trip code (for both Shuttle and Transfer, since it's the same code generation logic)
    static Future<Map<String, dynamic>> generateTripCode({
    required int tripId,
    required String tripCode,
  }) async {
    final url = Uri.parse("$baseUrl/generate_trip_code.php");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json", "Accept": "application/json"},
      body: jsonEncode({"tripId": tripId, "tripCode": tripCode}),
    );

    if (res.body.trim().isEmpty) throw Exception("Empty response");

    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  // Start Trip API with multipart/form-data for photo upload
  static Future<Map<String, dynamic>> startTrip({
    required int transportServiceId,
    required int odometer,
    required double fuelPercent,
    required File photoFile,
  }) async {
    final uri = Uri.parse("$baseUrl/start_trip.php");

    final req = http.MultipartRequest("POST", uri);
    req.fields["transport_service_id"] = transportServiceId.toString();
    req.fields["odometer"] = odometer.toString();
    req.fields["fuel_percent"] = fuelPercent.toString();

    req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (body.trim().isEmpty) throw Exception("Empty response");
    final json = jsonDecode(body);

    return Map<String, dynamic>.from(json);
  }

    // For Stop Trip, we can reuse the same API as Shuttle and Transfer, just with different transport_service_id and endpoint
    static Future<Map<String, dynamic>> stopTrip({
    required int transportServiceId,
    required int endOdometer,
    required double endFuelPercent,
    required File photoFile,
  }) async {
    final uri = Uri.parse("$baseUrl/stop_trip.php");

    final req = http.MultipartRequest("POST", uri);
    req.fields["transport_service_id"] = transportServiceId.toString();
    req.fields["end_odometer"] = endOdometer.toString();
    req.fields["end_fuel_percent"] = endFuelPercent.toString();
    req.files.add(await http.MultipartFile.fromPath("photo", photoFile.path));

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (body.trim().isEmpty) throw Exception("Empty response");
    return Map<String, dynamic>.from(jsonDecode(body));
  }

  // API to fetch default managers for a given employee (used in Shuttle and Transfer Trip forms)
  static Future<Map<String, dynamic>> getDefaultManagers({required int employeeId}) async {
  final url = Uri.parse("$baseUrl/get_default_managers.php?employee_id=$employeeId");
  final res = await http.get(url);

  if (res.body.trim().isEmpty) throw Exception("Empty response");
  return Map<String, dynamic>.from(jsonDecode(res.body));
}

}