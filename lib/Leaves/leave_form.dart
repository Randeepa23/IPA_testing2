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
}
Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  if (availableMembers.isNotEmpty && selectedMember == null) {
    setState(() => _memberError = 'Please select a team member to cover your duties');
    return;
  }

  if (availableMembers.isEmpty && !noMemberConfirmed) {
    setState(() => _confirmError = 'Please confirm to proceed without a reliever');
    return;
  }

  if (fromDate == null || toDate == null || selectedLeaveType == null) return;

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
              // ---------------- YOUR DETAILS ----------------
              const FormSectionTitle('Your Name'),
              const SizedBox(height: 8),
              ReadonlyInfoField(value: nameController.text),

              const SizedBox(height: 12),
              const FormSectionTitle('Employee No.'),
              const SizedBox(height: 8),
              ReadonlyInfoField(value: employeeController.text),

              const SizedBox(height: 12),
              const FormSectionTitle('Department'),
              const SizedBox(height: 8),
              ReadonlyInfoField(value: departmentController.text),

              const SizedBox(height: 12),
              const FormSectionTitle('Contact No.'),
              const SizedBox(height: 8),
              ReadonlyInfoField(value: contactController.text),

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

                              // If half day: end date same as start date
                              if (isHalfDay) {
                                toDate = date;
                              }
                            });

                            // load relievers only when we have required dates
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

                const SizedBox(height: 10),
                if (fromDate != null && toDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Days',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        Text(
                          '${toDate!.difference(fromDate!).inDays + 1} days',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
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

              // Available members list
              if (availableMembers.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(
                    // Radio button on RIGHT, Photo on LEFT, Name in middle
                    children: availableMembers.map((m) {
                    final empId = int.tryParse(m["id"] ?? "") ?? 0;
                    return RadioListTile<String>(
                      value: m['id']!,
                      groupValue: selectedMember,
                      onChanged: (v) => setState(() { selectedMember = v; _memberError = null; }),
                     fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.blue; // selected radio color
                      }
                      return Colors.black54; // unselected radio color
                    }),

                      // radio button on RIGHT
                      controlAffinity: ListTileControlAffinity.trailing,

                      // Photo on LEFT
                      secondary: FutureBuilder<Map<String, dynamic>?>(
                        future: empId > 0 ? _getPhotoFuture(empId) : Future.value(null),
                        builder: (context, snap) {
                          final url = (snap.data?["fileUrl"] ?? "").toString().trim();

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
                                  strokeWidth: 2
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

                      // Name in middle
                      title: Text(
                        m['name']!,
                        style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800, 
                        color: Colors.black87
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
                  onChanged: (v) => setState(() { noMemberConfirmed = v!; _confirmError = null; }),

                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blue,
                ),
              ),

              // inline error: member not selected
              if (_memberError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _memberError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // inline error: confirmation not ticked
              if (_confirmError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _confirmError!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

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

  Widget _buildDatePicker(
      String hint, DateTime? selected, Function(DateTime) onSelect) {
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
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime(2030),
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
