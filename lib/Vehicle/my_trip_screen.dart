import 'dart:io';
import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../ui/dialogs/cancel_trip_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Companion model
// ─────────────────────────────────────────────────────────────────────────────

class _TripCompanion {
  final int    id;
  final String name;
  const _TripCompanion({required this.id, required this.name});

  factory _TripCompanion.fromJson(Map<String, dynamic> j) => _TripCompanion(
        id:   int.tryParse((j['employee_id'] ?? '').toString()) ?? 0,
        name: (j['name'] ?? '').toString().trim(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MyTripsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTripsScreen({super.key, required this.user});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  int selectedTab = 0;
  bool loading = false;
  String? errorText;
  List<Map<String, dynamic>> trips = [];

  @override
  void initState() { super.initState(); _refreshTrips(); }

  String _employeeId() {
    final u = widget.user;
    final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
    return (v ?? "").toString().trim();
  }

  Future<void> _refreshTrips() async {
    try {
      setState(() { loading = true; errorText = null; });

      final empId = _employeeId();
      if (empId.isEmpty || empId == "0" || empId == "null") {
        throw Exception("employee_id missing in login data");
      }

      final res = await VehicleApiService.getMyTrips(employeeId: empId);
      if (res["success"] != true) throw Exception(res["message"] ?? "Failed to load trips");

      final data    = res["data"] ?? [];
      final rawList = List<Map<String, dynamic>>.from(data);

      final mapped = await Future.wait(rawList.map((e) async {
        final tripId     = (e["id"] ?? "").toString();
        String vehicleName = (e["vehicle_name"] ?? "").toString();

        try {
          final vd = await VehicleApiService.fetchVehicleDetails(
              transportServiceId: tripId);
          final make  = (vd["make"]  ?? "-").toString();
          final model = (vd["model"] ?? "-").toString();
          if (make != "-" || model != "-") vehicleName = "$make $model".trim();
        } catch (_) {}

        return {...e, "vehicleName": vehicleName};
      }));

      setState(() => trips = mapped);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredTrips() {
    final statusMap = ["PENDING", "APPROVED", "IN_PROGRESS", "COMPLETED"];
    return trips.where((t) => (t["status"] ?? "") == statusMap[selectedTab]).toList();
  }

  Future<bool?> _confirmCancelTrip() => showCancelTripDialog(context);

  Future<void> _startTripAndMoveToInProgress({
    required Map<String, dynamic> trip,
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
  }) async {
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.startTrip(
        transportServiceId: tripId,
        odometer:           int.parse(meterReading),
        fuelPercent:        double.parse(fuelPercent),
        photoFile:          meterPhoto,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 2);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "Trip Started",
            message: "Trip started successfully and moved to In Progress.",
            icon: Icons.check_circle, isSuccess: true);
      } else {
        throw Exception(res["message"] ?? "Start trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Start Trip Failed",
          message: e.toString(), icon: Icons.error_outline, isSuccess: false);
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
    final tripId = int.tryParse((trip["id"] ?? 0).toString()) ?? 0;
    if (tripId <= 0) return;
    try {
      setState(() => loading = true);
      final res = await VehicleApiService.stopTrip(
        transportServiceId: tripId,
        endOdometer:        int.parse(meterReading),
        endFuelPercent:     double.parse(fuelPercent),
        photoFile:          meterPhoto,
      );
      if (res["success"] == true) {
        if (!mounted) return;
        setState(() => selectedTab = 3);
        await _refreshTrips();
        if (!mounted) return;
        TopBanner.show(context,
            title: "Trip Completed", message: "Trip completed successfully.",
            icon: Icons.check_circle, isSuccess: true);
      } else {
        throw Exception(res["message"] ?? "Stop trip failed");
      }
    } catch (e) {
      if (!mounted) return;
      TopBanner.show(context, title: "Stop Trip Failed",
          message: e.toString(), icon: Icons.error_outline, isSuccess: false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cancelTrip(Map<String, dynamic> t) async {
    try {
      setState(() => loading = true);
      final id = (t["id"] ?? "").toString();
      if (id.isEmpty) throw Exception("Trip id missing");
      final res = await VehicleApiService.cancelTrip(id: id);
      if (res["success"] == true) {
        if (!mounted) return;
        TopBanner.show(context,
            title:   "Request Cancelled",
            message: "Your pending vehicle trip request has been cancelled.",
            icon:    Icons.cancel);
        await _refreshTrips();
      } else {
        throw Exception(res["message"] ?? "Cancel failed");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
                      onChanged:     (i) => setState(() => selectedTab = i),
                    ),
                  ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator(
                          color: Colors.blue, strokeWidth: 4)),
                    ),
                  if (!loading && filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                          child: Text("No trips found",
                              style: TextStyle(color: Colors.grey))),
                    ),
                ],
              );
            }

            final t = filtered[index - 1];

            // Parse companions from API response
            final rawCompanions = t["companions"] as List? ?? [];
            final companions    = rawCompanions
                .map((c) => _TripCompanion.fromJson(c as Map<String, dynamic>))
                .toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TripCard(
                data:       t,
                companions: companions,
                onCancel:   t["status"] == "PENDING"
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

// ─────────────────────────────────────────────────────────────────────────────
// Segmented tabs (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentTabs({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          _pill("Pending",     0),
          const SizedBox(width: 6),
          _pill("Approved",    1),
          const SizedBox(width: 6),
          _pill("In Progress", 2),
          const SizedBox(width: 6),
          _pill("Completed",   3),
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
            color: active ? const Color(0xFF0B5FA5) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10, offset: const Offset(0, 6))]
                : [],
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : const Color(0xFF334155))),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip Card
// ─────────────────────────────────────────────────────────────────────────────

class TripCard extends StatelessWidget {
  final Map<String, dynamic>  data;
  final List<_TripCompanion>  companions;
  final VoidCallback?         onCancel;

  const TripCard({
    super.key,
    required this.data,
    required this.companions,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status       = (data["status"] ?? "").toString();
    final isPending    = status == "PENDING";
    final isApproved   = status == "APPROVED";
    final isInProgress = status == "IN_PROGRESS";
    final isCompleted  = status == "COMPLETED";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [

          // ── Header ───────────────────────────────────────────────────────
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
                      Text((data["vehicleNo"] ?? "").toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF1E2A3A))),
                      const SizedBox(height: 2),
                      Text((data["vehicleName"] ?? "").toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                _statusPill(status),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [

                // PENDING
                if (isPending) ...[
                  _infoRow("Reason",      "Office Service"),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date",   (data["fromDate"]    ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date",     (data["toDate"]      ?? "").toString()),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  if (onCancel != null) ...[
                    const SizedBox(height: 12),
                    _gradientButton(text: "Cancel Request",
                        colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                        onTap: onCancel!),
                  ],
                ],

                // APPROVED
                if (isApproved) ...[
                  _infoRow("Trip Code",   (data["tripCode"]       ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason",      (data["reason"]         ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"]    ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("From Date",   (data["fromDate"]       ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("To Date",     (data["toDate"]         ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Approved By", (data["approvedByName"] ?? "").toString()),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      onTap: () {
                        showStartTripDialog(
                          context: ctx,
                          vehicleNo:   (data["vehicleNo"]   ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._startTripAndMoveToInProgress(
                              trip:         data,
                              meterReading: meterReading,
                              fuelPercent:  fuelPercent,
                              meterPhoto:   meterPhoto,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // IN_PROGRESS
                if (isInProgress) ...[
                  _infoRow("Trip Code",   (data["tripCode"]    ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason",      (data["reason"]      ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination", (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter", "${data["startMeter"] ?? "-"} km"),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],

                  const SizedBox(height: 12),
                  Builder(
                    builder: (ctx) => _gradientButton(
                      text:   "Stop Trip & Submit (Enter Meter Reading)",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: () {
                        showStopTripDialog(
                          context: ctx,
                          vehicleNo:   (data["vehicleNo"]   ?? "-").toString(),
                          destination: (data["destination"] ?? "-").toString(),
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            final state = ctx.findAncestorStateOfType<_MyTripsScreenState>();
                            await state?._stopTripAndMoveToCompleted(
                              trip:         data,
                              meterReading: meterReading,
                              fuelPercent:  fuelPercent,
                              meterPhoto:   meterPhoto,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],

                // COMPLETED
                if (isCompleted) ...[
                  _infoRow("Trip Code",    (data["tripCode"]    ?? "").toString(), highlight: true),
                  const SizedBox(height: 8),
                  _infoRow("Reason",       (data["reason"]      ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Destination",  (data["destination"] ?? "").toString()),
                  const SizedBox(height: 8),
                  _infoRow("Start Meter",  "${data["tripStartOdometer"] ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("End Meter",    "${data["tripEndOdometer"]   ?? "-"} km"),
                  const SizedBox(height: 8),
                  _infoRow("Distance",     "${data["distanceKm"]        ?? "-"} km"),

                  // Companions
                  if (companions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _companionsRow(context, companions),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Companions row — overlapping avatars + tap to see all ─────────────────
  Widget _companionsRow(BuildContext context, List<_TripCompanion> list) {
    return GestureDetector(
      onTap: () => _showCompanionsSheet(context, list),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F8FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE6F8)),
        ),
        child: Row(
          children: [
            SizedBox(
              height: 36,
              width: _avatarStackWidth(list.length),
              child: Stack(
                children: [
                  for (int i = 0; i < list.length.clamp(0, 3); i++)
                    Positioned(
                      left: i * 24.0,
                      child: _avatarCircle(list[i].name, i),
                    ),
                  if (list.length > 3)
                    Positioned(
                      left: 3 * 24.0,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: Center(
                          child: Text('+${list.length - 3}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF475569))),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                list.length == 1
                    ? list.first.name
                    : '${list.length} people going',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569)),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  // ── Companions bottom sheet ────────────────────────────────────────────────
  void _showCompanionsSheet(BuildContext context, List<_TripCompanion> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.group_outlined,
                    color: Color(0xFF1565C0), size: 20),
                const SizedBox(width: 8),
                Text('Going With (${list.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72, endIndent: 20),
            itemBuilder: (_, i) {
              final c        = list[i];
              final parts    = c.name.trim().split(' ')
                  .where((p) => p.isNotEmpty).toList();
              final initials = parts.length >= 2
                  ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
                  : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF1565C0),
                      child: Text(initials,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 14),
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A))),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _avatarStackWidth(int count) => (count.clamp(0, 4) * 24.0) + 12;

  Widget _avatarCircle(String name, int index) {
    const colors = [
      Color(0xFF1565C0), Color(0xFF2E7D32),
      Color(0xFF6A1B9A), Color(0xFFE65100),
    ];
    final parts    = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts[0][0].toUpperCase() : '?');
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: colors[index % colors.length],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }

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
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12),
                  blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.8)),
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final label = {
      "PENDING":     "Pending",
      "APPROVED":    "Approved",
      "IN_PROGRESS": "In-progress",
      "COMPLETED":   "Completed",
    }[status] ?? status;

    Color bg, border, text, iconColor;
    IconData icon;

    switch (status) {
      case "PENDING":
        bg = const Color(0xFFFFF3CD); border = const Color(0xFFFFE49A);
        text = const Color(0xFF8A6D3B); iconColor = const Color(0xFF8A6D3B);
        icon = Icons.hourglass_bottom; break;
      case "APPROVED":
        bg = const Color(0xFFE5E5E5); border = const Color(0xFFD3D3D3);
        text = const Color(0xFF7A7A7A); iconColor = const Color(0xFF7A7A7A);
        icon = Icons.check_circle; break;
      case "IN_PROGRESS":
        bg = const Color(0xFFE6E6E6); border = const Color(0xFFD0D0D0);
        text = const Color(0xFF7A7A7A); iconColor = const Color(0xFF7A7A7A);
        icon = Icons.schedule; break;
      default:
        bg = const Color(0xFFCDEED3); border = const Color(0xFF9AD7A6);
        text = const Color(0xFF2E7D32); iconColor = const Color(0xFF2E7D32);
        icon = Icons.verified;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w900, color: text)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}