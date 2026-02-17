import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'leave_form.dart';
import '../users/user_screen.dart';
import 'leave_request_screen.dart';
import './../users/employees_screen.dart';
import 'package:test_app/Services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  Map<String, dynamic>? leaveBalance;
  bool loadingLeave = true;
  String? leaveError;

  // Recent leave requests from API (same source as leave_history_screen)
  List<Map<String, dynamic>> recentLeaves = [];
  bool loadingRecentLeaves = true;
  String? recentLeavesError;

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
    _loadRecentLeaves();
  }

  static const int _recentLeavesLimit = 10;

  Future<void> _loadRecentLeaves() async {
    try {
      setState(() {
        loadingRecentLeaves = true;
        recentLeavesError = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loadingRecentLeaves = false;
          recentLeavesError = "employeeId not found";
        });
        return;
      }

      final res = await ApiService.getLeaveHistory(employeeId: employeeId);

      if (res["success"] == true) {
        final list = List<Map<String, dynamic>>.from(res["data"] ?? []);
        final mapped = list.take(_recentLeavesLimit).map((x) {
          final statusStr = (x["status"] ?? "PENDING").toString().toUpperCase();
          String status;
          Color color;
          if (statusStr == "APPROVED") {
            status = "Approved";
            color = Colors.green;
          } else if (statusStr == "REJECTED") {
            status = "Rejected";
            color = Colors.red;
          } else {
            status = "Pending";
            color = Colors.orange;
          }
          final numDays = x["number_of_days"]?.toString() ?? "0";
          final days = numDays == "1" ? "1 day" : "$numDays days";
          return {
            "type": (x["leave_type"] ?? "-").toString(),
            "date": (x["leave_start_date"] ?? x["requested_at"] ?? "-").toString(),
            "days": days,
            "status": status,
            "color": color,
          };
        }).toList();

        setState(() {
          recentLeaves = mapped;
          loadingRecentLeaves = false;
        });
      } else {
        setState(() {
          loadingRecentLeaves = false;
          recentLeavesError = res["message"]?.toString() ?? "Failed to load recent requests";
        });
      }
    } catch (e) {
      setState(() {
        loadingRecentLeaves = false;
        recentLeavesError = e.toString();
      });
    }
  }

  

  /// Reloads both leave balance and recent leaves. Call this for pull-to-refresh or refresh button.
  Future<void> _reloadPage() async {
    await Future.wait([
      _loadLeaveBalance(),
      _loadRecentLeaves(),
    ]);
  }

  Future<void> _loadLeaveBalance() async {
    try {
      setState(() {
        loadingLeave = true;
        leaveError = null;
      });

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      if (employeeId.isEmpty) {
        setState(() {
          loadingLeave = false;
          leaveError = "employeeId not found in login user data";
        });
        return;
      }

      // Call API (you must implement ApiService.getLeaveBalance)
      final res = await ApiService.getLeaveBalance(employeeId: employeeId);

      if (res["success"] == true) {
        setState(() {
          leaveBalance = Map<String, dynamic>.from(res["data"] ?? {});
          loadingLeave = false;
        });
      } else {
        setState(() {
          loadingLeave = false;
          leaveError = res["message"]?.toString() ?? "Failed to load leave balance";
        });
      }
    } catch (e) {
      setState(() {
        loadingLeave = false;
        leaveError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user["firstName"] ?? "";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _reloadPage,
          color: Colors.blue,
          backgroundColor: Colors.white,
          strokeWidth: 2,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER (blue + blur + floating card) ALSO SCROLLS
              Stack(
                children: [
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
                            Row(
                              children: [
                                const Icon(Icons.notifications, color: Colors.white),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _reloadPage(),
                                  child: const Icon(Icons.refresh, color: Colors.white),
                                ),
                              ],
                            ),
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
                                        builder: (context) => UserScreen(user: widget.user),
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
                          'Welcome Back, $firstName !',
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

                        // Floating card from API
                        _leaveBalanceSection(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),

              // REST CONTENT
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

                    if (loadingRecentLeaves)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (recentLeavesError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Text(
                              recentLeavesError!,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadRecentLeaves,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else if (recentLeaves.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No recent requests',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        ),
                      )
                    else
                      ...recentLeaves.map(
                        (leave) => _leaveStatus(
                          leave['type'] as String,
                          leave['date'] as String,
                          leave['days'] as String,
                          leave['status'] as String,
                          leave['color'] as Color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // Handles loading/error/success for the balance card
  Widget _leaveBalanceSection() {
  
    if (loadingLeave) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (leaveError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Leave balance error: $leaveError",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadLeaveBalance,
            child: const Text("Retry"),
          ),
        ],
      );
    }

    if (leaveBalance == null || leaveBalance!.isEmpty) {
      return Text(
        "No leave balance data",
        style: GoogleFonts.poppins(color: Colors.white),
      );
    }

    return _leaveBalanceCard(leaveBalance!);
  }

  // Leave Balance Card
  Widget _leaveBalanceCard(Map<String, dynamic> balance) {

    // safe parse
    double d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;

    final annualRemaining = d(balance["annual_days"]);
    final sickRemaining = d(balance["sick_days"]);
    final casualRemaining = d(balance["casual_days"]);

    // If your API returns totals, use them. Otherwise fallback.
    final annualTotal = d(balance["annual_total"]) == 0 ? 20.0 : d(balance["annual_total"]);
    final sickTotal = d(balance["sick_total"]) == 0 ? 10.0 : d(balance["sick_total"]);
    final casualTotal = d(balance["casual_total"]) == 0 ? 5.0 : d(balance["casual_total"]);

    final annualUsed = (annualTotal - annualRemaining).clamp(0, annualTotal);
    final sickUsed = (sickTotal - sickRemaining).clamp(0, sickTotal);
    final casualUsed = (casualTotal - casualRemaining).clamp(0, casualTotal);

    return Card(
      //color: Colors.white,
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

            _progressRow('Annual Leave', annualUsed.toInt(), annualTotal.toInt()),
            _progressRow('Sick Leave', sickUsed.toInt(), sickTotal.toInt()),
            _progressRow('Casual Leave', casualUsed.toInt(), casualTotal.toInt()),
          ],
        ),
      ),
    );
  }

  // Color by usage: green (low) → blue (middle) → red (near total)
  Color _progressColor(double value) {
    final v = value.clamp(0.0, 1.0);
    if (v <= 0.5) {
      return Color.lerp(Colors.green, Colors.blue, v / 0.5)!;
    }
    return Color.lerp(Colors.blue, Colors.red, (v - 0.5) / 0.5)!;
  }

  Widget _progressRow(String type, int used, int total) {
    final safeTotal = total == 0 ? 1 : total;
    final value = used / safeTotal;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: GoogleFonts.poppins()),
              Text('$used/$total', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(_progressColor(value)),
            backgroundColor: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }

  // QUICK ACTIONS
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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LeaveFormScreen(user: widget.user)),
            );
            if (!mounted) return;
            // Refresh dashboard after applying leave
            _loadRecentLeaves();
            _loadLeaveBalance();
          },
        ),
        _QuickAction(
          icon: Icons.car_rental,
          label: 'Vehicle Request',
          onTap: () {
            print('Vehicle tapped');
          },
        ),
        _QuickAction(
          icon: Icons.person,
          label: 'Reliever Request',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmployeesScreen()),
            );
          },
        ),
        _QuickAction(
          icon: Icons.cabin,
          label: 'Request',
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LeaveRequestScreen()),
            );
            if (!mounted) return;
            // Refresh dashboard after any request screen actions
            _loadRecentLeaves();
            _loadLeaveBalance();
          },
        ),
      ],
    );
  }

 // Recent request card — simple, user-friendly
  Widget _leaveStatus(String type, String date, String days, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E2A3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$date  ·  $days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF6B7A90),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// Quick Action Widget

