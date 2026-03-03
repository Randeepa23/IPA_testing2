import 'package:flutter/material.dart';
import 'package:test_app/Services/vehicle_api_service.dart';
import 'dart:ui';
import '../users/vehicle_screen.dart';
import '../Vehicle/assigned_shuttle_trip_screen.dart';
import '../Vehicle/assigned_transfer_trip_screen.dart';

class VehicleHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const VehicleHomeScreen({super.key, required this.user});

  @override
  State<VehicleHomeScreen> createState() => _VehicleHomeScreenState();
}

class _VehicleHomeScreenState extends State<VehicleHomeScreen> {

    // For showing assigned trip counts on the home screen
    int shuttleAssignedCount = 0;
    int transferAssignedCount = 0;
    int officeBadgeCount = 0;
    bool officeBadgeHidden = false;
    bool firstLoad = true;

    @override
  void initState() {
    super.initState();
    _loadOfficeBadgeCount();
    _loadAssignedCounts();
  }

bool get isManager {
  final id = widget.user["jobTitleId"]?.toString() ?? "";
  return id == "3"; // example: HOD/Manager
}

    Future<void> _loadOfficeBadgeCount() async {
      try {
        final employeeId = widget.user["employeeId"]?.toString() ?? "";
        if (employeeId.isEmpty) return;

        // 1) employee side (my office pending)
        final myRes = await VehicleApiService.getMyTrips(employeeId: employeeId);
        final myList = List<Map<String, dynamic>>.from(myRes["data"] ?? []);

        final myOfficePending = myList.where((e) {
          final type = (e["reason"] ?? e["type"] ?? "").toString().toUpperCase().trim();
          final status = (e["status"] ?? "").toString().toUpperCase().trim();
          return type == "OFFICE" && status == "APPROVED";
        }).length;

        // 2) manager side
        int managerPending = 0;
        if (isManager) {
          final mgrList = await VehicleApiService.fetchManagerVehicleRequests(managerId: employeeId);
          managerPending = mgrList.where((e) {
            final status = (e["status"] ?? "").toString().toUpperCase().trim();
            return status == "PENDING";
          }).length;
        }

        if (!mounted) return;
        setState(() => officeBadgeCount = myOfficePending + managerPending);
      } catch (e) {
        if (!mounted) return;
        setState(() => officeBadgeCount = 0);
      }
    }

    Future<void> _loadAssignedCounts() async {
      try {
        final employeeId = widget.user["employeeId"]?.toString() ?? "";
        if (employeeId.isEmpty) return;

        final results = await Future.wait([
          VehicleApiService.fetchShuttleAssignedCount(employeeId: employeeId),
          VehicleApiService.fetchTransferAssignedCount(employeeId: employeeId),
        ]);

        if (!mounted) return;

        setState(() {
          shuttleAssignedCount = results[0];
          transferAssignedCount = results[1];
          firstLoad = false;

        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          shuttleAssignedCount = 0;
          transferAssignedCount = 0;
          firstLoad = false;
        });
      }
    }
    

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    return Scaffold(
  backgroundColor: Colors.white,
  body: SafeArea(
    child: RefreshIndicator(
      onRefresh: () async {
        setState(() => officeBadgeHidden = false);

        await Future.wait([
          _loadOfficeBadgeCount(),
          _loadAssignedCounts(),
        ]);
      },
      color: Colors.blue,
      backgroundColor: Colors.white,
      strokeWidth: 2,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopHeader(isTablet: isTablet, user: widget.user),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16,
              16,
              isTablet ? 24 : 16,
              24,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  const SizedBox(height: 6),

                  // Title card
                  const _InfoBanner(
                    title: "Vehicle Request System",
                    subtitle: "Choose a service to continue",
                    icon: Icons.directions_car_rounded,
                  ),

                  const SizedBox(height: 16),

                  _ServiceCard(
                    icon: Icons.apartment_rounded,
                    title: "Office",
                    subtitle: "Request a company vehicle for official use.\nRequires manager approval.",
                    chipText: "Approval required",
                    chipColor: const Color(0xFFFFF3CD),
                    chipTextColor: const Color(0xFF8A5A00),
                    primaryButtonText: "Request Vehicle",

                    badgeCount: officeBadgeHidden ? 0 : officeBadgeCount,

                    onPrimaryTap: () async {
                      // hide after open
                      setState(() => officeBadgeHidden = true);

                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VehicleScreen(user: widget.user)),
                      );

                      if (!mounted) return;
                      // do not reload here (only refresh will show again)
                    },
                  ),

                  const SizedBox(height: 14),

                  _ServiceCard(
                    icon: Icons.route_rounded,
                    title: "Shuttle",
                    subtitle:
                        "Regular office shuttle routes.\nVehicle and driver are auto-assigned.",
                    chipText: "Auto assigned",
                    chipColor: const Color(0xFFEAF1FF),
                    chipTextColor: const Color(0xFF1E5BB8),
                    primaryButtonText: "View Trips",
                    
                    // Show assigned trip count badge only after first load (to avoid showing '0' during loading)
                    badgeCount: shuttleAssignedCount,

                    onPrimaryTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignedShuttleTripScreen(user: widget.user),
                        ),
                      );
                      if (!mounted) return;
                      _loadAssignedCounts(); // refresh when coming back
                    },
                  ),

                  const SizedBox(height: 14),

                  _ServiceCard(
                    icon: Icons.place_rounded,
                    title: "Transfer",
                    subtitle:
                        "Point-to-point transport.\nVehicle and driver are auto-assigned.",
                    chipText: "Quick request",
                    chipColor: const Color(0xFFE8F8EE),
                    chipTextColor: const Color(0xFF1E7D47),
                    primaryButtonText: "View Trips",

                    // Show assigned trip count badge only after first load (to avoid showing '0' during loading)
                    badgeCount: transferAssignedCount,
                    
                    onPrimaryTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignedTransferTripScreen(user: widget.user),
                        ),
                      );
                      if (!mounted) return;
                      _loadAssignedCounts();
                    },
                  ),

                  const SizedBox(height: 50),
                  Row(
                    children: const [
                      Expanded(
                        child: Divider(color: Color(0xFF2563EB), thickness: 1),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Explore Holdings',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Color(0xFF2563EB), thickness: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

/// ---------- TOP HEADER ----------
class _TopHeader extends StatelessWidget {
  final bool isTablet;
  final Map<String, dynamic> user;
  const _TopHeader({required this.isTablet, required this.user});


  @override
  Widget build(BuildContext context) {
    final fullName = user["name"] ?? "";
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : "";
    //final lastName  = parts.length > 1 ? parts.last : "";
    return Padding(
      padding: EdgeInsets.fromLTRB(isTablet ? 24 : 16, 10, isTablet ? 24 : 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, $firstName !",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Select a service type to continue",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Back",
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ],
      ),
    );
  }
}

/// ---------- INFO BANNER ----------
class _InfoBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _InfoBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B7DE9),
            Color(0xFF3B82F6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- SERVICE CARD ----------
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  final String chipText;
  final Color chipColor;
  final Color chipTextColor;

  final String primaryButtonText;
  final VoidCallback onPrimaryTap;

  final int badgeCount;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chipText,
    required this.chipColor,
    required this.chipTextColor,
    required this.primaryButtonText,
    required this.onPrimaryTap,
    this.badgeCount = 0,
  });
  

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6ECF5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF1E88E5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _Chip(text: chipText, bg: chipColor, fg: chipTextColor),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF003580)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: onPrimaryTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          primaryButtonText,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        // BADGE (top-right)
        if (badgeCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                "$badgeCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ---------- CHIP ----------
class _Chip extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Chip({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10.8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
              
