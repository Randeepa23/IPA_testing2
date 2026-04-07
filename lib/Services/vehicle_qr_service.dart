import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/vehicle_q_model.dart';

class VehicleQrService {

  //static const String baseUrl= "http://10.0.2.2/mobile-api/api";
  static const String baseUrl = "https://exploresuite.lk/mobile-api/api";

  static const String exploredrive = 'https://exploredrive.lk/api';

  static Future<VehicleQrModel> getVehicleDetails(String vehicleNo, {required String preferredName, required String employeeId, required String vehicleNumber}) async {
    try {
      final response = await http.get(
        Uri.parse('$exploredrive/vehicle-details/$vehicleNo'),
        headers: {
          'Accept': 'application/json',
        },
      );

      final Map<String, dynamic> jsonData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return VehicleQrModel.fromJson(jsonData);
      } else {
        return VehicleQrModel(
          status: false,
          message: jsonData['message'] ?? 'Failed to fetch vehicle details',
          data: null,
        );
      }
    } catch (e) {
      return VehicleQrModel(
        status: false,
        message: 'Something went wrong: $e',
        data: null,
      );
    }
   }
  
 //NEW API (use this one)
static Future<VehicleQrModel> getVehicleDetailsWithLog({
    required String employeeId,
    required String preferredName,
    required String vehicleNumber,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/get_vehicle_qr.php");

      final response = await http.post(
        uri,
        body: {
          "employee_id": employeeId,
          "preferred_name": preferredName,
          "vehicle_number": vehicleNumber,
        },
      );

      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      return VehicleQrModel.fromJson(jsonData);
    } catch (e) {
      return VehicleQrModel(
        status: false,
        message: "Something went wrong: $e",
        data: null,
      );
    }
  }
}