import 'package:flutter/material.dart';
import '../Vehicle/vehicle_new_request_screen.dart';
import '../Vehicle/my_trip_screen.dart';
import '../Vehicle/vehicle_request_screen.dart';
class VehicleScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final int initialTab;

  const VehicleScreen({super.key, this.initialTab = 0, required this.user});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  late int selectedTab;
  int _tripsRefreshKey = 0;

  void _onRequestSubmitted() {
    setState(() {
      selectedTab = 1;
      _tripsRefreshKey++;
    });
  }

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
  }

  String getAppBarTitle() {
    switch (selectedTab) {
      case 0:
        return "New Request";
      case 1:
        return "My Trips";
      case 2:
        return "Requests";
      default:
        return "Vehicle";
    }
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
         title: Text(
        getAppBarTitle(),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    label: "New\nRequest",
                    icon: Icons.add_circle_outline,
                    isActive: selectedTab == 0,
                    onTap: () => setState(() => selectedTab = 0),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabButton(
                    label: "My Trips",
                    icon: Icons.directions_car_outlined,
                    isActive: selectedTab == 1,
                    onTap: () => setState(() => selectedTab = 1),
                    activeColor: blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tabButton(
                    label: "Requests",
                    icon: Icons.assignment_outlined,
                    isActive: selectedTab == 2,
                    onTap: () => setState(() => selectedTab = 2),
                    activeColor: blue,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: selectedTab,
              children: [
                VehicleRequestFormScreen(user: widget.user, onRequestSubmitted: _onRequestSubmitted),
                MyTripsScreen(key: ValueKey(_tripsRefreshKey), user: widget.user),
                VehicleRequestScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE1E6EF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.black87),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isActive ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}