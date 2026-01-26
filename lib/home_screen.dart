import 'package:flutter/material.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Top Row
             Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Hello, Explore',
      style: TextStyle(
        fontSize: 16,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    ),
    IconButton(
      icon: const Icon(
        Icons.logout_outlined,
        color: Colors.blue,
      ),
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
    ),
  ],
),


              const SizedBox(height: 50),

              // Fixed 3 Clickable Cards
              _menuCard(
                title: 'VEHICLE',
                onTap: () {
                  print('Vehicle clicked');
                },
              ),
              const SizedBox(height: 20),

              _menuCard(
                title: 'LEAVES',
                onTap: () {
                  print('Leaves clicked');
                },
                
              ),
              const SizedBox(height: 20),

              _menuCard(
                title: 'SCHEDULE',
                onTap: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
                print('Schedule clicked');
                },
              ),

              const Spacer(),

              // Footer
              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFF0060A6))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Explore Holdings',
                      style: TextStyle(
                        color: Color(0xFF0060A6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Color(0xFF0060A6))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Clickable Card Widget
  static Widget _menuCard({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0060A6),
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
