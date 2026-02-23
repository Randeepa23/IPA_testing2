import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';

class MyTripsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTripsScreen({super.key, required this.user});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  int selectedTab = 0; // 0 Approved, 1 In Progress, 2 Completed
  bool loading = false;

  Future<void> _refreshTrips() async {
    setState(() => loading = true);

    // TODO: call your API here
    await Future.delayed(const Duration(seconds: 1)); // mock refresh

    // after fetching, update trips list (if dynamic)
    setState(() => loading = false);
  }


final trips = [
  {
    "status": "APPROVED",
    "vehicleNo": "VAN-9012",
    "vehicleName": "Nissan Caravan",
    "tripCode": "#0001AJITH",
    "destination": "Kandy",
    "reason": "Office Service",
    "approvedBy": "Kasun Silva",
    "fromDate": "01/22/2026",
    "toDate": "01/22/2026",
  },
  {
    "status": "IN_PROGRESS",
    "vehicleNo": "VAN-9012",
    "vehicleName": "Nissan Caravan",
    "tripCode": "#0002NAVO",
    "destination": "Kandy",
    "reason": "Tour Guide Assignment",
    "approvedBy": "Kasun Silva",
    "fromDate": "01/22/2026",
    "toDate": "01/22/2026",
    "startMeter": "32100", 
  },
  {
    "status": "COMPLETED",
    "vehicleNo": "VAN-9012",
    "vehicleName": "Nissan Caravan",
    "tripCode": "#0003INDU",
    "destination": "Kandy",
    "reason": "Tour Guide Assignment",
    "approvedBy": "Kasun Silva",
    "fromDate": "01/22/2026",
    "toDate": "01/22/2026",
    "startMeter": "32100",        
    "endMeter": "32200",          
    "odoDistance": "100",         
    "gpsDistance": "99",          
  },
];

  List<Map<String, dynamic>> _filteredTrips() {
    final s = (selectedTab == 0)
        ? "APPROVED"
        : (selectedTab == 1)
            ? "IN_PROGRESS"
            : "COMPLETED";

    return trips.where((t) => t["status"] == s).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
    body: RefreshIndicator(
    onRefresh: _refreshTrips,
    color: Colors.blue,
    backgroundColor: Colors.white,
    child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      itemCount: _filteredTrips().length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SegmentTabs(
              selectedIndex: selectedTab,
              onChanged: (i) => setState(() => selectedTab = i),
            ),
          );
        }

        final t = _filteredTrips()[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TripCard(
            data: t,
            onStartTrip: () {},
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
        //border: Border.all(color: const Color(0xFFE6ECF5)),
      ),
      child: Row(
        children: [
          _pill("Approved", 0),
          const SizedBox(width: 6),
          _pill("In Progress", 1),
          const SizedBox(width: 6),
          _pill("Completed", 2),
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
            color: active ? const Color(0xFF0B5FA5) : const Color.fromARGB(255, 250, 250, 250),
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
  final VoidCallback onStartTrip;

  const TripCard({super.key, required this.data, required this.onStartTrip});

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
          // top header
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
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
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

          // body details
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              children: [
               // ---------------- DETAILS SECTION ----------------
              _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
              const SizedBox(height: 8),

              _infoRow("Destination", (data["destination"] ?? "").toString()),
              const SizedBox(height: 8),

              _infoRow("Reason", (data["reason"] ?? "").toString()),

              // HIDE Approved By ONLY in COMPLETED
              if (!isCompleted) ...[
                const SizedBox(height: 8),
                _infoRow("Approved By", (data["approvedBy"] ?? "").toString()),
              ],

              // HIDE From / To Date ONLY in COMPLETED
              if (!isCompleted) ...[
                const SizedBox(height: 8),
                _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                const SizedBox(height: 8),
                _infoRow("To Date", (data["toDate"] ?? "").toString()),
              ],

              // ---------------- STATUS-BASED SECTION ----------------
              if (isApproved) ...[
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

              if (isInProgress) ...[
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
                          const SnackBar(content: Text("Trip started successfully")),
                        );
                      },
                    );
                  },
                ),
              ],

              if (isCompleted) ...[
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
          final label = status == "APPROVED"
              ? "Approved"
              : status == "IN_PROGRESS"
                  ? "In-progress"
                  : "Completed";

          Color bg;
          Color border;
          Color text;
          IconData icon;
          Color iconColor;

          if (status == "APPROVED") {
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