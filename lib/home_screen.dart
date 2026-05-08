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
  /// Same pixel size for every service icon (inside a fixed box).
  static const double _kServiceImageSize = 75;
  static const double _kServiceLabelFontSize = 13.5;

  // Check the user is in the list of HR management
  bool get isHrManagement {
    final id = (widget.user["jobTitleId"] ?? widget.user["job_title_id"])
            ?.toString() ??
        "";
    return ["11", "14", "15", "16", "17", "18", "19","21", "20", "48"]
        .contains(id);
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
        label: "Leave & Personal \nVehicle Request",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
          );
        },
      ),
      // more services can be added here without changing the UI code
      _ServiceItem(
        image: 'assets/123456.png',
        label: "Vehicle Request",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VehicleHomeScreen(user: user)),
          );
        },
      ),
      // placeholder services (disabled with message)
      _ServiceItem(
        image: 'assets/qr.png',
        label: "Fuel QR Code",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) =>  VehicleQrScreen(user:widget.user)),
          );
        }
      ),
            // more placeholders can be added here without changing the UI code
      _ServiceItem(
        icon: Icons.local_parking_rounded,
        label: "Airport Parking",
        disabled: false,
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
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MeetingDashboardScreen(user: user)),
          );
        },
      ),
      // more placeholders can be added here without changing the UI code
      _ServiceItem(
        image: 'assets/setting.png',
        label: "Settings",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen()),
          );
        }
      ),
      _ServiceItem(
        image: 'assets/help.png',
        label: "Help",
        disabled: false,
        onTap: () => showBottomMessage("Help is coming soon 🚧"),
      ),

      // only one real service for now, but placeholders can be added easily
      _ServiceItem(
        image: 'assets/itSupport.png',
        label: "IT Support",
        disabled: true,
        onTap: () => showBottomMessage("IT Support is coming soon 🚧")
      ),
      // more placeholders can be added here without changing the UI code
      // _ServiceItem(
      //   image: 'assets/inventory.png',
      //   label: "Inventory Management",
      //   disabled: true,
      //   onTap: () => showBottomMessage("Inventory Management is coming soon 🚧"),
      // ),
      // more placeholders can be added here without changing the UI code
      _ServiceItem(
        image: 'assets/project.png',
        label: "Project & Task",
        disabled: true,
        onTap: () => showBottomMessage("Project & Task is coming soon 🚧"),
      ),
      // more placeholders can be added here without changing the UI code
      _ServiceItem(
        image: 'assets/finance.png',
        label: "Finance & Accounting",
        disabled: true,
        onTap: () => showBottomMessage("Finance & Accounting is coming soon 🚧"),
      ),
    ];
    final services = <_ServiceItem>[
      ...rawServices.where((s) => !s.disabled),
      ...rawServices.where((s) => s.disabled),
    ];

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
                        Text(
                          _greeting,
                          style: TextStyle(
                            color: const Color(0xFF000000)
                                .withOpacity(0.78),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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

              const SizedBox(height: 16),

              // Fixed 3×3 grid — same image size on every card
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: services.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, i) {
                    final s = services[i];
                    return _serviceCard(
                      imagePath: s.image,
                      iconData: s.icon,
                      label: s.label,
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
      barrierColor: Colors.black.withOpacity(0.15),
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
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color.fromARGB(255, 228, 228, 228)),
            boxShadow: [
              BoxShadow(
                color: blue.withOpacity(0.20),
                blurRadius: 3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Fixed slot so every asset draws at identical logical size
                SizedBox(
                  width: _kServiceImageSize + 12,
                  height: _kServiceImageSize + 12,
                  child: Center(
                    child: imagePath != null
                        ? Image.asset(
                            imagePath,
                            width: _kServiceImageSize,
                            height: _kServiceImageSize,
                            fit: BoxFit.contain,
                          )
                        : iconData != null
                            ? Icon(
                                iconData,
                                size: _kServiceImageSize - 8,
                                color: blue,
                              )
                            : const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: _kServiceLabelFontSize,
                    fontWeight: FontWeight.w800,
                    color: blue,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// helper model
class _ServiceItem {
  final String? image;
  final IconData? icon;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  _ServiceItem({
    this.image,
    this.icon,
    required this.label,
    required this.disabled,
    required this.onTap,
  }) : assert(image != null || icon != null,
            'Provide either an image asset or an icon for the service.');
}
