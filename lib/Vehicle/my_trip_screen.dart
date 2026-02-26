import 'dart:ui';
import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';

class MyTripsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTripsScreen({super.key, required this.user});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  int selectedTab = 0; // 0 Pending, 1 Approved, 2 In Progress, 3 Completed
  bool loading = false;
  String? errorText;

  List<Map<String, dynamic>> trips = [];

  @override
  void initState() {
    super.initState();
    _refreshTrips();
  }

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  Future<void> _refreshTrips() async {
    try {
      setState(() {
        loading = true;
        errorText = null;
      });

      final empId = _employeeId();
      if (empId.isEmpty || empId == "0" || empId == "null") {
        throw Exception("employee_id missing in login data");
      }

      final res = await VehicleApiService.getMyTrips(employeeId: empId);

      if (res["success"] != true) {
        throw Exception(res["message"] ?? "Failed to load trips");
      }

      final data = res["data"] ?? [];
      final list = List<Map<String, dynamic>>.from(data);

      setState(() => trips = list);
    } catch (e) {
      setState(() => errorText = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredTrips() {
    final status = (selectedTab == 0)
        ? "PENDING"
        : (selectedTab == 1)
            ? "APPROVED"
            : (selectedTab == 2)
                ? "IN_PROGRESS"
                : "COMPLETED";

    return trips.where((t) => (t["status"] ?? "") == status).toList();
  }

  Future<bool?> _confirmCancelTrip() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        final dialogW = (w * 0.92).clamp(280.0, 420.0);

        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.15)),
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
                            const Icon(Icons.info_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Do you want to cancel this request",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const Text(
                          "This action cannot be undone",
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8EDF5)),
                          ),
                          child: const Text(
                            "Are you sure you want to cancel this vehicle trip request?",
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Cancel"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Confirm",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
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
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    try {
      final id = (t["id"] ?? "").toString();
      if (id.isEmpty) throw Exception("Trip id missing");

      setState(() => loading = true);

      final res = await VehicleApiService.cancelTrip(id: id);

      if (res["success"] == true) {
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Request canceled",
          message: "Your pending vehicle trip request has been canceled successfully.",
          icon: Icons.cancel,
        );
        await _refreshTrips();
      } else {
        throw Exception(res["message"] ?? "Cancel failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrips();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshTrips,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SegmentTabs(
                      selectedIndex: selectedTab,
                      onChanged: (i) => setState(() => selectedTab = i),
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _refreshTrips,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  if (!loading && errorText == null && filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12, top: 10),
                      child: Center(child: Text("No trips found")),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripCard(
                data: t,
                onCancel: (t["status"] == "PENDING")
                    ? () async {
                        final ok = await _confirmCancelTrip();
                        if (ok == true) _cancelTrip(t);
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ------------------ Segmented Tabs ------------------
class _SegmentTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _pill("Pending", 0),
          const SizedBox(width: 6),
          _pill("Approved", 1),
          const SizedBox(width: 6),
          _pill("In Progress", 2),
          const SizedBox(width: 6),
          _pill("Completed", 3),
        ],
      ),
    );
  }

  Widget _pill(String text, int index) {
    final active = selectedIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF0B5FA5)
                : const Color.fromARGB(255, 250, 250, 250),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    )
                  ]
                : [],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------ Trip Card ------------------
class TripCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onCancel;

  const TripCard({super.key, required this.data, this.onCancel});

  Widget _gradientButton({
    required String text,
    required VoidCallback onTap,
    List<Color> colors = const [Color(0xFF1DB954), Color(0xFF0B7A34)],
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12.8,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "").toString();

    final isPending = status == "PENDING";
    final isApproved = status == "APPROVED";
    final isInProgress = status == "IN_PROGRESS";
    final isCompleted = status == "COMPLETED";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (data["vehicleNo"] ?? "").toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                ),
                _statusPill(status),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
                // ✅ PENDING: only Reason, Destination, From, To (NO Trip Code)
                if (isPending) ...[
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date", (data["toDate"] ?? "").toString()),
                  if (onCancel != null) ...[
                    const SizedBox(height: 12),
                    _gradientButton(
                      text: "Cancel Request",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: onCancel!,
                    ),
                  ],
                ],

                // ✅ APPROVED: show Trip Code + Approved By ONLY here
                if (isApproved) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date", (data["toDate"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Approved By", (data["approvedBy"] ?? "").toString()),
                  const SizedBox(height: 12),
                  _gradientButton(
                    text: "Start Trip (Enter Meter Reading)",
                    onTap: () {
                      showStartTripDialog(
                        context: context,
                        vehicleNo: data["vehicleNo"],
                        destination: data["destination"],
                        isSubmitting: false,
                        onConfirm: ({
                          required meterReading,
                          required fuelPercent,
                          required meterPhoto,
                        }) async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Trip started successfully")),
                          );
                        },
                      );
                    },
                  ),
                ],

                // ✅ IN_PROGRESS: show Trip Code + Start Meter details
                if (isInProgress) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),
                  const SizedBox(height: 12),
                  _gradientButton(
                    text: "Stop Trip & Submit",
                    colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                    onTap: () {
                      showStopTripDialog(
                        context: context,
                        vehicleNo: data["vehicleNo"],
                        destination: data["destination"],
                        isSubmitting: false,
                        onConfirm: ({
                          required meterReading,
                          required fuelPercent,
                          required meterPhoto,
                        }) async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Trip stopped successfully")),
                          );
                        },
                      );
                    },
                  ),
                ],

                // ✅ COMPLETED: keep your full details (ok)
                if (isCompleted) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Meter", "${data["endMeter"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("Distance Traveled by Odometer", "${data["odoDistance"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("GPS Calculated Distance", "${data["gpsDistance"] ?? "-"} km"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final label = status == "PENDING"
        ? "Pending"
        : status == "APPROVED"
            ? "Approved"
            : status == "IN_PROGRESS"
                ? "In-progress"
                : "Completed";

    Color bg;
    Color border;
    Color text;
    IconData icon;
    Color iconColor;

    if (status == "PENDING") {
      bg = const Color(0xFFFFF3CD);
      border = const Color(0xFFFFE49A);
      text = const Color(0xFF8A6D3B);
      icon = Icons.hourglass_bottom;
      iconColor = const Color(0xFF8A6D3B);
    } else if (status == "APPROVED") {
      bg = const Color(0xFFE5E5E5);
      border = const Color(0xFFD3D3D3);
      text = const Color(0xFF7A7A7A);
      icon = Icons.check_circle;
      iconColor = const Color(0xFF7A7A7A);
    } else if (status == "IN_PROGRESS") {
      bg = const Color(0xFFE6E6E6);
      border = const Color(0xFFD0D0D0);
      text = const Color(0xFF7A7A7A);
      icon = Icons.schedule;
      iconColor = const Color(0xFF7A7A7A);
    } else {
      bg = const Color(0xFFCDEED3);
      border = const Color(0xFF9AD7A6);
      text = const Color(0xFF2E7D32);
      icon = Icons.verified;
      iconColor = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: text),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFD8E7F4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E3F3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.8,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}