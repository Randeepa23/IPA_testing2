import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';

class MyTripsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const MyTripsScreen({super.key, required this.user});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  int selectedTab = 0; // 0 Approved, 1 In Progress, 2 Completed

  // Dummy data (replace with API)
  final trips = const [
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
    final list = _filteredTrips();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _SegmentTabs(
              selectedIndex: selectedTab,
              onChanged: (i) => setState(() => selectedTab = i),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final t = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TripCard(
                    data: t,
                    onStartTrip: () {
                      // TODO: open meter reading screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Start Trip clicked")),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
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
        border: Border.all(color: const Color(0xFFE6ECF5)),
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
            color: active ? const Color(0xFF0B5FA5) : Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final status = (data["status"] ?? "").toString();
    final isApproved = status == "APPROVED";

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
                _infoRow("Trip Code", (data["tripCode"] ?? "").toString(), highlight: true),
                const SizedBox(height: 8),
                _infoRow("Destination", (data["destination"] ?? "").toString()),
                const SizedBox(height: 8),
                _infoRow("Reason", (data["reason"] ?? "").toString()),
                const SizedBox(height: 8),
                _infoRow("Approved By", (data["approvedBy"] ?? "").toString()),
                const SizedBox(height: 8),
                _infoRow("From Date", (data["fromDate"] ?? "").toString()),
                const SizedBox(height: 8),
                _infoRow("To Date", (data["toDate"] ?? "").toString()),

               if (isApproved) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: InkWell(
                    onTap: () {
                      showStartTripDialog(
                        context: context,
                        vehicleNo: data["vehicleNo"],        // e.g. VAN-9012
                        destination: data["destination"],    // e.g. Kandy
                        isSubmitting: false,
                        onConfirm: ({
                          required meterReading,
                          required fuelPercent,
                          required meterPhoto,
                        }) async {
                          // 🔹 CALL API HERE LATER
                          // await ApiService.startTrip(
                          //   tripId: trip["trip_id"],
                          //   meter: meterReading,
                          //   fuel: fuelPercent,
                          //   photo: meterPhoto,
                          // );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Trip started successfully"),
                            ),
                          );
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1DB954), // light green
                            Color(0xFF0B7A34), // dark green
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Start Trip (Enter Meter Reading)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.8,
                        ),
                      ),
                    ),
                  ),
                ),
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
            ? "In Progress"
            : "Completed";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD3D3D3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF7A7A7A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7A7A7A),
            ),
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