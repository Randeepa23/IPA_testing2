import 'package:flutter/material.dart';
import 'dart:ui';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  // Dummy requests (replace with API data)
  final List<Map<String, dynamic>> requests = [
    {
      "employeeName": "Nimal Perera",
      "position": "Senior Tour Coordinator",
      "employeeId": "EV2024001",
      "leaveType": "Annual Leave",
      "from": "2026-03-15",
      "to": "2026-03-19",
      "days": 4,
      "reason": "Family vacation to Ella",
      "coveringOfficer": {
        "name": "Kasun Silva",
        "note": "I confirm coverage. All bookings managed."
      },
      "attachmentName": "hotel_booking.pdf", // ✅ available
    },
    {
      "employeeName": "Lahiru Perera",
      "position": "Senior Tour Coordinator",
      "employeeId": "EV2024002",
      "leaveType": "Casual Leave",
      "from": "2026-03-15",
      "to": "2026-03-19",
      "days": 4,
      "reason": "Family vacation to Ella",
      "coveringOfficer": {
        "name": "Kasun Silva",
        "note": "I confirm coverage. All bookings managed."
      },
      "attachmentName": null, // NOT available
    },
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    final pad = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Leave Request"),
        foregroundColor: Colors.black,
        elevation: 0.6,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(pad),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final r = requests[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _LeaveRequestCard(
              data: r,
              onReject: () => _showRejectDialog(context, r),
              onApprove: () => _showApproveDialog(context, r),
            ),
          );
        },
      ),
    );
  }

  // ====================== REJECT POPUP (comment required) ======================
Future<void> _showRejectDialog(BuildContext context, Map<String, dynamic> r) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15), // optional dim
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(280.0, 420.0);

      return Stack(
        children: [
          // BACKGROUND BLUR ONLY
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
          ),

          // YOUR EXISTING DIALOG (UNCHANGED)
          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Reject Leave Request",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "This action cannot be undone.",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 12),
                        const Text(
                          "Your Comment",
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),

                        TextFormField(
                          controller: controller,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Peak season - unable to approve...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return "Comment is required for reject";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        const Text(
                          "Are you sure you want to reject this leave request?",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Cancel"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (!formKey.currentState!.validate()) return;

                                  final comment = controller.text.trim();

                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Rejected with comment: $comment")),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Reject", style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}




  // ====================== APPROVE POPUP (no comment) ======================
  Future<void> _showApproveDialog(BuildContext context, Map<String, dynamic> r) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15), // dim (optional)
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;

      // KEEP SAME WIDTH AS REJECT
      final dialogW = (w * 0.90).clamp(300.0, 420.0);

      return Stack(
        children: [
          //BLUR BACKGROUND
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.transparent),
          ),

          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW, //width controlled here
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Approve Leave Request",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Please confirm approval.",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 14),
                      Text(
                        "Approve leave for ${r['employeeName']}?",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Approved successfully")),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Approve", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
 }
}

// ====================== CARD UI ======================
class _LeaveRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _LeaveRequestCard({
    required this.data,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    final attachment = data["attachmentName"];
    final covering = data["coveringOfficer"] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ top employee row (UNCHANGED)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEAF1FF),
                child: Icon(Icons.person, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data["employeeName"] ?? "",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${data["position"] ?? ""}\nEmployee ID: ${data["employeeId"] ?? ""}",
                      style: const TextStyle(
                        color: Color(0xFF6B7A90),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Leave type", data["leaveType"]),
                const SizedBox(height: 8),
                _detailRow("From date", data["from"]),
                const SizedBox(height: 8),
                _detailRow("To date", data["to"]),

                const SizedBox(height: 10),

                // total days blue bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Total Days:",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                      Text(
                        "${data["days"]}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2A3A),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          //Reason (UNCHANGED)
          _boxField("Reason", data["reason"] ?? ""),

          const SizedBox(height: 10),

          //Covering Officer (UNCHANGED)
          if (covering != null) ...[
            _boxField(
              "Covering Officer",
              "Name: ${covering["name"] ?? "-"}\nNote: \"${covering["note"] ?? "-"}\"",
            ),
            const SizedBox(height: 10),
          ],

          //Attachment row (KEEP, optional)
          if (attachment != null && attachment.toString().trim().isNotEmpty) ...[
            _attachmentRow(attachment.toString()),
            const SizedBox(height: 10),
          ] else ...[
            const Text(
              "Attached document: No update",
              style: TextStyle(
                color: Color(0xFF6B7A90),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],

          //Buttons (UNCHANGED)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Reject",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Approve",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  //NEW detail row style (label left, value right) — like your UI
  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2A3A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  //SAME box style (Reason / Covering)
  Widget _boxField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7A90),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2A3A),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  // SAME attachment row (kept)
  Widget _attachmentRow(String fileName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file, color: Color(0xFF1E88E5), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E88E5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: open/download attachment
            },
            icon: const Icon(Icons.download, size: 18),
          ),
        ],
      ),
    );
  }
}

