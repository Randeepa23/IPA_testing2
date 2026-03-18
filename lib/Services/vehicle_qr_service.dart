import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/vehicle_q_model.dart';

class VehicleQrService {
  static const String baseUrl = 'https://exploredrive.lk/api';

  static Future<VehicleQrModel> getVehicleDetails(String vehicleNo) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicle-details/$vehicleNo'),
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
}