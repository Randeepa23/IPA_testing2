// import 'dart:io';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class VehicleApiService {

  //Android Emulator → PC localhost
  static const String baseUrl = "http://10.0.2.2/mobile-api/vehicle";
  //static const String baseUrl = "https://exploresuite.lk/mobile-api/vehicle";

  // For real device testing, use your PC's local network IP address
  // static const String baseUrl = "http://
  static Future<Map<String, dynamic>> assignVehicleToTrip({
    required int tripId,
    required String vehicleType,
    required String vehicleNo,
    required String reason,
  }) async {
    final uri = Uri.parse("$baseUrl/assign_vehicle_to_trip.php");

    final request = http.MultipartRequest("POST", uri)
      ..fields["trip_id"] = tripId.toString()
      ..fields["vehicle_type"] = vehicleType
      ..fields["vehicle_no"] = vehicleNo
      ..fields["reason"] = reason;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchVehicleDetails({
      required String transportServiceId,
    }) async {
      final uri = Uri.parse(
        "https://exploresuite.lk/api/transport-services/$transportServiceId/vehicle-details",
      );

      final res = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
        },
      );

      if (res.body.trim().isEmpty) {
        throw Exception("Vehicle details API returned empty response");
      }

      final json = jsonDecode(res.body);

      if (res.statusCode != 200) {
        throw Exception(json["error"] ?? "Failed to fetch vehicle details");
      }

      return Map<String, dynamic>.from(json);
    }

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

    // For real device testing, use your PC's local network IP address
    // static const String baseUrl = "http://
    static Future<List<Map<String, dynamic>>> fetchPersonalTrips({
      required String employeeId,
      required String status,
    }) async {
      final uri = Uri.parse(
        "$baseUrl/get_personal_trip.php?employee_id=$employeeId&status=$status",
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

    // API to fetch count of assigned trips (for both Shuttle and Transfer, since it's the same logic just different endpoints)
    static Future<int> fetchShuttleAssignedCount({
      required String employeeId,
    }) async {
      final list = await fetchShuttleTrips(
        employeeId: employeeId,
        status: "ASSIGNED",
      );
      return list.length;
    }

    static Future<int> fetchTransferAssignedCount({
      required String employeeId,
    }) async {
      final list = await fetchTransferTrips(
        employeeId: employeeId,
        status: "ASSIGNED",
      );
      return list.length;
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

 /// Create Vehicle Request -> inserts into office (type = transfer)
  static Future<Map<String, dynamic>> createOfficeVehicleRequest({
    required String employeeId,
    required String managerId,
    required String vehicleNo,
    required String fromDate,     // yyyy-MM-dd
    required String toDate,       // yyyy-MM-dd
    required String destination,
    required String contactNo,
  required String employeeName,
    String reason = "Office Service",
    String? vehicleType,          // ← new
  }) async {
    final url = Uri.parse("$baseUrl/create_office_vehicle_request.php");

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "contact_no": contactNo,
        "employee_id": employeeId,
        "manager_id": managerId,
        "vehicle_no": vehicleNo,
        "from_date": fromDate,
        "to_date": toDate,
        "destination": destination,
        "chauffer_phone": contactNo,
        "chauffer_name": employeeName,
        "reason": reason,
        "vehicle_type": vehicleType,
      }),
    ).timeout(const Duration(seconds: 12));

    if (res.body.trim().isEmpty) {
      throw Exception("Server returned EMPTY response");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    // fallback if API returns object but decoded as Map<dynamic,dynamic>
    return Map<String, dynamic>.from(decoded);
  }

  /// Create Vehicle Request -> inserts into office (type = transfer)
  static Future<Map<String, dynamic>> createPersonalVehicleRequest({
    required String employeeId,
    required String managerId,
    required String vehicleNo,
    required String fromDate,     // yyyy-MM-dd
    required String toDate,       // yyyy-MM-dd
    //required String destination,
    required String contactNo,
  required String employeeName,
    String reason = "Personal Service",
    String? vehicleType,          // ← new
  }) async {
    final url = Uri.parse("$baseUrl/create_personal_vehicle_request.php");

    final res = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({
        "contact_no": contactNo,
        "employee_id": employeeId,
        "manager_id": managerId,
        "vehicle_no": vehicleNo,
        "from_date": fromDate,
        "to_date": toDate,
        //"destination": destination,
        "chauffer_phone": contactNo,
        "chauffer_name": employeeName,
        "reason": reason,
        "vehicle_type": vehicleType,
      }),
    ).timeout(const Duration(seconds: 12));

    if (res.body.trim().isEmpty) {
      throw Exception("Server returned EMPTY response");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    // fallback if API returns object but decoded as Map<dynamic,dynamic>
    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> getMyTrips({required String employeeId}) async {
  final url = Uri.parse("$baseUrl/get_my_trips.php?employee_id=$employeeId");
  final res = await http.get(url, headers: {"Accept": "application/json"});

  final body = res.body.trim();
  if (body.isEmpty) throw Exception("EMPTY response");
  if (!body.startsWith("{") && !body.startsWith("[")) {
    throw Exception("Non-JSON: $body");
  }
  return Map<String, dynamic>.from(jsonDecode(body));
}
static Future<Map<String, dynamic>> cancelTrip({required String id}) async {
  final url = Uri.parse("$baseUrl/cancel_trip.php");
  final res = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: jsonEncode({"id": int.parse(id)}),
  );

  final body = res.body.trim();
  if (body.isEmpty) throw Exception("EMPTY response");
  return Map<String, dynamic>.from(jsonDecode(body));
}

static Future<List<Map<String, dynamic>>> fetchManagerVehicleRequests({
  required String managerId,
}) async {
  final url = Uri.parse("$baseUrl/get_manager_vehicle_requests.php?manager_id=$managerId");
  final res = await http.get(url, headers: {"Accept": "application/json"});

  final decoded = jsonDecode(res.body);
  if (decoded["success"] != true) {
    throw Exception(decoded["message"] ?? "API failed");
  }

  return List<Map<String, dynamic>>.from(decoded["data"] ?? []);
}

static Future<List<Map<String, dynamic>>> fetchManagerPersonalRequests({
  required String managerId,
}) async {
  final url = Uri.parse("$baseUrl/get_manager_personal_request.php?manager_id=$managerId");
  final res = await http.get(url, headers: {"Accept": "application/json"});

  final decoded = jsonDecode(res.body);
  if (decoded["success"] != true) {
    throw Exception(decoded["message"] ?? "API failed");
  }

  return List<Map<String, dynamic>>.from(decoded["data"] ?? []);
}

static Future<void> approveVehicleRequest({required int requestId}) async {
  final url = Uri.parse("$baseUrl/approve_vehicle_request.php");
  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json", "Accept": "application/json"},
    body: jsonEncode({"request_id": requestId}),
  );

  final decoded = jsonDecode(res.body);
  if (decoded["success"] != true) {
    throw Exception(decoded["message"] ?? "Approve failed");
  }
}

static Future<void> rejectVehicleRequest({
  required int requestId,
  required String comment,
}) async {
  final url = Uri.parse("$baseUrl/reject_vehicle_request.php");
  final res = await http.post(
    url,
    headers: {"Content-Type": "application/json", "Accept": "application/json"},
    body: jsonEncode({"request_id": requestId, "comment": comment}),
  );

  final decoded = jsonDecode(res.body);
  if (decoded["success"] != true) {
    throw Exception(decoded["message"] ?? "Reject failed");
  }
}

}