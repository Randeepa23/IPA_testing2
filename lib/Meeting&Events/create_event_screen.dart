import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Constants/app_colors.dart';
import '../Services/api_service.dart';
import '../Services/meeting_and_event_service.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateEventScreen({super.key, required this.user});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController meetingLinkController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  String meetingType = "Meeting"; // Meeting | Event
  String locationType = "physical"; // physical | online
  bool isLoading = false;
  bool isLoadingMembers = false;

  List<Map<String, String>> allStaffMembers = [];
  final Set<String> selectedParticipantIds = {};
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  @override
  void initState() {
    super.initState();
    locationController.text = "Meeting Room";
    _loadStaffMembers();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    meetingLinkController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

  // 📅 Pick Date
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? startTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

Future<void> _loadStaffMembers() async {
  setState(() => isLoadingMembers = true);

  try {
    final res = await MeetingAndEventService.getAllStaff();

    if (res['success'] != true) {
      throw Exception("API failed");
    }

    final List members = res['members'] ?? [];

    final list = members
        .map<Map<String, String>>((e) {
          final item = Map<String, dynamic>.from(e);

          final id = (item["id"] ?? item["employee_id"] ?? "").toString();
          final name = (item["name"] ?? "Unknown").toString();
          final jobTitle = (item["job_title"] ?? "").toString();

          if (id.trim().isEmpty) return {};

          return {
            "id": id,
            "name": name,
            "job_title": jobTitle, // ✅ added
          };
        })
        .where((m) => m.isNotEmpty)
        .toList();

    if (!mounted) return;

      setState(() {
        _photoFutureCache.clear();
        allStaffMembers = list;
      });

  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to load staff members")),
    );
  } finally {
    if (mounted) {
      setState(() => isLoadingMembers = false);
    }
  }
}

  DateTime? _toDateTime(TimeOfDay? time) {
    if (selectedDate == null || time == null) return null;
    return DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      time.hour,
      time.minute,
    );
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  int? _resolveUserId() {
    // Primary expected key from login/user payload.
    final topLevel = _parseInt(widget.user["employee_id"]) ??
        _parseInt(widget.user["employeeId"]) ??
        _parseInt(widget.user["id"]) ??
        _parseInt(widget.user["emp_id"]) ??
        _parseInt(widget.user["user_id"]) ??
        _parseInt(widget.user["staff_id"]);
    if (topLevel != null) return topLevel;

    // Some APIs wrap user details in nested objects.
    final nestedCandidates = [
      widget.user["user"],
      widget.user["employee"],
      widget.user["data"],
      widget.user["profile"],
    ];

    for (final candidate in nestedCandidates) {
      if (candidate is Map) {
        final nested = Map<String, dynamic>.from(candidate);
        final nestedId = _parseInt(nested["employee_id"]) ??
            _parseInt(nested["employeeId"]) ??
            _parseInt(nested["id"]) ??
            _parseInt(nested["emp_id"]) ??
            _parseInt(nested["user_id"]) ??
            _parseInt(nested["staff_id"]);
        if (nestedId != null) return nestedId;
      }
    }

    return null;
  }

  String _computedDurationText() {
    final from = _toDateTime(startTime);
    final to = _toDateTime(endTime);
    if (from == null || to == null || !to.isAfter(from)) return "-";

    final diff = to.difference(from);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours > 0 && minutes > 0) return "${hours}h ${minutes}m";
    if (hours > 0) return "${hours}h";
    return "${minutes}m";
  }

  // 🚀 Submit Event
  Future<void> createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one participant")),
      );
      return;
    }

    final userId = _resolveUserId();
    if (userId == null) {
      debugPrint("CreateEventScreen user payload: ${widget.user}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Missing employee_id")),
      );
      return;
    }

    final from = _toDateTime(startTime);
    final to = _toDateTime(endTime);
    if (selectedDate == null || from == null || to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select date, start time and end time")),
      );
      return;
    }

    if (!to.isAfter(from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("End time must be after start time")),
      );
      return;
    }

    setState(() => isLoading = true);

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final String formattedStartTime =
        "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00";
    final String formattedEndTime =
        "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00";
    try {
      final response = await MeetingAndEventService.createMeeting(
        type: meetingType.toLowerCase(),
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        meetingDate: formattedDate,
        startTime: formattedStartTime,
        endTime: formattedEndTime,
        locationType: locationType,
        location: locationType == "physical"
            ? locationController.text.trim()
            : meetingLinkController.text.trim(),
        membersIds: selectedParticipantIds.toList(),
        createdBy: userId,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"] ?? "Event Created Successfully")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response["message"] ?? "Failed to create event")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create event: $e")),
      );
    }
  }

  // 🎨 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Meeting / Event type
              DropdownButtonFormField<String>(
                value: meetingType,
                decoration: const InputDecoration(labelText: "Title Type"),
                items: const [
                  DropdownMenuItem(value: "Meeting", child: Text("Meeting")),
                  DropdownMenuItem(value: "Event", child: Text("Event")),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => meetingType = v);
                },
              ),

              const SizedBox(height: 10),

              // Event title
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
                validator: (v) => v!.isEmpty ? "Enter title" : null,
              ),

              const SizedBox(height: 10),

              // Description
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),

              const SizedBox(height: 10),

              // Date
              ListTile(
                title: Text(selectedDate == null
                    ? "Select Date"
                    : DateFormat('yyyy-MM-dd').format(selectedDate!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickDate,
              ),

              // Time range
              ListTile(
                title: Text(
                  startTime == null ? "Select Start Time" : startTime!.format(context),
                ),
                trailing: const Icon(Icons.access_time),
                onTap: _pickStartTime,
              ),

              ListTile(
                title: Text(
                  endTime == null ? "Select End Time" : endTime!.format(context),
                ),
                trailing: const Icon(Icons.timelapse),
                onTap: _pickEndTime,
              ),

              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Duration",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _computedDurationText(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Location Type
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Physical"),
                      value: "physical",
                      groupValue: locationType,
                      onChanged: (value) {
                        setState(() {
                          locationType = value.toString();
                          locationController.text = "Meeting Room";
                          meetingLinkController.clear();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: const Text("Online"),
                      value: "online",
                      groupValue: locationType,
                      onChanged: (value) {
                        setState(() {
                          locationType = value.toString();
                          locationController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Location or Link
              if (locationType == "physical")
                TextFormField(
                  controller: locationController,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: "Location"),
                ),

              if (locationType == "online")
                TextFormField(
                  controller: meetingLinkController,
                  decoration: const InputDecoration(labelText: "Meeting Link"),
                  validator: (v) => v!.isEmpty ? "Enter meeting link" : null,
                ),

              const SizedBox(height: 15),

              // Participants
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Participants *",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(height: 8),
              if (isLoadingMembers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (allStaffMembers.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "No staff members available",
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: SizedBox(
                    height: 260,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        itemCount: allStaffMembers.length,
                        itemBuilder: (context, index) {
                          final member = allStaffMembers[index];
                          final memberId = member["id"]!;
                          final checked = selectedParticipantIds.contains(memberId);
                          final empId = int.tryParse(memberId) ?? 0;

                          return CheckboxListTile(
                            value: checked,
                            controlAffinity: ListTileControlAffinity.trailing,
                            activeColor: AppColors.primaryStart,
                            secondary: FutureBuilder<Map<String, dynamic>?>(
                              future: empId > 0
                                  ? _getPhotoFuture(empId)
                                  : Future.value(null),
                              builder: (context, snap) {
                                final url = (snap.data?["fileUrl"] ?? "")
                                    .toString()
                                    .trim();

                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFFEAF1FF),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.blue,
                                        backgroundColor: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }

                                if (url.isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEAF1FF),
                                    backgroundImage: NetworkImage(url),
                                  );
                                }

                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFEAF1FF),
                                  child: Icon(
                                    Icons.person,
                                    size: 18,
                                    color: Colors.black54,
                                  ),
                                );
                              },
                            ),
                            title: Text(
                              member["name"] ?? "",
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: (member["job_title"] ?? "").trim().isNotEmpty
                                ? Text(
                                    member["job_title"]!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedParticipantIds.add(memberId);
                                } else {
                                  selectedParticipantIds.remove(memberId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Button
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryStart, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isLoading ? null : createEvent,
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Create Event",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}