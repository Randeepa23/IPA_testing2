import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:test_app/Services/api_service.dart';
import 'dart:ui';

class LeaveFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const LeaveFormScreen({super.key, required this.user});

  @override
  _LeaveFormScreenState createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();
  final reasonController = TextEditingController();
  final addressController = TextEditingController();

  // Leave type
  String? selectedLeaveType;

  // Dates
  DateTime? fromDate;
  DateTime? toDate;

  // File (mock)
  String? attachedFileName;

  // Example leave types
  final leaveTypes = ['Annual Leave', 'Sick Leave', 'Casual Leave'];


  // ===== MASTER MEMBER DATA WITH AVAILABILITY =====
  final List<Map<String, dynamic>> allMembers = [
    {
      'id': 'M001',
      'name': 'John Doe',
      'availableFrom': DateTime(2026, 2, 1),
      'availableTo': DateTime(2026, 2, 10),
    },
    {
      'id': 'M002',
      'name': 'Jane Smith',
      'availableFrom': DateTime(2026, 1, 15),
      'availableTo': DateTime(2026, 1, 25),
    },
  ];

  //Filtered members
  List<Map<String, String>> availableMembers = [];

  String? selectedMember;
  bool noMemberConfirmed = false;

@override
void initState() {
  super.initState();
  debugPrint("FORM USER DATA: ${widget.user}");
  
  nameController.text = widget.user['name'] ?? '';
  employeeController.text = widget.user['employeeCode'] ?? '';
  departmentController.text = widget.user['department'] ?? '';
  contactController.text = widget.user['primaryContact'] ?? '';
}

Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  if (availableMembers.isNotEmpty && selectedMember == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select a team member')),
    );
    return;
  }

  if (availableMembers.isEmpty && !noMemberConfirmed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Confirmation required')),
    );
    return;
  }

  if (fromDate == null || toDate == null || selectedLeaveType == null) return;

  // ✅ map leave type name -> leave_policy_id
  final leavePolicyId = _leaveTypeToId(selectedLeaveType!);

  final start = DateFormat('yyyy-MM-dd').format(fromDate!);
  final end = DateFormat('yyyy-MM-dd').format(toDate!);
  final days = (toDate!.difference(fromDate!).inDays + 1).toDouble();

  try {
    final res = await ApiService.applyLeaveRequest(
      employeeId: widget.user["employeeId"],
      leavePolicyId: leavePolicyId,
      startDate: start,
      endDate: end,
      numberOfDays: days,
      reason: reasonController.text.trim(),
      overseeMemberId: selectedMember, // null allowed
      isSpecialRequest: noMemberConfirmed,
      address: addressController.text.trim(),
    );

    if (res["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Request submitted")),
      );
      Navigator.pop(context); // go back dashboard
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Failed")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}

int _leaveTypeToId(String type) {
  if (type == "Annual Leave") return 1;
  if (type == "Sick Leave") return 2;
  if (type == "Casual Leave") return 3;
  return 0;
}



void _showSubmitConfirmation() {
  final blue = Colors.blue[800] ?? Colors.blue;

  final leaveType = selectedLeaveType ?? "Leave";
  final fromTxt = fromDate == null ? "-" : DateFormat('yyyy-MM-dd').format(fromDate!);
  final toTxt = toDate == null ? "-" : DateFormat('yyyy-MM-dd').format(toDate!);
  final daysTxt = (fromDate != null && toDate != null)
      ? "${toDate!.difference(fromDate!).inDays + 1} days"
      : "-";

  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent, // important for blur
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(280.0, 420.0);

      return Stack(
        children: [
          // 🔹 BLUR BACKGROUND
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              color: Colors.black.withOpacity(0.15), // soft dim
            ),
          ),

          // 🔹 YOUR EXISTING DIALOG (UNCHANGED)
          Center(
            child: Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Apply Leave Request",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),
                      const Text(
                        "This action cannot be undone.",
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8EDF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leaveType,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$fromTxt to $toTxt",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7A90),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              daysTxt,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7A90),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        "Are you sure you want to submit this leave request?\nYour leave balance will be restored.",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Cancel"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _submitForm();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                "Send",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

  // ===== DATE RANGE FILTER LOGIC =====
  void _filterMembersByDate() {
    if (fromDate == null || toDate == null) return;

    setState(() {
      availableMembers = allMembers.where((member) {
        DateTime availableFrom = member['availableFrom'];
        DateTime availableTo = member['availableTo'];

        // DATE OVERLAP CHECK
        return !(toDate!.isBefore(availableFrom) ||
            fromDate!.isAfter(availableTo));
      }).map((m) => {
            'id': m['id'].toString(),
            'name': m['name'].toString(),
          }).toList();

      selectedMember = null;
      noMemberConfirmed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue[800] ?? Colors.blue;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
      backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Apply for leave',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- YOUR DETAILS ----------------
              _sectionTitle('Your Name'),
              const SizedBox(height: 8),
              _readonlyInput(value: nameController.text),

              const SizedBox(height: 12),
              _sectionTitle('Employee No.'),
              const SizedBox(height: 8),
              _readonlyInput(value: employeeController.text),

              const SizedBox(height: 12),
              _sectionTitle('Department'),
              const SizedBox(height: 8),
              _readonlyInput(value: departmentController.text),

              const SizedBox(height: 12),
              _sectionTitle('Contact No.'),
              const SizedBox(height: 8),
              _readonlyInput(value: contactController.text),

              const SizedBox(height: 16),

              // ---------------- LEAVE TYPE ----------------
              _sectionTitle('Leave Type *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedLeaveType,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                hint: const Text('Select leave type'),
                items: leaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => selectedLeaveType = v),
                validator: (v) => v == null ? 'Select leave type' : null,
              ),

              const SizedBox(height: 16),

              // ---------------- DATES (SIDE BY SIDE) ----------------
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('From date *'),
                        const SizedBox(height: 8),
                        _buildDatePicker('From date', fromDate, (date) {
                          fromDate = date;
                          _filterMembersByDate();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('To date *'),
                        const SizedBox(height: 8),
                        _buildDatePicker('To date', toDate, (date) {
                          toDate = date;
                          _filterMembersByDate();
                        }),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (fromDate != null && toDate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Days',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A)),
                      ),
                      Text(
                        '${toDate!.difference(fromDate!).inDays + 1} days',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E2A3A)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ---------------- REASON ----------------
              _sectionTitle('Reason for leave *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reason for leave...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // ---------------- TEAM MEMBER (RELIEVER) ----------------
              _sectionTitle('Select Team Member to Cover Your Duties *'),
              const SizedBox(height: 10),

              if (fromDate != null && toDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          availableMembers.isNotEmpty
                              ? 'Showing team availability for ${DateFormat('yyyy-MM-dd').format(fromDate!)} to ${DateFormat('yyyy-MM-dd').format(toDate!)}'
                              : 'Peak leave period detected - all members unavailable',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),

              // Available members list
              if (availableMembers.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(
                    children: availableMembers.map((m) {
                      return RadioListTile<String>(
                        dense: true,
                        title: Text(
                          m['name']!,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        value: m['id']!,
                        groupValue: selectedMember,
                        onChanged: (v) => setState(() => selectedMember = v),
                        activeColor: blue,
                      );
                    }).toList(),
                  ),
                )
              else if (fromDate != null && toDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E8F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Proceed without reliever team member (By HOD Approval)',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    subtitle: const Text(
                      'This request will be escalated to HR for special approval.',
                      style:
                          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                    value: noMemberConfirmed,
                    onChanged: (v) => setState(() => noMemberConfirmed = v!),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),

              const SizedBox(height: 16),

              // ---------------- ADDRESS ----------------
              _sectionTitle('Address While on Leave (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter address while on leave...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------- ATTACHMENT ----------------
              _sectionTitle('Attach Document (Optional)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    attachedFileName = 'document.pdf'; // mock
                  });
                },
                child: DottedBorder(
                  radius: const Radius.circular(12),
                  dashPattern: const [6, 4],
                  color: Colors.grey.shade400,
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file_outlined,
                            size: 34, color: Colors.black54),
                        const SizedBox(height: 8),
                        Text(
                          attachedFileName ?? 'Tap to upload document',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ---------------- SUBMIT ----------------
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _showSubmitConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'SUBMIT',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS (UI ONLY) ----------------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1E2A3A),
      ),
    );
  }

  Widget _readonlyInput({required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1E2A3A),
        ),
      ),
    );
  }

  // Keep your existing _buildDatePicker function (logic unchanged)
  Widget _buildDatePicker(
      String label, DateTime? selected, Function(DateTime) onSelect) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      controller: TextEditingController(
        text: selected == null ? '' : DateFormat('yyyy-MM-dd').format(selected),
      ),
      validator: (_) => selected == null ? 'Required' : null,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime(2030),
        );
        if (picked != null) onSelect(picked);
      },
    );
  }

  // ---------------- YOUR EXISTING LOGIC (UNCHANGED) ----------------

  // void _submitForm() {
  //   if (!_formKey.currentState!.validate()) return;

  //   if (availableMembers.isNotEmpty && selectedMember == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Select a team member')),
  //     );
  //     return;
  //   }

  //   if (availableMembers.isEmpty && !noMemberConfirmed) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Confirmation required')),
  //     );
  //     return;
  //   }

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Leave submitted successfully!')),
  //   );
  // }
}
