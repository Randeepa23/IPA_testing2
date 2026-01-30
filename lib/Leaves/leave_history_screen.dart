import 'package:flutter/material.dart';
class LeaveHistoryScreen extends StatefulWidget {
  const LeaveHistoryScreen({super.key});

  @override
  State<LeaveHistoryScreen> createState() => _LeaveHistoryScreenState();
}

enum LeaveStatus { pending, approved, rejected, canceled }

class LeaveRequest {
  final String leaveType;
  final String reason;
  final String startDate;
  final String endDate;
  final String duration;
  final String appliedOn;
  final LeaveStatus status;
  final String? managerComment;

  LeaveRequest({
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.appliedOn,
    required this.status,
    this.managerComment,
  });
}

class _LeaveHistoryScreenState extends State<LeaveHistoryScreen> {
  int selectedTopTab = 1; // 0 profile, 1 history, 2 reliever
  int selectedFilter = 0; // 0 all, 1 pending, 2 approved, 3 rejected

  // Dummy data (replace with API list)
  final List<LeaveRequest> allRequests = [
    LeaveRequest(
      leaveType: 'Annual Leave',
      reason: 'Family Vacation to Ella',
      startDate: '12/12/2025',
      endDate: '12/12/2025',
      duration: '1 Days',
      appliedOn: '12/12/2025',
      status: LeaveStatus.pending,
    ),
    LeaveRequest(
      leaveType: 'Annual Leave',
      reason: 'Family Vacation to Ella',
      startDate: '12/12/2025',
      endDate: '12/12/2025',
      duration: '1 Days',
      appliedOn: '12/12/2025',
      status: LeaveStatus.approved,
      managerComment: 'Approved. Enjoy your time off!',
    ),
    LeaveRequest(
      leaveType: 'Casual Leave',
      reason: 'Personal work',
      startDate: '20/12/2025',
      endDate: '20/12/2025',
      duration: '1 Days',
      appliedOn: '18/12/2025',
      status: LeaveStatus.rejected,
      managerComment: 'Not possible on this date.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800]!;
    final counts = _counts(allRequests);

    final filtered = _filteredList(allRequests);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Filter chips row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All (${counts['all']})', 0, blue),
                  const SizedBox(width: 8),
                  _filterChip('Pending (${counts['pending']})', 1, blue),
                  const SizedBox(width: 8),
                  _filterChip('Approved (${counts['approved']})', 2, blue),
                  const SizedBox(width: 8),
                  _filterChip('Rejected (${counts['rejected']})', 3, blue),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Cards list
            ...filtered.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _leaveCard(r),
                )),
          ],
        ),
      ),
    );
  }


  // ---------------- FILTER CHIPS ----------------

  Widget _filterChip(String text, int index, Color blue) {
    final active = selectedFilter == index;

    return InkWell(
      onTap: () => setState(() => selectedFilter = index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? blue : const Color(0xFFE1E6EF)),
          boxShadow: [
            if (active)
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF1E2A3A),
          ),
        ),
      ),
    );
  }

  // ---------------- LEAVE CARD ----------------

  Widget _leaveCard(LeaveRequest r) {
    final statusUi = _statusUI(r.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Leave type + status + cancel button (only pending)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.leaveType,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.reason,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7A90),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusPill(statusUi['text'] as String, statusUi['bg'] as Color, statusUi['fg'] as Color),
            ],
          ),

          if (r.status == LeaveStatus.pending) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Call cancel API
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cancel Request tapped')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD64545),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Cancel Request',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          _fieldBox(icon: Icons.calendar_month_outlined, label: 'Start Date', value: r.startDate),
          const SizedBox(height: 8),
          _fieldBox(icon: Icons.calendar_month_outlined, label: 'End Date', value: r.endDate),
          const SizedBox(height: 8),
          _fieldBox(icon: Icons.timelapse_outlined, label: 'Duration', value: r.duration),

          if (r.managerComment != null && r.managerComment!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD7E8F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E2A3A), height: 1.3),
                  children: [
                    const TextSpan(
                      text: "Manager's Comment:\n",
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: r.managerComment!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            'Apply on: ${r.appliedOn}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldBox({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E6EF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7A90)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2A3A),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  Map<String, dynamic> _statusUI(LeaveStatus s) {
    switch (s) {
      case LeaveStatus.pending:
        return {'text': 'Pending', 'bg': const Color(0xFFE7D48A), 'fg': const Color(0xFF6B4F00)};
      case LeaveStatus.approved:
        return {'text': 'Approved', 'bg': const Color(0xFFCFF1D6), 'fg': const Color(0xFF0F6B2D)};
      case LeaveStatus.rejected:
        return {'text': 'Rejected', 'bg': const Color(0xFFFFD1D1), 'fg': const Color(0xFF9B1C1C)};
      case LeaveStatus.canceled:
        return {'text': 'Canceled', 'bg': const Color(0xFFF3B7B7), 'fg': const Color(0xFF7A1010)};
    }
  }

  Map<String, int> _counts(List<LeaveRequest> list) {
    int pending = 0, approved = 0, rejected = 0;
    for (final r in list) {
      if (r.status == LeaveStatus.pending) pending++;
      if (r.status == LeaveStatus.approved) approved++;
      if (r.status == LeaveStatus.rejected) rejected++;
    }
    return {
      'all': list.length,
      'pending': pending,
      'approved': approved,
      'rejected': rejected,
    };
  }

  List<LeaveRequest> _filteredList(List<LeaveRequest> list) {
    if (selectedFilter == 0) return list;

    return list.where((r) {
      if (selectedFilter == 1) return r.status == LeaveStatus.pending;
      if (selectedFilter == 2) return r.status == LeaveStatus.approved;
      if (selectedFilter == 3) return r.status == LeaveStatus.rejected;
      return true;
    }).toList();
  }
}
