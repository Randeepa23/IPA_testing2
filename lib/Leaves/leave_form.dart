import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:test_app/Services/api_service.dart';
import 'dart:ui';
import 'dart:io';
import 'package:test_app/ui/dialogs/leave_submit_dialog.dart';
import 'package:test_app/ui/widgets/common_form_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'leave_history_screen.dart';
import 'top_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';



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
  File? attachedFile;
  String? attachedFileName;

  // Example leave types
  final leaveTypes = ['Annual Leave', 'Sick Leave', 'Casual Leave', 'Half Day'];

  bool isHalfDay = false;
  String? halfDaySession; // 'MORNING' or 'EVENING'


  //Filtered members
  List<Map<String, String>> availableMembers = [];

  String? selectedMember;
  bool noMemberConfirmed = false;

  // show loading on Send button
  bool _isSubmitting = false;

  // inline field errors for non-FormField widgets
  String? _memberError;
  String? _confirmError;

  // Approving manager
  List<Map<String, String>> _leaveManagers = [];
  String? _selectedManagerId;
  bool _loadingManagers = true;
  String? _managerError;

  // Manager employee IDs (fetched from server)
  List<String> _managerIds = [];

  // Cache for profile photo futures to avoid redundant API calls
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  // For picking profile photo in member list
  final ImagePicker _picker = ImagePicker();

  bool _isImageFile(String? name) {
  if (name == null) return false;

  final lower = name.toLowerCase();

  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp');
}

  // Check if the user is a manager, based on IDs fetched from the server
  bool get _isManager {
    final empId = (widget.user["employeeId"] ?? widget.user["employee_id"] ?? "")
        .toString().trim();
    return _managerIds.contains(empId);
  }



  // Same input style as login/forgot password - clear on all devices
  InputDecoration _inputDecoration(String hint, {IconData? icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade700) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.4),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFD32F2F),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.4),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFD32F2F),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    );
  }

  Widget _infoCell(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8A9BB0)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8A97AD),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E2A3A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

@override
void initState() {
  super.initState();
  debugPrint("FORM USER DATA: ${widget.user}");
  
  nameController.text = widget.user['name'] ?? '';
  employeeController.text = widget.user['employeeCode'] ?? '';
  departmentController.text = widget.user['department'] ?? '';
  contactController.text = widget.user['phone'] ?? '';

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _recoverLostData();
  });

  // Load manager IDs first — this drives _isManager check
  _loadManagerIds();
  _loadLeaveManagers();
}

Future<void> _loadManagerIds() async {
  final ids = await ApiService.getManagerIds();
  if (!mounted) return;
  setState(() {
    _managerIds = ids;
    // Auto-confirm no reliever if this user is a manager
    if (_isManager) {
      noMemberConfirmed = true;
    }
  });
}

Future<void> _loadLeaveManagers() async {
  try {
    setState(() { _loadingManagers = true; _managerError = null; });

    final empId = widget.user["employeeId"]?.toString()
        ?? widget.user["employee_id"]?.toString()
        ?? "";
    if (empId.isEmpty) throw Exception("employeeId missing");

    final res = await ApiService.getLeaveManagers(employeeId: empId);
    if (res["success"] != true) throw Exception(res["message"] ?? "Failed");

    final data       = res["data"] ?? {};
    final raw        = List.from(data["managers"] ?? []);
    // This is the single best available manager after fallback chain:
    // reporting manager → HR (10) → GM (14) → MD (11)
    final resolvedId = data["reporting_manager_id"]?.toString();

    final allManagers = raw.map<Map<String, String>>((e) => {
      "id":   e["id"].toString(),
      "name": (e["name"] ?? "").toString(),
    }).toList();

    // ── KEY: filter to show ONLY the resolved single manager ─────────────
    // Same as PersonalVehicleRequestScreen — employee sees one manager,
    // already resolved through the availability/fallback chain on the server.
    final displayList = allManagers
        .where((m) => m["id"].toString() == resolvedId)
        .toList();

    setState(() {
      _leaveManagers     = displayList;  // only 1 manager shown
      _selectedManagerId = resolvedId;   // auto-selected
      _loadingManagers   = false;
    });

  } catch (e) {
    setState(() {
      _loadingManagers = false;
      _managerError    = e.toString();
    });
  }
}

Future<void> _submitForm() async {

  if (!_formKey.currentState!.validate()) return;

  // Only validate reliever selection for non-managers
  if (!_isManager) {
    if (availableMembers.isNotEmpty && selectedMember == null) {
      setState(() => _memberError = 'Please select a team member to cover your duties');
      return;
    }
    if (availableMembers.isEmpty && !noMemberConfirmed) {
      setState(() => _confirmError = 'Please confirm to proceed without a reliever');
      return;
    }
  }

  if (fromDate == null || toDate == null || selectedLeaveType == null) return;

  // Enforce minimum days per leave type
  final totalDays = toDate!.difference(fromDate!).inDays + 1;
  final minDays = _minimumDays();
  if (totalDays < minDays) {
    TopBanner.show(
      context,
      title: 'Minimum Days Required',
      message: '$selectedLeaveType requires at least $minDays days. Please adjust your dates.',
      icon: Icons.warning_amber_rounded,
      rightButtonText: 'OK',
      onRightTap: () {},
    );
    return;
  }

  // map leave type name -> leave_policy_id
  final leavePolicyId = _leaveTypeToId(selectedLeaveType!);

  final start = DateFormat('yyyy-MM-dd').format(fromDate!);
  final end = DateFormat('yyyy-MM-dd').format(toDate!);
  final days = (toDate!.difference(fromDate!).inDays + 1).toDouble();

  try {
    setState(() {
      _isSubmitting = true;
    });

    final res = await ApiService.applyLeaveRequest(
      employeeId: widget.user["employeeId"].toString(),
      leavePolicyId: leavePolicyId,
      startDate: start,
      endDate: end,
      numberOfDays: days,
      reason: reasonController.text.trim(),
      overseeMemberId: selectedMember,
      isSpecialRequest: noMemberConfirmed,
      address: addressController.text.trim(),
      halfDaySession: isHalfDay ? halfDaySession : null,
      managerId: _selectedManagerId,
    );

      if (res["success"] == true) {

        // 1) Get new leave_request_id from response
        final int leaveRequestId = int.parse(res["leave_request_id"].toString());

        // 2) Upload document if user selected a file
        if (attachedFile != null) {
          try {
            await ApiService.uploadLeaveDocument(
              leaveRequestId: leaveRequestId,
              file: attachedFile!,
            );
          } catch (e) {
            // upload failed but leave request created
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Document upload failed: $e")),
            );
          }
        }

        //  3) show top banner
        TopBanner.show(
          context,
          title: "Request send successful..",
          message: "Your leave request has been submitted successfully.",
          icon: Icons.check_circle,
          leftButtonText: "View request",
          rightButtonText: "Ok",
          onLeftTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LeaveHistoryScreen(user: widget.user)),
            );
          },
          onRightTap: () {},
        );

        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 1000), () {});
      }
      else {
      // ERROR MESSAGE FROM PHP
      final msg = res["message"] ?? "Request failed";

            TopBanner.show(
              context,
              title: "Leave Request Failed",
              message: msg,
              icon: Icons.warning_amber_rounded,
              rightButtonText: "OK",
              onRightTap: () {},
              );
            }
          } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
            });
          }
        }
      }

int _leaveTypeToId(String type) {
  if (type == "Annual Leave") return 1;
  if (type == "Sick Leave") return 2;
  if (type == "Casual Leave") return 3;
  if (type == "Half Day") return 4;
  return 0;
}


  // Fetch profile photo with caching to optimize performance
  Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }


//Call the submit confirmation dialog
void _showSubmitConfirmation() {
  final leaveType = selectedLeaveType ?? "Leave";
  final fromTxt = fromDate == null ? "-" : DateFormat('yyyy-MM-dd').format(fromDate!);
  final toTxt = toDate == null ? "-" : DateFormat('yyyy-MM-dd').format(toDate!);
  final daysTxt = (fromDate != null && toDate != null)
      ? "${toDate!.difference(fromDate!).inDays + 1} days"
      : "-";

  showLeaveSubmitDialog(
    context: context,
    leaveType: leaveType,
    fromTxt: fromTxt,
    toTxt: toTxt,
    daysTxt: daysTxt,
    isSubmitting: _isSubmitting,
    onConfirm: _submitForm,
  );
}


  // ===== DATE RANGE FILTER LOGIC =====
    Future<void> _loadRelievers() async {

      // Managers don't need a reliever — skip loading
      if (_isManager) return;
      if (fromDate == null) return;

      // for half day: toDate = fromDate
      final effectiveTo = isHalfDay ? fromDate : toDate;
      if (effectiveTo == null) return;

      final employeeId = widget.user["employeeId"]?.toString() ?? "";
      final deptId = widget.user["departmentId"]?.toString() ?? "";
      if (employeeId.isEmpty || deptId.isEmpty) return;

      final from = DateFormat('yyyy-MM-dd').format(fromDate!);
      final to = DateFormat('yyyy-MM-dd').format(effectiveTo);

      try {
        final res = await ApiService.getRelievers(
          employeeId: employeeId,
          departmentId: deptId,
          fromDate: from,
          toDate: to,
        );

        if (res["success"] == true) {
          final list = List<Map<String, dynamic>>.from(res["members"] ?? []);

          // Clear photo cache to avoid showing wrong photos after date change
          _photoFutureCache.clear();

          setState(() {
            availableMembers = list
                .map((m) => {
                      "id": m["id"].toString(),
                      "name": m["name"].toString(),
                    })
                .toList();

            selectedMember = null;
            noMemberConfirmed = false;
          });
        } else {
          setState(() {
            availableMembers = [];
            selectedMember = null;
          });
        }
      } catch (e) {
        setState(() {
          availableMembers = [];
          selectedMember = null;
        });
      }
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
              // ── Employee info card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE5F8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        //const SizedBox(width: 8),
                        const Text(
                          'Your Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFDDE5F8)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell('Name', nameController.text, Icons.badge_outlined),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infoCell('Employee No.', employeeController.text, Icons.tag_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _infoCell('Department', departmentController.text, Icons.apartment_rounded),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _infoCell('Contact No.', contactController.text, Icons.phone_outlined),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------- LEAVE TYPE ----------------
              const FormSectionTitle('Leave Type *'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedLeaveType,
                dropdownColor: Colors.white,
                decoration: _dropdownDecoration(),
                hint: Text('Select leave type', style: TextStyle(color: Colors.grey.shade600)),
                items: leaveTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t,
                    style: const TextStyle(     // ITEM TEXT COLOR
                    color: Colors.black,
                    fontWeight: FontWeight.w600
                          ),
                          )
                        )
                        )
                    .toList(),
                onChanged: (v) {
                setState(() {
                  selectedLeaveType = v;

                  // check Half Day
                  isHalfDay = (v == "Half Day");

                  // reset right side field
                  toDate = null;
                  halfDaySession = null;
                });
              },

                validator: (v) => v == null ? 'Select leave type' : null,
              ),

              const SizedBox(height: 16),



              // ---------------- DATES (SIDE BY SIDE) ----------------
              if (isHalfDay) ...[
                const FormSectionTitle('Date *'),
                const SizedBox(height: 8),
                _buildDatePicker('Select date', fromDate, (date) {
                  setState(() {
                    fromDate = date;
                    toDate = date;
                  });
                  _loadRelievers();
                }),

                const SizedBox(height: 12),
                const FormSectionTitle('Half Day Session *'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: halfDaySession,
                  dropdownColor: Colors.white,
                  decoration: _dropdownDecoration(),
                  hint: Text('Select session', style: TextStyle(color: Colors.grey.shade600)),
                  items: const [
                    DropdownMenuItem(value: 'MORNING', child: Text('Morning',style: const TextStyle(color: Colors.black,fontWeight: FontWeight.w600))),
                    DropdownMenuItem(value: 'EVENING', child: Text('Evening',style: const TextStyle(color: Colors.black,fontWeight: FontWeight.w600))),
                  ],
                  onChanged: (v) => setState(() => halfDaySession = v),
                  validator: (v) => v == null ? 'Select session' : null,
                ),


                const SizedBox(height: 10),


                if (fromDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Days',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Half Day',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
              // ---------------- DATES (SIDE BY SIDE) ----------------
              Row(
                children: [
                  // LEFT: From date / Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FormSectionTitle(isHalfDay ? 'Date *' : 'From date *'),
                        const SizedBox(height: 8),
                        _buildDatePicker(
                          isHalfDay ? 'Select date' : 'From date',
                          fromDate,
                          (date) {
                            setState(() {
                              fromDate = date;
                              if (isHalfDay) {
                                toDate = date;
                              } else {
                                // reset toDate if it no longer meets the minimum
                                final min = _minToDate();
                                if (toDate != null &&
                                    min != null &&
                                    toDate!.isBefore(min)) {
                                  toDate = null;
                                }
                              }
                            });
                            _loadRelievers();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // RIGHT: To date OR Time (Morning/Evening)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FormSectionTitle(isHalfDay ? 'Time *' : 'To date *'),
                        const SizedBox(height: 8),

                        if (isHalfDay)
                          DropdownButtonFormField<String>(
                            value: halfDaySession,
                            dropdownColor: Colors.white,
                            decoration: _dropdownDecoration(),
                            hint: Text('Select time', style: TextStyle(color: Colors.grey.shade600)),
                            items: const [
                              DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                              DropdownMenuItem(value: 'EVENING', child: Text('Evening')),
                            ],
                            onChanged: (v) => setState(() => halfDaySession = v),
                            validator: (v) => v == null ? 'Select time' : null,
                          )
                        else
                          _buildDatePicker(
                            'To date',
                            toDate,
                            (date) {
                              setState(() => toDate = date);
                              _loadRelievers();
                            },
                            notBefore: _minToDate(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

                const SizedBox(height: 10),
                if (fromDate != null && toDate != null)
                  Builder(builder: (context) {
                    final days = toDate!.difference(fromDate!).inDays + 1;
                    final minDays = _minimumDays();
                    final belowMin = days < minDays;
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: belowMin
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFEAF1FF),
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
                                    color: Colors.black87),
                              ),
                              Text(
                                '$days days',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: belowMin
                                        ? const Color(0xFFD32F2F)
                                        : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        if (minDays > 1) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                belowMin
                                    ? Icons.error_outline
                                    : Icons.info_outline,
                                size: 13,
                                color: belowMin
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$selectedLeaveType requires a minimum of $minDays days.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: belowMin
                                      ? const Color(0xFFD32F2F)
                                      : const Color(0xFF1E2A3A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  }),
              ],

              const SizedBox(height: 16),

              // ---------------- REASON ----------------
              const FormSectionTitle('Reason for leave *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: 4,
                decoration: _inputDecoration('Enter reason for leave...'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 16),

              // ---------------- TEAM MEMBER (RELIEVER) ----------------
              if (_isManager) ...[
                // Managers see a simple info card instead of reliever selection
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBDD0F8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "No reliever required",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E2A3A),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "As a manager, your leave request will be sent directly to your reporting manager for approval.",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7A90),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Non-managers: show full reliever selection (existing UI unchanged)
                const FormSectionTitle('Select Team Member to Cover Your Duties *'),
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

                if (availableMembers.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE1E6EF)),
                    ),
                    child: Column(
                      children: availableMembers.map((m) {
                        final empId = int.tryParse(m["id"] ?? "") ?? 0;
                        return RadioListTile<String>(
                          value: m['id']!,
                          groupValue: selectedMember,
                          onChanged: (v) => setState(() {
                            selectedMember = v;
                            _memberError = null;
                          }),
                          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                            if (states.contains(MaterialState.selected)) return Colors.blue;
                            return Colors.black54;
                          }),
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: FutureBuilder<Map<String, dynamic>?>(
                            future: empId > 0 ? _getPhotoFuture(empId) : Future.value(null),
                            builder: (context, snap) {
                              final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFFEAF1FF),
                                  child: SizedBox(
                                    width: 14, height: 14,
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
                                child: Icon(Icons.person, size: 18, color: Colors.black54),
                              );
                            },
                          ),
                          title: Text(
                            m['name']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: const Text(
                        'This request will be escalated to HR for special approval.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      value: noMemberConfirmed,
                      onChanged: (v) => setState(() {
                        noMemberConfirmed = v!;
                        _confirmError = null;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.blue,
                    ),
                  ),

                if (_memberError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 14),
                        const SizedBox(width: 4),
                        Text(_memberError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),

                if (_confirmError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 14),
                        const SizedBox(width: 4),
                        Text(_confirmError!,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 16),


              // ---------------- ADDRESS ----------------
              const FormSectionTitle('Address While on Leave (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: addressController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: 2,
                decoration: _inputDecoration('Enter address while on leave...'),
              ),

              const SizedBox(height: 16),

              // ---------------- ATTACHMENT ----------------
              const FormSectionTitle('Attach Document (Optional)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickAttachment,
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
                    child: attachedFile != null && _isImageFile(attachedFileName)
                        ? Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                attachedFile!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Column(
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

              // ---------------- APPROVING MANAGER ----------------
              const SizedBox(height: 16),
              const FormSectionTitle('Approving Manager *'),
              const SizedBox(height: 8),

              if (_loadingManagers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
                  ),
                )
              else if (_managerError != null)
                Text(_managerError!, style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.w700))
              else if (_leaveManagers.isEmpty)
                const Text("No managers available", style: TextStyle(color: Colors.grey))
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(
                    children: _leaveManagers.map((m) {
                      final mId = (m["id"] ?? "").toString();
                      final eId = int.tryParse(mId) ?? 0;
                      return RadioListTile<String>(
                        value: mId,
                        groupValue: _selectedManagerId,
                        onChanged: (v) => setState(() => _selectedManagerId = v),
                        controlAffinity: ListTileControlAffinity.trailing,
                        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                          if (states.contains(MaterialState.selected)) {
                            return Colors.blue;
                          }
                          return Colors.black54;
                        }),
                        secondary: FutureBuilder<Map<String, dynamic>?>(
                          future: eId > 0 ? _getPhotoFuture(eId) : Future.value(null),
                          builder: (context, snap) {
                            final url = (snap.data?["fileUrl"] ?? "").toString().trim();
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFEAF1FF),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.blue, backgroundColor: Colors.white, strokeWidth: 2),
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
                              child: Icon(Icons.person, size: 18, color: Colors.black54),
                            );
                          },
                        ),
                        title: Text(
                          (m["name"] ?? "-"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),

              // ---------------- SUBMIT ----------------
              GradientSubmitButton(
                label: 'SUBMIT',
                isLoading: _isSubmitting,
                onPressed: _showSubmitConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }

            // ================== Document Picker Function ==================
            Future<void> _pickAttachment() async {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Take photo"),
              onTap: () async {
                Navigator.pop(context);

                final ok = await _ensureCameraPermission();
                if (!ok) {
                  _showMsg("Camera permission denied");
                  return;
                }

                try {
                  final XFile? x = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );

                  if (x == null) return;
                  if (!mounted) return;

                  setState(() {
                    attachedFile = File(x.path);
                    attachedFileName = x.name;
                  });
                } catch (e) {
                  _showMsg("Failed to open camera: $e");
                }
              },
            ),
                        ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from gallery"),
              onTap: () async {
                Navigator.pop(context);

                final ok = await _ensureGalleryPermission();
                if (!ok) {
                  _showMsg("Gallery permission denied");
                  return;
                }

                try {
                  final XFile? x = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );

                  if (x == null) return;
                  if (!mounted) return;

                  setState(() {
                    attachedFile = File(x.path);
                    attachedFileName = x.name;
                  });
                } catch (e) {
                  _showMsg("Failed to open gallery: $e");
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text("Choose document (PDF/DOC)"),
              onTap: () async {
                Navigator.pop(context);

                try {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
                    withData: true,
                  );

                  if (result == null || result.files.isEmpty) return;

                  final picked = result.files.single;

                  if (picked.path != null && picked.path!.isNotEmpty) {
                    setState(() {
                      attachedFile = File(picked.path!);
                      attachedFileName = picked.name;
                    });
                  } else if (picked.bytes != null) {
                    final tempDir = await getTemporaryDirectory();
                    final tempFile = File('${tempDir.path}/${picked.name}');
                    await tempFile.writeAsBytes(picked.bytes!);

                    setState(() {
                      attachedFile = tempFile;
                      attachedFileName = picked.name;
                    });
                  } else {
                    _showMsg("Unable to access selected file");
                  }
                } catch (e) {
                  _showMsg("Failed to pick file: $e");
                }
              },
            ),
            if (attachedFile != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Remove attachment"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    attachedFile = null;
                    attachedFileName = null;
                  });
                },
              ),
          ],
        ),
      );
    },
  );
}

  // Handle lost data (e.g. app killed while picking image)
  Future<void> _recoverLostData() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();

      if (response.isEmpty) return;

      if (response.files != null && response.files!.isNotEmpty) {
        final XFile file = response.files!.first;

        if (!mounted) return;
        setState(() {
          attachedFile = File(file.path);
          attachedFileName = file.name;
        });

        _showMsg("Recovered captured image");
        return;
      }

      if (response.file != null) {
        final XFile file = response.file!;

        if (!mounted) return;
        setState(() {
          attachedFile = File(file.path);
          attachedFileName = file.name;
        });

        _showMsg("Recovered captured image");
        return;
      }

      if (response.exception != null) {
        debugPrint("Lost data exception: ${response.exception}");
      }
    } catch (e) {
      debugPrint("retrieveLostData error: $e");
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<bool> _ensureGalleryPermission() async {
    if (await Permission.photos.isGranted || await Permission.storage.isGranted) {
      return true;
    }

    final photos = await Permission.photos.request();
    if (photos.isGranted || photos.isLimited) return true;

    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---------------- UI HELPERS (UI ONLY) ----------------

  /// Earliest selectable date — depends on leave type:
  /// Annual Leave → today (no past).
  /// Sick Leave   → today (no past; apply promptly after illness).
  /// Others       → 3 days in the past (retroactive casual/half-day).
  DateTime _leavePickerFirstDate() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (selectedLeaveType == 'Annual Leave' ||
        selectedLeaveType == 'Sick Leave') {
      return today;
    }
    return today.subtract(const Duration(days: 3));
  }

  /// Minimum allowed "To date" given [fromDate] and the current leave type.
  /// Annual Leave → fromDate + 2 days (≥ 3 days total).
  /// Sick Leave   → fromDate + 1 day  (≥ 2 days total).
  /// Others       → fromDate itself (no minimum beyond 1 day).
  DateTime? _minToDate() {
    if (fromDate == null) return null;
    if (selectedLeaveType == 'Annual Leave') {
      return fromDate!.add(const Duration(days: 2));
    }
    if (selectedLeaveType == 'Sick Leave') {
      return fromDate!.add(const Duration(days: 1));
    }
    return fromDate;
  }

  int _minimumDays() {
    if (selectedLeaveType == 'Annual Leave') return 3;
    if (selectedLeaveType == 'Sick Leave') return 2;
    return 1;
  }

  Widget _buildDatePicker(
    String hint,
    DateTime? selected,
    Function(DateTime) onSelect, {
    DateTime? notBefore,
  }) {
    return TextFormField(
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: _inputDecoration(
        hint,
        suffix: Icon(Icons.calendar_today, color: Colors.grey.shade700),
      ),
      controller: TextEditingController(
        text: selected == null ? '' : DateFormat('yyyy-MM-dd').format(selected),
      ),
      validator: (_) => selected == null ? 'Required' : null,
      onTap: () async {
        final today = DateUtils.dateOnly(DateTime.now());
        var firstDate = _leavePickerFirstDate();
        if (notBefore != null) {
          final nb = DateUtils.dateOnly(notBefore);
          if (nb.isAfter(firstDate)) firstDate = nb;
        }
        final lastDate = DateTime(2030);
        var initialDate = selected ?? today;
        if (initialDate.isBefore(firstDate)) initialDate = firstDate;
        if (initialDate.isAfter(lastDate)) initialDate = lastDate;

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1565C0),      // header & selected day
                onPrimary: Colors.white,          // text on header
                surface: Colors.white,            // calendar background
                onSurface: Color(0xFF1E2A3A),     // day numbers
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          ),
        );
        if (picked != null) onSelect(picked);
      },
    );
  }
}
