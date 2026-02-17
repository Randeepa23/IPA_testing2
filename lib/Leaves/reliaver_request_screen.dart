import 'dart:ui';
import 'top_banner.dart';
import 'package:flutter/material.dart';
import 'package:test_app/Services/api_service.dart';

class RelieverRequestView extends StatefulWidget {
  final Map<String, dynamic> user;
  const RelieverRequestView({super.key, required this.user});

  @override
  State<RelieverRequestView> createState() => _RelieverRequestViewState();

  
}

class _RelieverRequestViewState extends State<RelieverRequestView> {
  List<Map<String, dynamic>> requests = [];
  bool loading = false;
  String? errorText;



  void _showSuccessBanner(String title, String message) {
  TopBanner.show(
    context,
    title: title,
    message: message,
    icon: Icons.check_circle,
    rightButtonText: "OK",
  );
}

void _showErrorBanner(String title, String message) {
  TopBanner.show(
    context,
    title: title,
    message: message,
    icon: Icons.error_outline,
    rightButtonText: "OK",
  );
}


  @override
  void initState() {
    super.initState();
    _loadRelieverRequests();
  }

  Future<void> _loadRelieverRequests() async {
    try {
      setState(() {
        loading = true;
        errorText = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loading = false;
          errorText = "employeeId not found in login data";
        });
        return;
      }

      final res = await ApiService.getRelieverRequests(employeeId: employeeId);

      if (!mounted) return;

      if (res["success"] == true) {
        final raw = res["requests"] ?? res["data"] ?? [];
        final list = List<Map<String, dynamic>>.from(raw);

        // Keep reference to old controllers so we can dispose after build
        final oldRequests = List<Map<String, dynamic>>.from(requests);

        // add controller per item for new list
        for (final r in list) {
          r["noteController"] = TextEditingController(text: "");
        }

        setState(() {
          requests = list;
          loading = false;
        });

        // Dispose old controllers after this frame so TextFields have released them
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final r in oldRequests) {
            final c = r["noteController"];
            if (c is TextEditingController) c.dispose();
          }
        });
      } else {
        setState(() {
          loading = false;
          errorText = (res["message"] ?? "Failed to load").toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = e.toString();
      });
    }
  }

  @override
  void dispose() {
    for (final r in requests) {
      final c = r["noteController"];
      if (c is TextEditingController) c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800] ?? Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
      onRefresh: _loadRelieverRequests,
      color: Colors.blue,
      backgroundColor: Colors.white,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 8),

        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (errorText != null)
          Column(
            children: [
              Text(errorText!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadRelieverRequests,
                child: const Text("Retry"),
              ),
            ],
          )
        else if (requests.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text("No reliever requests")),
          )
        else
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

    String getStr(List<String> keys, {String fallback = "-"}) {
      for (final k in keys) {
        final v = r[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
      return fallback;
    }

    final int leaveRequestId = (r["leaveRequestId"] is int)
        ? r["leaveRequestId"] as int
        : int.tryParse((r["leaveRequestId"] ?? "0").toString()) ?? 0;

    final relieverId = widget.user["employeeId"]?.toString() ?? "";

    final name = getStr(["name", "employee_name"]);
    final role = getStr(["job_title_name", "designation", "job_title"], fallback: "");
    final empNo = getStr(["empNo", "employeeCode", "employee_code"], fallback: "-");
    final leaveType = getStr(["leaveType", "leave_type"]);
    final from = getStr(["from", "leave_start_date"]);
    final to = getStr(["to", "leave_end_date"]);
    final days = getStr(["days", "number_of_days"], fallback: "0");
    final applyOn = getStr(["applyOn", "requested_at"], fallback: "-");
    final status = getStr(["status"], fallback: "Awaiting Your Response");

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
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2A3A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${role.isEmpty ? '' : role}\nEmployee No: $empNo",
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
              _statusPill(status, const Color(0xFFE7D48A), const Color(0xFF6B4F00)),
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
                _rowLine("Leave type", leaveType),
                const SizedBox(height: 8),
                _rowLine("From date", from),
                const SizedBox(height: 8),
                _rowLine("To date", to),
                const SizedBox(height: 10),
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
                        days,
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

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showDeclineDialog(
                    employeeName: name,
                    initialNote: "",
                    onDecline: (comment) async {
                      if (leaveRequestId <= 0 || relieverId.isEmpty) return;

                     final res = await ApiService.relieverDecline(
                        leaveRequestId: leaveRequestId,
                        relieverId: relieverId,
                        comment: comment,
                      );

                      if (!mounted) return;

                      if (res["success"] == true) {
                      TopBanner.show(
                        context,
                        title: "Request Declined",
                        message: "Your pending leave request has been canceled successfully.",
                        icon: Icons.cancel,
                        isSuccess: true,
                      );

                        // refresh list
                        await _loadRelieverRequests();
                      } else {
                        _showErrorBanner(
                          "Decline failed",
                          res["message"]?.toString() ?? "Please try again.",
                        );
                      }
                      await _loadRelieverRequests();
                    },
                  ),

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
                    employeeName: name,
                    initialNote: "",
                    onAccept: (comment) async {
                      if (leaveRequestId <= 0 || relieverId.isEmpty) return;

                      final res = await ApiService.relieverAccept(
                        leaveRequestId: leaveRequestId,
                        relieverId: relieverId,
                        comment: comment,
                      );

                      if (!mounted) return;
                     if (res["success"] == true) {
                      TopBanner.show(
                        context,
                        title: "Request Accepted and Forwarded",
                        message: "Your pending leave request has been accepted successfully.",
                        icon: Icons.check_circle,
                      );

                        // refresh list
                        await _loadRelieverRequests();
                      } else {
                        _showSuccessBanner(
                          "Accept failed",
                          res["message"]?.toString() ?? "Please try again.",
                        );
                      }
                      await _loadRelieverRequests();
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
            "Apply on: $applyOn",
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

  // ========= Decline dialog (comment required) =========
  Future<void> _showDeclineDialog({
    required String employeeName,
    required String initialNote,
    required Function(String comment) onDecline,
  }) async {
    final controller = TextEditingController(text: initialNote);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final dialogW = (w * 0.92).clamp(280.0, 420.0);

        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.transparent),
            ),
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
                                  "Decline Reliever Coverage",
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
                          const Text("Your Comment", style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: controller,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: "Explain why you cannot cover this leave...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Comment is required for decline";
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Are you sure you want to decline covering leave for $employeeName?",
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                                    onDecline(comment);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD32F2F),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: const Text(
                                    "Decline",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
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

    // Dispose after dialog tree has been torn down to avoid _dependents.isEmpty
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }

  // ========= Accept dialog (comment optional) =========
  Future<void> _showAcceptDialog({
    required String employeeName,
    required String initialNote,
    required Function(String comment) onAccept,
  }) async {
    final controller = TextEditingController(text: initialNote);

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final dialogW = (w * 0.92).clamp(280.0, 420.0);

        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.transparent),
            ),
            Center(
              child: Dialog(
                insetPadding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: SizedBox(
                  width: dialogW,
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
                                "Accept & Forward Request",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text("Your Comment", style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "e.g. I will cover all responsibilities during these dates...",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Are you sure you want to accept and forward this leave request for $employeeName?",
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                                  final comment = controller.text.trim();
                                  Navigator.pop(ctx);

                                  onAccept(comment);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 57, 138, 60),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text(
                                  "Accept & Forward",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
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

    // Dispose after dialog tree has been torn down to avoid _dependents.isEmpty
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}
