import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),

            _profileCard(blue),
            const SizedBox(height: 16),

            _sectionTitle('Contact Information'),
            const SizedBox(height: 10),
            _infoCard(
              children: const [
                _InfoRow(icon: Icons.email_outlined, title: 'Email', value: 'nimal.perera@explorevacationslk'),
                _DividerLine(),
                _InfoRow(icon: Icons.phone_outlined, title: 'Phone', value: '+94 776453668'),
                _DividerLine(),
                _InfoRow(icon: Icons.apartment_outlined, title: 'Department', value: 'Explore Vacation Sri Lanka'),
                _DividerLine(),
                _InfoRow(icon: Icons.location_on_outlined, title: 'Location', value: 'Seeduwa'),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Employment Details'),
            const SizedBox(height: 10),
            _infoCard(
              children: const [
                _InfoRow(icon: Icons.person_outline, title: 'Reporting Manager', value: 'Nimal Perera'),
                _DividerLine(),
                _InfoRow(icon: Icons.calendar_month_outlined, title: 'Join Date', value: '19/01/2026'),
              ],
            ),

            const SizedBox(height: 16),
            _sectionTitle('Leave Balance Summary'),
            const SizedBox(height: 10),
            _infoCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              children: const [
                _LeaveBar(title: 'Annual Leaves', used: 10, total: 20),
                SizedBox(height: 12),
                _LeaveBar(title: 'Casual Leaves', used: 3, total: 10),
                SizedBox(height: 12),
                _LeaveBar(title: 'Medical Leaves', used: 2, total: 5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(Color blue) {
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
          // Avatar (LEFT)
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.blue),
          ),
          const SizedBox(width: 12),

          // Name + Details (RIGHT)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Nimal Perera',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Senior Tour Coordinator',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                //SizedBox(height: 2),
                Text(
                  'Employee ID: EV2024001',
                  style: TextStyle(
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
              '$remaining/$total',
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
            backgroundColor: const Color(0xFFEAF1FF),
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
