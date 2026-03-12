import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:test_app/Leaves/dashbord_screen.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';
import 'vehicle_home_screen.dart';
import 'ui/dialogs/logout_dialog.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final user = widget.user;

    // responsive sizes
    final screenW = MediaQuery.of(context).size.width;
    final iconSize = screenW < 360 ? 54.0 : 70.0;
    final fontSize = screenW < 360 ? 15.0 : 17.0;

    // services list (easy to add more)
    final services = <_ServiceItem>[
      _ServiceItem(
        image: 'assets/456123.png',
        label: "Apply Leaves",
        disabled: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
          );
        },
      ),
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
      _ServiceItem(
        image: 'assets/789123.png',
        label: "Shift Schedule",
        disabled: true,
        onTap: () => showBottomMessage("Shift Schedule is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/itSupport.png',
        label: "IT Support",
        disabled: false,
        onTap: () => showBottomMessage("Inventory Management is coming soon 🚧"),
        // onTap: () => Navigator.push(
        //   // context,
        //   // MaterialPageRoute(builder: (_) => const ImageTranslateScreen()),
        // ),
        
      ),
      _ServiceItem(
        image: 'assets/inventory.png',
        label: "Inventory Management",
        disabled: true,
        onTap: () => showBottomMessage("Inventory Management is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/meeting&event.png',
        label: "Meeting & Events",
        disabled: true,
        onTap: () => showBottomMessage("Meeting & Events is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/project.png',
        label: "Project & Task",
        disabled: true,
        onTap: () => showBottomMessage("Project & Task is coming soon 🚧"),
      ),
      _ServiceItem(
        image: 'assets/finance.png',
        label: "Finance & Accounting",
        disabled: true,
        onTap: () => showBottomMessage("Finance & Accounting is coming soon 🚧"),
      ),
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
                children: [
                  Text(
                    'Hello, $name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black54
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined, color: Colors.black54),
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

              // responsive grid (no overlap on small devices)
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: services.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190, // auto columns
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 1.15, // better height for small screens
                  ),
                  itemBuilder: (context, i) {
                    final s = services[i];
                    return _serviceCard(
                      imagePath: s.image,
                      label: s.label,
                      onTap: s.onTap,
                      isDisabled: s.disabled,
                      iconSize: iconSize,
                      fontSize: fontSize,
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

  // updated service card (responsive + no overflow)
  Widget _serviceCard({
    String? imagePath,
    required String label,
    required VoidCallback onTap,
    bool isDisabled = false,
    double iconSize = 70,
    double fontSize = 17,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isDisabled ? null : onTap, // block tap when disabled
      child: Opacity(
        opacity: isDisabled ? 0.65 : 1,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF5F9FF),
              ],
            ),
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imagePath != null)
                    Image.asset(
                      imagePath,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: blue,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// helper model
class _ServiceItem {
  final String image;
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  _ServiceItem({
    required this.image,
    required this.label,
    required this.disabled,
    required this.onTap,
  });
}