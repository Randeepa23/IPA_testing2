import 'package:flutter/material.dart';
import 'package:test_app/Leaves/dashbord_screen.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';
import 'vehicle_home_screen.dart';
import 'ui/dialogs/logout_dialog.dart';
import 'ui/dialogs/privacy_notice_dialog.dart';
import 'Reports/reports_screen.dart';
import '../QRCode/Vehicle_qr_screen.dart';
import '../users/biometric_enabled_screen.dart';
import 'Meeting&Events/dashbord_screen.dart';
import 'AirportParking/airport_parking_screen.dart';
import 'users/gate_pass_screen.dart';
import '../users/vehicle_screen.dart';
import '../users/personal_vehicle_screen.dart' as pvs;

class HomeScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic> user;
  final String name;
  final String? successMessage;

  const HomeScreen({
    Key? key,
    required this.name,
    required this.username,
    required this.user,
    this.successMessage,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const blue = Color(0xFF0060A6);
  bool _privacyNoticeShown = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  // Check the user is in the list of HR management
  bool get isHrManagement {
    final id = (widget.user["employeeId"] ?? widget.user["employeeId"])
            ?.toString() ??
        "";
    return ["26","11","14","24","25","19"]
        .contains(id);
  }

  // ── Airport Parking access ────────────────────────────────────────────────
  // Add or remove employee IDs here to control who can open the module.
  static const _airportParkingAllowedIds = ["26","11","14","19","24","29","52","61","80"];

  bool get isAirportParkingAllowed {
    final id =
        (widget.user["employeeId"] ?? widget.user["employee_id"] ?? widget.user["id"])
            ?.toString()
            .trim() ??
        "";
    return _airportParkingAllowedIds.contains(id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.successMessage;
      if (msg != null && msg.trim().isNotEmpty) {
        TopBanner.show(
          context,
          title: "Welcome",
          message: msg,
          icon: Icons.check_circle,
          rightButtonText: "OK",
        );
      }
      _showPrivacyNoticeAfterLogin();
    });
  }

  //Show privacy notice dialog after login
  Future<void> _showPrivacyNoticeAfterLogin() async {
    if (!mounted || _privacyNoticeShown) return;
    _privacyNoticeShown = true;

    // Small delay avoids clashing with welcome banner animation.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await showPrivacyNoticeDialog(context);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final user = widget.user;

    // services list (easy to add more)
    final rawServices = <_ServiceItem>[
      _ServiceItem(
        image: 'assets/456123.png',
        label: "Apply Leave",
        description: "Apply and track your leaves and personal vehicle requests",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/personal-vehicle.png',
        label: "Vehicle Request (Personal Use)",
        description: "Request personal vehicles for trips",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => pvs.VehicleScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/office-vehicle.png',
        label: "Vehicle Request (Office Use)",
        description: "Request company vehicles for official trips",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/123456.png',
        label: "Shuttle & Transfer Trip",
        description: "Track and manage your Shuttle and Transfer vehicle trips",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleHomeScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/gatepass.png',
        label: "Gate Pass",
        description: "Request and track visitor gate passes",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GatePassScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/qr.png',
        label: "Fuel QR Code",
        description: "Scan and manage fuel QR codes for vehicles",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleQrScreen(user: widget.user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/airportparking.png',
        label: "Airport Parking Customer Handling",
        description: "Reserve and manage airport parking slots",
        disabled: !isAirportParkingAllowed,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AirportParkingScreen(user: user),
            ),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/report.png',
        label: "Reports",
        description: "View and export HR and operational reports",
        disabled: !isHrManagement,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportsScreen(),
            ),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/meeting&event.png',
        label: "Meeting & Events",
        description: "Schedule and manage meetings and events",
        disabled: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeetingDashboardScreen(user: user)),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/setting.png',
        label: "Settings",
        description: "Manage your account and app preferences",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          );
        },
      ),
      _ServiceItem(
        image: 'assets/help.png',
        label: "Help",
        description: "Get assistance and user guide",
        disabled: false,
        onTap: () => showBottomMessage("Help is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/itSupport.png',
        label: "IT Support",
        description: "Raise and track IT support tickets",
        disabled: true,
        onTap: () => showBottomMessage("IT Support is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/project.png',
        label: "Project & Task",
        description: "Manage projects and assign team tasks",
        disabled: true,
        onTap: () => showBottomMessage("Project & Task is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/finance.png',
        label: "Finance & Accounting",
        description: "Track financial records and accounting",
        disabled: true,
        onTap: () => showBottomMessage("Finance & Accounting is coming soon 🚧"),
      ),
    ];
    final allServices = <_ServiceItem>[
      ...rawServices.where((s) => !s.disabled),
      ...rawServices.where((s) => s.disabled),
    ];
    final services = _searchQuery.isEmpty
        ? allServices
        : allServices.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.label.toLowerCase().contains(q) ||
                s.description.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.white,

      // footer fixed
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: const [
              Expanded(child: Divider(color: blue, thickness: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Explore Holdings',
                  style: TextStyle(
                    color: blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: blue, thickness: 1)),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hello, $name',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                color: const Color(0xFF000000)
                                    .withValues(alpha: 0.78),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const _GreetingEmoji(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined, color: Colors.black),
                    onPressed: _showLogoutConfirmationDialog,
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Divider(
                thickness: 0.8,
                color: Color.fromARGB(255, 187, 187, 187),
              ),

              const SizedBox(height: 8),

              const Text(
                "Services",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: blue,
                ),
              ),

              const SizedBox(height: 4),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: "Search services...",
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFAAB4C4)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8A97AD), size: 17),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 15, color: Color(0xFF8A97AD)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF4F7FC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE4EBF8)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: blue, width: 1.4),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFCCD5E0)),
                            const SizedBox(height: 10),
                            Text(
                              'No services found for "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF8A97AD)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: services.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final s = services[i];
                          return _serviceCard(
                            imagePath: s.image,
                            iconData: s.icon,
                            label: s.label,
                            description: s.description,
                            onTap: s.onTap,
                            isDisabled: s.disabled,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmationDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (_) => LogoutDialog(
        onLogout: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      ),
    );
  }

  void showBottomMessage(String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E63B5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            height: 70,
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _serviceCard({
    String? imagePath,
    IconData? iconData,
    required String label,
    String description = "",
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.40 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE4EBF8)),
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            width: 68,
                            height: 68,
                            fit: BoxFit.contain,
                          )
                        : iconData != null
                            ? Icon(iconData, size: 36, color: blue)
                            : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 16),
                // Label + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: blue,
                          height: 1.2,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8A97AD),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  isDisabled ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                  color: isDisabled ? const Color(0xFFB0BCCC) : const Color(0xFF8A97AD),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class _GreetingEmoji extends StatelessWidget {
  const _GreetingEmoji();

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final emoji = h < 12 ? '☀️' : h < 17 ? '🌤️' : '🌙';
    return Text(emoji, style: const TextStyle(fontSize: 13));
  }
}

// helper model
class _ServiceItem {
  final String? image;
  final IconData? icon;
  final String label;
  final String description;
  final bool disabled;
  final VoidCallback onTap;

  _ServiceItem({
    this.image,
    this.icon,
    required this.label,
    this.description = "",
    required this.disabled,
    required this.onTap,
  }) : assert(image != null || icon != null,
            'Provide either an image asset or an icon for the service.');
}
