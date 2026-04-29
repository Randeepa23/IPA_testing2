import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Constants/app_colors.dart';
import '../Services/api_service.dart';
import '../Services/meeting_and_event_service.dart';
import 'create_event_screen.dart';
import 'participants_sheet.dart';

class MeetingDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MeetingDashboardScreen({super.key, required this.user});

  @override
  State<MeetingDashboardScreen> createState() => _MeetingDashboardScreenState();
}

class _MeetingDashboardScreenState extends State<MeetingDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _meetings = [];
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};
  final Map<int, String> _staffNameById = {};

  @override
  void initState() {
    super.initState();
    _fetchMeetings();
    _loadStaffDirectory();
  }

  Future<void> _loadStaffDirectory() async {
    try {
      final res = await MeetingAndEventService.getAllStaff();
      final List members = res["members"] ?? [];
      final mapped = <int, String>{};
      for (final raw in members) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = int.tryParse(
          (item["employee_id"] ?? item["id"] ?? "").toString(),
        );
        if (id == null) continue;
        final name = (item["name"] ??
                item["employee_name"] ??
                item["preferred_name"] ??
                item["full_name"] ??
                "")
            .toString()
            .trim();
        mapped[id] = name.isEmpty ? "Unknown Employee" : name;
      }
      if (!mounted) return;
      setState(() {
        _staffNameById
          ..clear()
          ..addAll(mapped);
      });
    } catch (_) {
      // Keep UI functional even if staff directory fails.
    }
  }

  Future<void> _ensureMemberNamesLoaded(List<int> memberIds) async {
    if (memberIds.isEmpty) return;
    final hasMissing = memberIds.any((id) => !_staffNameById.containsKey(id));
    if (!hasMissing) return;
    await _loadStaffDirectory();
  }

  Future<void> _fetchMeetings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await MeetingAndEventService.getAllMeetings();
      if (!mounted) return;
      setState(() {
        _meetings = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return date;
    }
  }

  String _formatTimeRange(String start, String end) {
    try {
      final startParts = start.split(":");
      final endParts = end.split(":");
      if (startParts.length < 2 || endParts.length < 2) return "$start - $end";
      final now = DateTime.now();
      final from = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );
      final to = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );
      return "${DateFormat('hh:mm a').format(from)} - ${DateFormat('hh:mm a').format(to)}";
    } catch (_) {
      return "$start - $end";
    }
  }

  int _participantCount(dynamic membersIds) {
    if (membersIds is List) return membersIds.length;
    return 0;
  }

  List<int> _memberIds(dynamic membersIds) {
    if (membersIds is! List) return [];
    return membersIds
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .toList();
  }

  Map<String, String> _responseStatusMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), (val ?? "pending").toString()),
      );
    }
    return {};
  }

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

  String _badgeText(String status) {
    switch (status.toLowerCase()) {
      case "ongoing":
        return "LIVE";
      case "completed":
        return "DONE";
      case "cancelled":
        return "CANCELLED";
      default:
        return "UPCOMING";
    }
  }

  Color _stripeColor(String status) {
    switch (status.toLowerCase()) {
      case "ongoing":
        return const Color(0xFF2E7D32);
      case "completed":
        return const Color(0xFF455A64);
      case "cancelled":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Meeting & Events'),
        actions: [
          IconButton(
            onPressed: _fetchMeetings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _createEventButton(context),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              _topSummaryCard(),
              const SizedBox(height: 14),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
            const SizedBox(height: 8),
            Text(
              "Failed to load meetings",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _fetchMeetings,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    if (_meetings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchMeetings,
        child: ListView(
          children: const [
            SizedBox(height: 140),
            Icon(Icons.event_note, size: 52, color: Colors.black38),
            SizedBox(height: 10),
            Center(
              child: Text(
                "No meetings found",
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: ListView(
        children: [
          const Text(
            "Upcoming & Recent",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163A70),
            ),
          ),
          const SizedBox(height: 10),
          ..._meetings.map((m) {
            final status = (m["status"] ?? "scheduled").toString();
            return _meetingCard(
              title: (m["title"] ?? "Untitled").toString(),
              type: (m["type"] ?? "").toString().toUpperCase(),
              date: _formatDate((m["meeting_date"] ?? "").toString()),
              time: _formatTimeRange(
                (m["start_time"] ?? "").toString(),
                (m["end_time"] ?? "").toString(),
              ),
              location: (m["location"] ?? "-").toString(),
              participants: _participantCount(m["members_ids"]),
              memberIds: _memberIds(m["members_ids"]),
            responseStatus: _responseStatusMap(m["response_status"]),
              stripeColor: _stripeColor(status),
              badgeText: _badgeText(status),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _topSummaryCard() {
    final total = _meetings.length;
    final ongoing = _meetings
        .where((m) => (m["status"] ?? "").toString().toLowerCase() == "ongoing")
        .length;
    final upcoming = _meetings
        .where((m) => (m["status"] ?? "").toString().toLowerCase() == "scheduled")
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Meetings Overview",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163A70),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _countPill("Total", total, const Color(0xFF1565C0)),
              const SizedBox(width: 8),
              _countPill("Live", ongoing, const Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              _countPill("Upcoming", upcoming, const Color(0xFF5E6A7D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countPill(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $value",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _createEventButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryStart, AppColors.primaryEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryEnd.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateEventScreen(user: widget.user)),
            ).then((_) => _fetchMeetings());
          },
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Create Event',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _meetingCard({
    required String title,
    required String type,
    required String date,
    required String time,
    required String location,
    required int participants,
    required List<int> memberIds,
    required Map<String, String> responseStatus,
    required Color stripeColor,
    required String badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 118,
            decoration: BoxDecoration(
              color: stripeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stripeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stripeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _metaRow(Icons.category_outlined, 'Type: $type'),
                  const SizedBox(height: 4),
                  _metaRow(Icons.calendar_month_rounded, date),
                  const SizedBox(height: 4),
                  _metaRow(Icons.access_time_rounded, time),
                  const SizedBox(height: 4),
                  _metaRow(Icons.place_outlined, location),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.groups_2_outlined, size: 16, color: Color(0xFF5E6A7D)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$participants participants',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF4A5568),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await _ensureMemberNamesLoaded(memberIds);
                          if (!mounted) return;
                          showParticipantsSheet(
                            context: context,
                            title: title,
                            memberIds: memberIds,
                            responseStatus: responseStatus,
                            staffNameById: _staffNameById,
                            getPhotoFuture: _getPhotoFuture,
                          );
                        },
                        child: _participantAvatars(memberIds),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5E6A7D)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _participantAvatars(List<int> memberIds) {
    if (memberIds.isEmpty) return const SizedBox.shrink();

    const maxVisible = 4;
    const radius = 12.0;
    const overlap = 8.0;
    final visible = memberIds.take(maxVisible).toList();
    final hiddenCount = memberIds.length - visible.length;
    final totalWidth = (visible.length - 1) * (radius * 2 - overlap) + (radius * 2);

    return SizedBox(
      width: totalWidth + (hiddenCount > 0 ? 24 : 0),
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * (radius * 2 - overlap),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _getPhotoFuture(visible[i]),
                builder: (context, snap) {
                  final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                  return CircleAvatar(
                    radius: radius,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: radius - 1.5,
                      backgroundColor: const Color(0xFFEAF1FF),
                      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
                      child: url.isEmpty
                          ? const Icon(Icons.person, size: 12, color: Colors.black54)
                          : null,
                    ),
                  );
                },
              ),
            ),
          if (hiddenCount > 0)
            Positioned(
              left: totalWidth + 4,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: const Color(0xFFE5EAF5),
                child: Text(
                  '+$hiddenCount',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A5568),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}
