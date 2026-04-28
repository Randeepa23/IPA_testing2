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

  // Create meeting/event API
  static Future<Map<String, dynamic>> createMeeting({
    required String type,
    required String title,
    required String description,
    required String meetingDate,
    required String startTime,
    required String endTime,
    required String locationType,
    required String location,
    required List<String> membersIds,
    required int createdBy,
    String status = "scheduled",
    String responseStatus = "{}",
    String attachments = "[]",
  }) async {
    final url = Uri.parse("$baseUrl/create_event.php");
    final normalizedMemberIds = membersIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final autoResponseStatusMap = <String, String>{
      for (final id in normalizedMemberIds) id: "pending",
    };
    final resolvedResponseStatus =
        responseStatus.trim().isEmpty || responseStatus.trim() == "{}"
            ? jsonEncode(autoResponseStatusMap)
            : responseStatus;

    final res = await http.post(
      url,
      headers: {
        "Accept": "application/json",
      },
      body: {
        "type": type,
        "title": title,
        "description": description,
        "meeting_date": meetingDate,
        "start_time": startTime,
        "end_time": endTime,
        "location_type": locationType,
        "location": location,
        "members_ids": jsonEncode(normalizedMemberIds),
        "status": status,
        "created_by": createdBy.toString(),
        "user_id": createdBy.toString(),
        "response_status": resolvedResponseStatus,
        "attachments": attachments,
      },
    ).timeout(const Duration(seconds: 15));

    if (res.body.trim().isEmpty) {
      throw Exception("EMPTY response");
    }

    if (res.statusCode != 200) {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw Exception("Invalid JSON response: ${res.body}");
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception("Unexpected response format");
    }

    return decoded;
  }

}