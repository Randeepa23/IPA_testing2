import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'Leaves/dashbord_screen.dart';

class HomeScreen extends StatelessWidget {

  final String username;
  const HomeScreen({Key? key, required this.username}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0060A6);

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
                    'Hello, $username',
                    style: TextStyle(
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
              const Divider(thickness: 0.8, color: Color.fromARGB(255, 187, 187, 187)),

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

              //Grid cards (like screenshot)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 18,
                crossAxisSpacing: 18,
                childAspectRatio: 1.35, // card shape like screenshot
                children: [
                  _serviceCard(
                    imagePath: 'assets/leaves.png', //your image
                    label: "Apply Leaves",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) =>  DashboardScreen(username: username,)),
                      );
                    },
                  ),

                  _serviceCard(
                    imagePath: 'assets/vehicle_request.png', //your image
                    label: "Request Vehicle",
                    onTap: () {
                      print("Vehicle clicked");
                    },
                  ),
                  _serviceCard(
                    imagePath: 'assets/shift_shedule.png', //your image
                    label: "Shift Schedule",
                    onTap: () {
                      print("Schedule clicked");
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

              //Service Card Widget (matches screenshot style)
              Widget _serviceCard({
              required String imagePath, // 👈 image instead of icon
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
                      // IMAGE
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
