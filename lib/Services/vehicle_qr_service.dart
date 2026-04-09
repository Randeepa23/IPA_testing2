import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/vehicle_q_model.dart';

class VehicleQrService {

  static const String _vehicleApiBaseUrl = "https://srilankaautorentals.com/api";

  static Future<VehicleQrModel> getVehicleDetails(String vehicleNo, {required String preferredName, required String employeeId, required String vehicleNumber}) async {
    try {
      final response = await http.get(
        Uri.parse('$_vehicleApiBaseUrl/vehicle-details/$vehicleNo'),
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
  
 // Kept for backward compatibility with existing callers
static Future<VehicleQrModel> getVehicleDetailsWithLog({
    required String employeeId,
    required String preferredName,
    required String vehicleNumber,
  }) async {
    return getVehicleDetails(
      vehicleNumber,
      preferredName: preferredName,
      employeeId: employeeId,
      vehicleNumber: vehicleNumber,
    );
  }
}