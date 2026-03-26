import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/cancel_trip_dialog.dart';

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
final rawList = List<Map<String, dynamic>>.from(data);

final mapped = await Future.wait(rawList.map((e) async {
  final tripId = (e["id"] ?? "").toString();

  String vehicleMake = "-";
  String vehicleModel = "-";
  String vehicleName = (e["vehicle_name"] ?? "").toString();

  try {
    final vehicleDetails =
        await VehicleApiService.fetchVehicleDetails(
      transportServiceId: tripId,
    );

    vehicleMake = (vehicleDetails["make"] ?? "-").toString();
    vehicleModel = (vehicleDetails["model"] ?? "-").toString();

    if (vehicleMake != "-" || vehicleModel != "-") {
      vehicleName = "$vehicleMake $vehicleModel".trim();
    }
  } catch (_) {}

  return {
    ...e,
    "vehicleName": vehicleName, // ✅ ADD THIS
  };
}));

setState(() => trips = mapped);
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
  return showCancelTripDialog(context);
}

  Future<void> _startTripAndMoveToInProgress({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? trip["transport_service_id"] ?? "0").toString()) ?? 0;
    if (tripId <= 0) return;

    try {
      setState(() => loading = true);

      final res = await VehicleApiService.startTrip(
        transportServiceId: tripId,
        odometer: int.parse(meterReading),
        fuelPercent: double.parse(fuelPercent),
        photoFile: meterPhoto,
      );

      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 2);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Trip Started",
          message: "Trip started successfully and moved to In Progress.",
          icon: Icons.check_circle,
          isSuccess: true,
        );
      } else {
        throw Exception(res["message"] ?? "Start trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Start Trip Failed",
        message: e.toString(),
        icon: Icons.error_outline,
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _stopTripAndMoveToCompleted({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? trip["transport_service_id"] ?? "0").toString()) ?? 0;
    if (tripId <= 0) return;

    try {
      setState(() => loading = true);

      final res = await VehicleApiService.stopTrip(
        transportServiceId: tripId,
        endOdometer: int.parse(meterReading),
        endFuelPercent: double.parse(fuelPercent),
        photoFile: meterPhoto,
      );

      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 3);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(
          context,
          title: "Trip Completed",
          message: "Trip completed successfully.",
          icon: Icons.check_circle,
          isSuccess: true,
        );
      } else {
        throw Exception(res["message"] ?? "Stop trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(
        context,
        title: "Stop Trip Failed",
        message: e.toString(),
        icon: Icons.error_outline,
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
                      child: Center(child: CircularProgressIndicator(
                                color: Colors.blue,
                                backgroundColor: Colors.white,
                                strokeWidth: 4,
                      )),
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
                      child: Center(child: Text("No trips found", style: TextStyle(color: Colors.grey))),
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

  const _SegmentTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

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
          _pill("Pending" , 0),
          const SizedBox(width: 6),
          _pill("Approved" , 1),
          const SizedBox(width: 6),
          _pill("In Progress" , 2),
          const SizedBox(width: 6),
          _pill("Completed" , 3),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data["vehicleNo"] ?? "").toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E2A3A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (data["vehicleName"] ?? "").toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
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
                // PENDING: only Reason, Destination, From, To (NO Trip Code)
                if (isPending) ...[
                  _infoRow("Reason", ("Office Service").toString()),
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

                // APPROVED: show Trip Code + Approved By ONLY here
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
                  _infoRow("Approved By", (data["approvedByName"] ?? "").toString()),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      onTap: () {
                        showStartTripDialog(
                          context: ctx,
                          vehicleNo: (data["vehicleNo"] ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._startTripAndMoveToInProgress(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // IN_PROGRESS: show Trip Code + Start Meter details
                if (isInProgress) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Stop Trip & Submit (Enter Meter Reading)",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: () {
                        showStopTripDialog(
                          context: ctx,
                          vehicleNo: (data["vehicleNo"] ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._stopTripAndMoveToCompleted(
                              trip: data,
                              meterReading: meterReading,
                              fuelPercent: fuelPercent,
                              meterPhoto: meterPhoto,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // COMPLETED: keep your full details (ok)
                if (isCompleted) ...[
                  _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason", (data["reason"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["tripStartOdometer"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Meter", "${data["tripEndOdometer"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("Distance Traveled by Odometer", "${data["distanceKm"] ?? "-"} km"),
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