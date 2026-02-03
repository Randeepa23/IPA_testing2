import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'leave_form.dart';
import '../users/user_screen.dart';
import 'leave_request_screen.dart';
import 'dart:ui';


class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  //Dummy Recent Leave Data
  final List<Map<String, dynamic>> recentLeaves = const [
    {
      "type": "Annual Leave",
      "date": "20 Mar 2026",
      "days": "5 days",
      "status": "Approved",
      "color": Colors.green,
    },
    {
      "type": "Sick Leave",
      "date": "18 Mar 2026",
      "days": "2 days",
      "status": "Rejected",
      "color": Colors.red,
    },
    {
      "type": "Casual Leave",
      "date": "15 Mar 2026",
      "days": "1 day",
      "status": "Pending",
      "color": Colors.orange,
    },
        {
      "type": "Casual Leave",
      "date": "15 Mar 2026",
      "days": "1 day",
      "status": "Pending",
      "color": Colors.orange,
    },
        {
      "type": "Annual Leave",
      "date": "20 Mar 2026",
      "days": "5 days",
      "status": "Approved",
      "color": Colors.green,
    },
        {
      "type": "Casual Leave",
      "date": "15 Mar 2026",
      "days": "1 day",
      "status": "Pending",
      "color": Colors.orange,
    },
        {
      "type": "Annual Leave",
      "date": "20 Mar 2026",
      "days": "5 days",
      "status": "Approved",
      "color": Colors.green,
    },
  ];

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(top: false, bottom: false, child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ HEADER (blue + blur + floating card) ALSO SCROLLS
          Stack(
            children: [
              // BLUE BACKGROUND
              Container(
                width: double.infinity,
                height: 300,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Color.fromARGB(255, 51, 144, 219),
                      Color.fromARGB(255, 11, 63, 139),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
              ),

              //CONTENT INSIDE HEADER
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 16,
                  16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER ICONS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.notifications, color: Colors.white),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.logout_outlined, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UserScreen(),
                                  ),
                                );
                              },
                              child: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person, size: 16, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Welcome Back, Explore!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Apply your leaves...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Floating card
                    _leaveBalanceCard(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),

          //REST CONTENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Action',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _quickActions(context),

                const SizedBox(height: 20),

                Text(
                  'Recent Requests',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),

                ...recentLeaves.map(
                  (leave) => _leaveStatus(
                    leave['type'],
                    leave['date'],
                    leave['days'],
                    leave['status'],
                    leave['color'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  )
 );
}

  //Leave Balance Card
  Widget _leaveBalanceCard() {
    return Card(
      
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Balance Overview',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            _progressRow('Annual Leave', 12, 20),
            _progressRow('Sick Leave', 7, 10),
            _progressRow('Casual Leave', 3, 5),
          ],
        ),
      ),
    );
  }

  //Progress Row
  Widget _progressRow(String type, int used, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: GoogleFonts.poppins()),
              Text('$used/$total',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: used / total,
            minHeight: 8,
            color: Colors.blue,
            backgroundColor: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }

  //QUICK ACTIONS (2 ROWS × 2 COLUMNS)
Widget _quickActions(BuildContext context) {
  return GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 2.4,
    children: [
      _QuickAction(
        icon: Icons.add_circle,
        label: 'Apply Leave',
        onTap: () {
          // Navigate to your Leave Form Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveFormScreen()),
          );
        },
      ),
      _QuickAction(
        icon: Icons.car_rental,
        label: 'Vehicle Request',
        onTap: () {
          // Open request screen
          print('Vehicle tapped');
        },
      ),
      // _QuickAction(
      //   icon: Icons.history,
      //   label: 'History',
      //   onTap: () {
      //     // Show leave history
      //     print('History tapped');
      //   },
      // ),
      _QuickAction(
        icon: Icons.person,
        label: 'Reliever Request',
        onTap: () {
          // Open reliever info
          print('Reliever tapped');
        },
      ),
      _QuickAction(
        icon: Icons.cabin,
        label: 'Request',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveRequestScreen()),
          );
        },
      ),
    ],
  );
}


  //Leave Status Card
  Widget _leaveStatus(
    String type,
    String date,
    String days,
    String status,
    Color color,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(type, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        subtitle: Text('$date • $days',
            style: GoogleFonts.poppins(fontSize: 12)),
        trailing: Chip(
          label: Text(status),
          backgroundColor: color.withOpacity(0.2),
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }
}

//Quick Action Widget
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue, size: 28),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
