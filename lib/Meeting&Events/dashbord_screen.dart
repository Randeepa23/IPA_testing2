import 'package:flutter/material.dart';
import '../Constants/app_colors.dart';
import 'create_event_screen.dart';

class MeetingDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const MeetingDashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ongoingMeetings = <_MeetingItem>[
      const _MeetingItem(
        title: 'Daily Operations Sync',
        organizer: 'HR Team',
        time: '10:30 AM - 11:00 AM',
        location: 'Board Room - 2',
        participants: 8,
      ),
      const _MeetingItem(
        title: 'Mobile App QA Review',
        organizer: 'IT Support',
        time: '02:00 PM - 03:00 PM',
        location: 'Microsoft Teams',
        participants: 12,
      ),
    ];

    final scheduledMeetings = <_MeetingItem>[
      const _MeetingItem(
        title: 'Finance Budget Planning',
        organizer: 'Finance Department',
        time: 'Tomorrow, 09:45 AM',
        location: 'Conference Hall A',
        participants: 10,
      ),
      const _MeetingItem(
        title: 'Project Kickoff - ERP Phase 2',
        organizer: 'Project Management',
        time: 'Tue, 03:30 PM',
        location: 'Google Meet',
        participants: 16,
      ),
      const _MeetingItem(
        title: 'Quarterly Vendor Evaluation',
        organizer: 'Procurement Team',
        time: 'Wed, 11:15 AM',
        location: 'Meeting Room - 1',
        participants: 6,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 0,
        title: const Text('Meeting & Events'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              _createEventButton(context),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildSectionTitle(
                      title: 'Ongoing Meetings',
                      icon: Icons.play_circle_outline_rounded,
                    ),
                    const SizedBox(height: 10),
                    ...ongoingMeetings.map(
                      (meeting) => _meetingCard(
                        meeting: meeting,
                        stripeColor: const Color(0xFF2E7D32),
                        badgeText: 'LIVE',
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle(
                      title: 'Scheduled Meetings',
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(height: 10),
                    ...scheduledMeetings.map(
                      (meeting) => _meetingCard(
                        meeting: meeting,
                        stripeColor: const Color(0xFF1565C0),
                        badgeText: 'UPCOMING',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createEventButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryStart, AppColors.primaryEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryEnd.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CreateEventScreen(user: user)),
            );
          },
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text(
            'Create Event',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF163A70)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF163A70),
          ),
        ),
      ],
    );
  }

  Widget _meetingCard({
    required _MeetingItem meeting,
    required Color stripeColor,
    required String badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 118,
            decoration: BoxDecoration(
              color: stripeColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meeting.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stripeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: stripeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _metaRow(Icons.person_outline, 'Organizer: ${meeting.organizer}'),
                  const SizedBox(height: 4),
                  _metaRow(Icons.access_time_rounded, meeting.time),
                  const SizedBox(height: 4),
                  _metaRow(Icons.place_outlined, meeting.location),
                  const SizedBox(height: 4),
                  _metaRow(
                    Icons.groups_2_outlined,
                    '${meeting.participants} participants',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5E6A7D)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF4A5568),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeetingItem {
  final String title;
  final String organizer;
  final String time;
  final String location;
  final int participants;

  const _MeetingItem({
    required this.title,
    required this.organizer,
    required this.time,
    required this.location,
    required this.participants,
  });
}
