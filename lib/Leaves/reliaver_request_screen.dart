import 'package:flutter/material.dart';

class RelieverRequestView extends StatefulWidget {
  const RelieverRequestView({super.key});

  @override
  State<RelieverRequestView> createState() => _RelieverRequestViewState();
}
class _RelieverRequestViewState extends State<RelieverRequestView> {
  //Demo list (replace with backend list)
  final List<Map<String, dynamic>> requests = [
    {
      "name": "Nimal Perera",
      "role": "Tour Manager",
      "empNo": "EV2024001",
      "leaveType": "Annual",
      "from": "2026-03-15",
      "to": "2026-03-16",
      "days": "1 days",
      "applyOn": "12/12/2025",
      "status": "Awaiting Your Response",
      "noteController": TextEditingController(),
    },
    {
      "name": "Sanduni Perera",
      "role": "Tour Manager",
      "empNo": "EV2024001",
      "leaveType": "Annual",
      "from": "2026-03-15",
      "to": "2026-03-16",
      "days": "1 days",
      "applyOn": "12/12/2025",
      "status": "Awaiting Your Response",
      "noteController": TextEditingController(),
    },
  ];

  int selectedTopTab = 2; // for your top button highlight

  @override
  void dispose() {
    for (final r in requests) {
      (r["noteController"] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800] ?? Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // ✅ list cards
            ...requests.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _requestCard(r, blue),
                )),
          ],
        ),
      ),
    );
  }

  // ---------------- CARD UI ----------------

  Widget _requestCard(Map<String, dynamic> r, Color blue) {
    final ctrl = r["noteController"] as TextEditingController;

    return Container(
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
          // header row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.person, size: 18, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r["name"],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${r["role"]}\nEmployee No: ${r["empNo"]}",
                      style: const TextStyle(
                        fontSize: 10.8,
                        height: 1.2,
                        color: Color(0xFF6B7A90),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(r["status"], const Color(0xFFE7D48A), const Color(0xFF6B4F00)),
            ],
          ),

          const SizedBox(height: 12),

          // details box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _rowLine("Leave type", r["leaveType"]),
                const SizedBox(height: 8),
                _rowLine("From date", r["from"]),
                const SizedBox(height: 8),
                _rowLine("To date", r["to"]),
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
                        r["days"],
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

          const Text(
            "Add Note (Optional)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2A3A),
            ),
          ),
          const SizedBox(height: 8),

          // ✅ note field (tap and type)
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Type........",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE1E6EF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: (Colors.blue[800] ?? Colors.blue)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: decline API
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Decline tapped")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB10F0F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Decline\nCoverage",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showAcceptDialog(
                    employeeName: r["name"],
                    note: ctrl.text,
                    onAccept: () {
                      // ✅ put your accept API call here
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Accepted (Note: ${ctrl.text})")),
                      );
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A8F2E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    "Accept and\nForward",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            "Apply on: ${r["applyOn"]}",
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

  Widget _rowLine(String left, String right) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7A90),
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E2A3A),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  // ---------------- ACCEPT POPUP (LIKE YOUR IMAGE) ----------------

  void _showAcceptDialog({
    required String employeeName,
    required String note,
    required VoidCallback onAccept,
  }) {
    final blue = Colors.blue[800] ?? Colors.blue;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(Icons.error_outline, color: Color(0xFFD64545), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Are You Accept Request",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close, size: 18, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "This action cannot be undone",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF6B7A90)),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to accept this leave request from $employeeName?\nYour leave balance will be restored.",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E2A3A), height: 1.3),
                ),
                if (note.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Note: $note",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E2A3A)),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE1E6EF)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onAccept();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Accept",
                          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}