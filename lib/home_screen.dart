import 'package:flutter/material.dart';
import 'package:test_app/Leaves/dashbord_screen.dart';
import 'login_screen.dart';
import 'Leaves/top_banner.dart';

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
  @override
  void initState() {
    super.initState();

    // show banner AFTER first frame (HomeScreen already built)
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
    const blue = Color(0xFF0060A6);

    final name = widget.name;
    final user = widget.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Top Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hello, $name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Divider(
                thickness: 0.8,
                color: Color.fromARGB(255, 187, 187, 187),
              ),

              const SizedBox(height: 8),

              //Services Title
              const Text(
                "Services",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: blue,
                ),
              ),

              const SizedBox(height: 24),

              //Grid cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 1.35,
                children: [
                  _serviceCard(
                    imagePath: 'assets/leaves.png',
                    label: "Apply Leaves",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardScreen(user: user),
                        ),
                      );
                    },
                  ),
                  _serviceCard(
                    imagePath: 'assets/vehicle_request.png',
                    label: "Request Vehicle",
                    onTap: () {
                      debugPrint("Vehicle clicked");
                    },
                  ),
                  _serviceCard(
                    imagePath: 'assets/shift_shedule.png',
                    label: "Shift Schedule",
                    onTap: () {
                      debugPrint("Schedule clicked");
                    },
                  ),
                  const SizedBox.shrink(),
                ],
              ),

              const Spacer(),

              //Footer
              Row(
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
            ],
          ),
        ),
      ),
    );
  }

  //Service Card Widget
  Widget _serviceCard({
    required String imagePath,
    required String label,
    required VoidCallback onTap,
  }) {
    const blue = Color(0xFF0060A6);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
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
          border: Border.all(color: const Color.fromARGB(255, 165, 165, 165)),
          boxShadow: [
            BoxShadow(
              color: blue.withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
