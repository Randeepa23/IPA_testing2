import 'dart:math';
import 'package:flutter/material.dart';
import '../ui/dialogs/start_trip_dialog.dart';
import '../ui/dialogs/stop_trip_dialog.dart';

class AssignedTransferTripScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AssignedTransferTripScreen({super.key, required this.user});

  @override
  State<AssignedTransferTripScreen> createState() =>
      _AssignedTransferTripScreenState();
}

class _AssignedTransferTripScreenState extends State<AssignedTransferTripScreen> {
  int selectedTab = 0; // 0 Assigned, 1 Start Trip, 2 In Progress, 3 Completed
  bool loading = false;

    Future<void> _refreshTrips() async {
      setState(() => loading = true);
      await Future.delayed(const Duration(seconds: 1));
      setState(() => loading = false);
    }

    // Make it mutable (NOT final) because we update status + tripCode
    late List<Map<String, dynamic>> trips = [
      {
        "id": "REQ-001",
        "status": "ASSIGNED",
        "vehicleNo": "VAN-1234",
        "vehicleName": "Toyota KDH",
        "pickup": "Explore Vacations Office - Seeduwa",
        "dropoff": "Colombo Fort Railway Station",
        "passengers": "12 pax",
        "time": "08:00",
        "date": "01/22/2026",
        "tripCode": null, // generated later
      },
      {
        "id": "REQ-002",
        "status": "ASSIGNED",
        "vehicleNo": "VAN-7777",
        "vehicleName": "Toyota KDH",
        "pickup": "Negombo",
        "dropoff": "Colombo",
        "passengers": "8 pax",
        "time": "10:30",
        "date": "01/22/2026",
        "tripCode": null,
      },

      // This one already has code and waiting to start
      {
        "id": "REQ-003",
        "status": "START_TRIP",
        "vehicleNo": "VAN-9012",
        "vehicleName": "Nissan Caravan",
        "pickup": "Head Office",
        "dropoff": "Kandy",
        "passengers": "6 pax",
        "time": "11:00",
        "date": "01/22/2026",
        "tripCode": "#0001AJITH",
      },

      {
        "id": "REQ-004",
        "status": "IN_PROGRESS",
        "vehicleNo": "VAN-5555",
        "vehicleName": "Nissan Caravan",
        "pickup": "Seeduwa",
        "dropoff": "Kandy",
        "passengers": "10 pax",
        "time": "12:30",
        "date": "01/22/2026",
        "tripCode": "#0002NAVO",
        "startMeter": "32100",
      },

      {
        "id": "REQ-005",
        "status": "COMPLETED",
        "vehicleNo": "VAN-8888",
        "vehicleName": "Toyota KDH",
        "pickup": "Colombo",
        "dropoff": "Galle",
        "passengers": "7 pax",
        "time": "07:30",
        "date": "01/21/2026",
        "tripCode": "#0003INDU",
        "startMeter": "45000",
        "endMeter": "45200",
        "odoDistance": "200",
        "gpsDistance": "198",
      },
    ];

    List<Map<String, dynamic>> _filteredTrips() {
      final status = switch (selectedTab) {
        0 => "ASSIGNED",
        1 => "START_TRIP",
        2 => "IN_PROGRESS",
        _ => "COMPLETED",
      };

      return trips
          .where((t) => (t["status"] ?? "") == status)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    // Generate Trip Code ONLY for ASSIGNED and move to START_TRIP
    void _generateTripCodeAndMove(String id) {
      final idx = trips.indexWhere((e) => e["id"] == id);
      if (idx == -1) return;

      // Generate code like #1234ABCD (dummy)
      final rnd = Random();
      final numPart = (1000 + rnd.nextInt(9000)).toString();
      final letters = String.fromCharCodes(
        List.generate(4, (_) => 65 + rnd.nextInt(26)),
      );
      final code = "#$numPart$letters";

      setState(() {
        trips[idx]["tripCode"] = code;
        trips[idx]["status"] = "START_TRIP";
        selectedTab = 1; // jump to Start Trip tab (optional)
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trip Code Generated: $code")),
      );
    }

    @override
    Widget build(BuildContext context) {
      final list = _filteredTrips();

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text(
            "Assigned Transfer Trip",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: Colors.blue,
            backgroundColor: Colors.white,
            onRefresh: _refreshTrips,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              itemCount: list.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Header(user: widget.user),
                  );
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SegmentTabs(
                      selectedIndex: selectedTab,
                      onChanged: (i) => setState(() => selectedTab = i),
                    ),
                  );
                }

                final t = list[index - 2];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TripCard(
                    data: t,
                    onGenerateTripCode: () => _generateTripCodeAndMove(t["id"]),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
  }

  /// ------------------ Header ------------------
  class _Header extends StatelessWidget {
    final Map<String, dynamic> user;
    const _Header({required this.user});

    @override
    Widget build(BuildContext context) {
      final name = (user["name"] ?? "Nimal perera").toString();
      final role = (user["role"] ?? "Driver").toString();

      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Assigned Transfer Trip",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              "$name - $role",
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }
  }

  /// ------------------ Tabs ------------------
  class _SegmentTabs extends StatelessWidget {
    final int selectedIndex;
    final ValueChanged<int> onChanged;
    const _SegmentTabs({required this.selectedIndex, required this.onChanged});

    @override
    Widget build(BuildContext context) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip("Assigned", 0),
            const SizedBox(width: 8),
            _chip("Start Trip", 1),
            const SizedBox(width: 8),
            _chip("In Progress", 2),
            const SizedBox(width: 8),
            _chip("Completed", 3),
          ],
        ),
      );
    }

    Widget _chip(String text, int index) {
      final active = selectedIndex == index;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0B5FA5) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE6ECF5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(active ? 0.12 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      );
    }
  }

  /// ------------------ Trip Card ------------------
  class TripCard extends StatelessWidget {
    final Map<String, dynamic> data;
    final VoidCallback onGenerateTripCode;

    const TripCard({
      super.key,
      required this.data,
      required this.onGenerateTripCode,
    });

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
      final isAssigned = status == "ASSIGNED";
      final isStartTrip = status == "START_TRIP";
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Transfer Trip",
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 14)),
                        SizedBox(height: 2),
                        Text("Toyota KDH",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            )),
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

                  // ================= NON-COMPLETED =================
                  if (!isCompleted) ...[

                    // Shuttle ID only for Start / In Progress
                    if (isStartTrip || isInProgress) ...[
                      _infoRow(
                        "Transfer Code",
                        (data["tripCode"] ?? "-").toString(),
                        highlight: true,
                      ),
                      const SizedBox(height: 8),
                    ],

                    _infoRow("Pick up", (data["pickup"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Drop-off", (data["dropoff"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Vehicle No", (data["vehicleNo"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Passengers", (data["passengers"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Time", (data["time"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Date", (data["date"] ?? "-").toString()),
                  ],

                  // ================= COMPLETED =================
                  if (isCompleted) ...[
                    _infoRow("Pick up", (data["pickup"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Drop-off", (data["dropoff"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Vehicle No", (data["vehicleNo"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow("Date", (data["date"] ?? "-").toString()),
                    const SizedBox(height: 8),
                    _infoRow(
                      "Odometer Distance",
                      "${data["odoDistance"] ?? "-"} km",
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      "GPS Distance",
                      "${data["gpsDistance"] ?? "-"} km",
                    ),
                  ],

                  // ================= BUTTONS =================
                  if (isAssigned) ...[
                    const SizedBox(height: 12),
                    _gradientButton(
                      text: "Generate Trip Code",
                      colors: const [Color(0xFF0B5FA5), Color(0xFF084C8A)],
                      onTap: onGenerateTripCode,
                    ),
                  ],

                  if (isStartTrip) ...[
                    const SizedBox(height: 12),
                    _gradientButton(
                      text: "Start Trip (Enter Meter Reading)",
                      colors: const [Color(0xFF1DB954), Color(0xFF0B7A34)],
                      onTap: () {
                        showStartTripDialog(
                          context: context,
                          vehicleNo: data["vehicleNo"],
                          destination: data["dropoff"],
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Trip started")),
                            );
                          },
                        );
                      },
                    ),
                  ],

                  if (isInProgress) ...[
                    const SizedBox(height: 12),
                    _gradientButton(
                      text: "Stop Trip & Submit",
                      colors: const [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      onTap: () {
                        showStopTripDialog(
                          context: context,
                          vehicleNo: data["vehicleNo"],
                          destination: data["dropoff"],
                          isSubmitting: false,
                          onConfirm: ({
                            required meterReading,
                            required fuelPercent,
                            required meterPhoto,
                          }) async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Trip stopped")),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              )
            ),
          ],
        ),
      );
    }

    // Left-aligned values (not centered / not right)
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
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

      Widget _statusPill(String status) {
        final label = status == "ASSIGNED"
            ? "Assigned"
            : status == "START_TRIP"
                ? "Start Trip"
                : status == "IN_PROGRESS"
                    ? "In Progress"
                    : "Completed";

        Color bg;
        Color border;
        Color text;

        if (status == "ASSIGNED") {
          bg = const Color(0xFFE5E5E5);
          border = const Color(0xFFD3D3D3);
          text = const Color(0xFF7A7A7A);
        } else if (status == "START_TRIP") {
          bg = const Color(0xFFEAF2FF);
          border = const Color(0xFFBFD5FF);
          text = const Color(0xFF0B5FA5);
        } else if (status == "IN_PROGRESS") {
          bg = const Color(0xFFE6E6E6);
          border = const Color(0xFFD0D0D0);
          text = const Color(0xFF7A7A7A);
        } else {
          bg = const Color(0xFFCDEED3);
          border = const Color(0xFF9AD7A6);
          text = const Color(0xFF2E7D32);
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: text),
          ),
        );
      }
}