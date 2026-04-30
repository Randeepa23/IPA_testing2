import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test_app/Models/vehicle_utilization_model.dart';

class VehicleUtilizationService {
  // Base URL - can be configured from backend settings
  static const String baseUrl = 'srilankaautorentals.com';
  static const String endpoint = '/api/vehicle-utilization';

  /// Fetch vehicle utilization data for a date range
  /// 
  /// Parameters:
  /// - [from]: Start date in yyyy-MM-dd format
  /// - [to]: End date in yyyy-MM-dd format (optional, defaults to [from])
  /// 
  /// Returns: [VehicleUtilizationResponse] with period, totals, and vehicle data
  static Future<VehicleUtilizationResponse> fetchUtilization({
    required String from,
    String? to,
  }) async {
    final query = <String, String>{'from': from};
    if (to != null && to.trim().isNotEmpty) {
      query['to'] = to.trim();
    }

    final uri = Uri.https(baseUrl, endpoint, query);

    try {
      final response = await http.get(uri).timeout(
        const Duration(seconds: 20),
      );

      if (response.statusCode != 200) {
        throw VehicleUtilizationException(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw VehicleUtilizationException('Invalid JSON response format');
      }

      return VehicleUtilizationResponse.fromJson(decoded);
    } catch (e) {
      if (e is VehicleUtilizationException) rethrow;
      throw VehicleUtilizationException('Failed to fetch data: $e');
    }
  }

  /// Format DateTime to API date format (yyyy-MM-dd)
  static String formatApiDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parse API date string to DateTime
  static DateTime parseApiDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Custom exception for vehicle utilization API errors
class VehicleUtilizationException implements Exception {
  final String message;

  VehicleUtilizationException(this.message);

  @override
  String toString() => message;
}
