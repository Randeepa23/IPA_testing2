import 'package:flutter/material.dart';
import 'package:test_app/Services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0;

  // Leave balance state
  Map<String, dynamic>? leaveBalance;
  bool loadingLeave = true;
  String? leaveError;

  @override
  void initState() {
    super.initState();
    _loadLeaveBalance();
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
          leaveError = "employeeId not found";
        });
        return;
      }

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
    final u = widget.user;
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            _profileCard(blue, widget.user),
            const SizedBox(height: 16),

            _sectionTitle('Contact Information'),
            const SizedBox(height: 10),

            _infoCard(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: (u["workEmail"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  value: (u["phone"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.apartment_outlined,
                  title: 'Department',
                  value: (u["department"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date of Birth',
                  value: (u["dateOfBirth"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: (u["workLocationName"] ?? "Seeduwa").toString(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Employment Details'),
            const SizedBox(height: 10),
            _infoCard(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  title: 'Reporting Manager',
                  value: (u["reportingManagerName"] ?? "-").toString(),
                ),
                const _DividerLine(),
                _InfoRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Join Date',
                  value: (u["dateOfJoining"] ?? "-").toString(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Leave Balance Summary'),
            const SizedBox(height: 10),

            // Dynamic Leave Balance Summary
            _buildLeaveBalanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalanceCard() {
    if (loadingLeave) {
      return _infoCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: const [
          Center(child: CircularProgressIndicator(
            color: Colors.blue,
            strokeWidth: 3,
          )),
        ],
      );
    }

    if (leaveError != null) {
      return _infoCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: [
          Text("Leave error: $leaveError"),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadLeaveBalance,
            child: const Text("Retry"),
          ),
        ],
      );
    }

    if (leaveBalance == null || leaveBalance!.isEmpty) {
      return _infoCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        children: const [
          Text("No leave data"),
        ],
      );
    }

    double d(dynamic v) => double.tryParse(v?.toString() ?? "0") ?? 0;

    final annualRemaining = d(leaveBalance!["annual_days"]);
    final sickRemaining = d(leaveBalance!["sick_days"]);
    final casualRemaining = d(leaveBalance!["casual_days"]);

    // Use totals from API if available; otherwise fallback
    final annualTotal = d(leaveBalance!["annual_total"]) == 0 ? 20.0 : d(leaveBalance!["annual_total"]);
    final sickTotal = d(leaveBalance!["sick_total"]) == 0 ? 10.0 : d(leaveBalance!["sick_total"]);
    final casualTotal = d(leaveBalance!["casual_total"]) == 0 ? 5.0 : d(leaveBalance!["casual_total"]);

    final annualUsed = (annualTotal - annualRemaining).clamp(0, annualTotal).toInt();
    final sickUsed = (sickTotal - sickRemaining).clamp(0, sickTotal).toInt();
    final casualUsed = (casualTotal - casualRemaining).clamp(0, casualTotal).toInt();

    return _infoCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      children: [
        _LeaveBar(title: 'Annual Leaves', used: annualUsed, total: annualTotal.toInt()),
        const SizedBox(height: 12),
        _LeaveBar(title: 'Medical Leaves', used: sickUsed, total: sickTotal.toInt()),
        const SizedBox(height: 12),
        _LeaveBar(title: 'Casual Leaves', used: casualUsed, total: casualTotal.toInt()),
      ],
    );
  }

  // ---------------- UI Widgets ----------------

  Widget _profileCard(Color blue, Map<String, dynamic> user) {
    final name = (user["name"] ?? "").toString();
    final department = (user["department"] ?? "").toString();
    final employeeCode = (user["employeeCode"] ?? "").toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [blue, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              image: const DecorationImage(
                image: AssetImage('assets/profile.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? "Unknown" : name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  department.isEmpty ? "No Department" : department,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "Employee Code: ${employeeCode.isEmpty ? "-" : employeeCode}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: Color(0xFF1E88E5)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2A3A),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(children: children),
    );
  }
}

// ---------------- SMALL WIDGETS ----------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7A90),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1E2A3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFEAEFF6)),
    );
  }
}

// Color by usage: green (low) → blue (middle) → red (near total)
Color _leaveProgressColor(double value) {
  final v = value.clamp(0.0, 1.0);
  if (v <= 0.5) {
    return Color.lerp(Colors.green, Colors.blue, v / 0.5)!;
  }
  return Color.lerp(Colors.blue, Colors.red, (v - 0.5) / 0.5)!;
}

class _LeaveBar extends StatelessWidget {
  final String title;
  final int used;
  final int total;

  const _LeaveBar({required this.title, required this.used, required this.total});

  @override
  Widget build(BuildContext context) {
    final remaining = total - used;
    final ratio = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2A3A),
                ),
              ),
            ),
            Text(
              '$used/$total',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(_leaveProgressColor(ratio)),
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Used: $used days   •   Remaining: $remaining days',
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF6B7A90),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
