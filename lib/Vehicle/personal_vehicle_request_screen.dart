import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
import '../Services/api_service.dart';
import '../ui/widgets/common_form_widgets.dart';
import 'package:http/http.dart' as http;


class PersonalVehicleRequestScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRequestSubmitted;

  const PersonalVehicleRequestScreen({super.key, required this.user, this.onRequestSubmitted});

  @override
  State<PersonalVehicleRequestScreen> createState() => _PersonalVehicleRequestScreenState();
}

// Google Places API Key  
const String googlePlacesKey = "AIzaSyAHmbwBrk0OKY0Nhp9FrR_zn8HKLGZ54OU";

class PlaceSuggestion {
  final String description;
  final String placeId;

  PlaceSuggestion({required this.description, required this.placeId});

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      description: json['description'],
      placeId: json['place_id'],
    );
  }
}

Future<List<PlaceSuggestion>> fetchPlaceSuggestions(String input) async {
  input = input.trim();
  if (input.isEmpty) return [];

  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/place/autocomplete/json",
    {
      "input": input,
      "key": googlePlacesKey,
      "components": "country:lk",
    },
  );

  final res = await http.get(uri);
  final body = res.body;
  final data = jsonDecode(body) as Map<String, dynamic>;

  final status = (data["status"] ?? "").toString();
  final err = (data["error_message"] ?? "").toString();

  debugPrint("Places status=$status code=${res.statusCode} err=$err");

  if (res.statusCode != 200) return [];
  if (status != "OK") return [];

  final preds = (data["predictions"] as List? ?? []);
  return preds
      .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
      .toList();
}

class _PersonalVehicleRequestScreenState extends State<PersonalVehicleRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Read-only user details
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();

  // Fields
  final destinationController = TextEditingController();

  // Vehicle no split
  final vehiclePrefixController = TextEditingController();
  final vehicleNumberController = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;

  String? vehicleError;
  String? vehicleTypeName;
  bool _isCheckingVehicle = false;
  int _checkGeneration = 0;

  // Manager
  List<Map<String, String>> managers = [];
  String? selectedManagerId;
  bool loadingManagers = true;
  String? managerError;
  String? reportingManagerId;

  bool _isSubmitting = false;

  int _previousRequestCount = 0;
  bool _loadingRequestCount = true;
  static const int _maxFocDaysPerRequest = 2;
  static const int _maxHalfOffDaysPerRequest = 3;

  int? vehicleId;

  // Photo cache for manager avatars
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  @override
  void initState() {
    super.initState();
    _loadManagers();
    _loadRequestCount();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['phone'] ?? '';
  }

  Future<void> _loadRequestCount() async {
    try {
      final employeeId = widget.user["employeeId"]?.toString() ?? "";

      final count = await VehicleApiService.getPersonalUsageCount(employeeId);

      if (!mounted) return;

      setState(() {
        _previousRequestCount = count;
        _loadingRequestCount = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingRequestCount = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load usage count: $e")),
      );
    }
  }

    Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
    return _photoFutureCache.putIfAbsent(
      employeeId,
      () => ApiService.getProfilePhoto(employeeId: employeeId),
    );
  }

Future<void> _loadManagers() async {
  try {
    setState(() {
      loadingManagers = true;
      managerError = null;
    });

    final empId = widget.user["employee_id"]?.toString()
        ?? widget.user["employeeId"]?.toString()
        ?? "";

    if (empId.isEmpty) throw Exception("employee_id missing in login data");

    final res = await VehicleApiService.getDefaultManagers(employeeId: int.parse(empId));

    if (res["success"] != true) {
      throw Exception(res["message"] ?? "API failed");
    }

    final data = res["data"] ?? {};
    final raw = List.from(data["managers"] ?? []);
    final reportingId = data["reporting_manager_id"]?.toString();
    reportingManagerId = widget.user["reportingManagerId"]?.toString();

    final list = raw.map<Map<String, String>>((e) {
      return {
        "id": e["id"].toString(),
        "name": (e["name"] ?? "").toString(),
      };
    }).toList();

    // DEBUG (check in console)
    print("Managers loaded: $list");
    print("Reporting manager: $reportingId");

    String? defaultId;

    if (reportingId != null && list.any((m) => m["id"] == reportingId)) {
      defaultId = reportingId;
    } else if (list.isNotEmpty) {
      defaultId = list.first["id"];
    }

    setState(() {
      managers = list;
      selectedManagerId = defaultId;
      loadingManagers = false;
    });
  } catch (e) {
    setState(() {
      loadingManagers = false;
      managerError = e.toString();
      managers = [];
      selectedManagerId = null;
    });
  }
}

Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;
  if (fromDate == null || toDate == null) return;

  final attempt = _previousRequestCount + 1;
  final isFreeAttempt = attempt <= 2;
  final isHalfOffAttempt = attempt >= 3 && attempt <= 5;
  final requestedDays = toDate!.difference(fromDate!).inDays + 1;
  if (isFreeAttempt && requestedDays > _maxFocDaysPerRequest) {
     TopBanner.show(
            context,
            title: "Request Failed",
            message: "Free requests are limited to maximum 2 days per request.",
            icon: Icons.error,
            isSuccess: false,
        );
    return;
  }
  if (isHalfOffAttempt && requestedDays > _maxHalfOffDaysPerRequest) {
     TopBanner.show(
            context,
            title: "Request Failed",
            message: "50% off requests are limited to maximum 3 days per request.",
            icon: Icons.error,
            isSuccess: false,
        );
    return;
  }

  if (_isCheckingVehicle) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please wait for vehicle validation to complete.")),
    );
    return;
  }
  if (vehicleError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(vehicleError!)),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    String _employeeIdFromUser() {
      final u = widget.user;
      final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
      return (v ?? "").toString().trim();
    }
    final empId = _employeeIdFromUser();
    final managerId = selectedManagerId!;
    final employeeName = nameController.text.trim();
    final employeePhone = contactController.text.trim();

    final vehicleNo =
        "${vehiclePrefixController.text.trim()}-${vehicleNumberController.text.trim()}";

    final fromDateTxt = DateFormat("yyyy-MM-dd").format(fromDate!);
    final toDateTxt = DateFormat("yyyy-MM-dd").format(toDate!);

    final vehicleType = vehicleTypeName ?? "-"; // fallback

    debugPrint("[SubmitForm] ── Payload ──────────────────────");
    debugPrint("[SubmitForm] employeeId  : $empId");
    debugPrint("[SubmitForm] managerId   : $managerId");
    debugPrint("[SubmitForm] vehicleNo   : $vehicleNo");
    debugPrint("[SubmitForm] vehicleType : $vehicleType");
    debugPrint("[SubmitForm] vehicleId   : $vehicleId");
    debugPrint("[SubmitForm] fromDate    : $fromDateTxt");
    debugPrint("[SubmitForm] toDate      : $toDateTxt");
    debugPrint("[SubmitForm] ────────────────────────────────");

    final res = await VehicleApiService.createPersonalVehicleRequest(
      employeeId: empId,
      managerId: managerId,
      vehicleNo: vehicleNo,
      fromDate: fromDateTxt,
      toDate: toDateTxt,
      //destination: destinationController.text.trim(),
      contactNo: employeePhone,
      employeeName: employeeName,
      reason: "Personal Request",
      vehicleType: vehicleType,  // ← new optional param
      vehicleId: vehicleId, // <-- pass the ID here

      
    );
    print("Vehicle Type Name: $vehicleType");

    if (res["success"] == true) {
          if (!mounted) return;

          TopBanner.show(
            context,
            title: "Request Submitted",
            message: "Your vehicle request has been submitted successfully.",
            icon: Icons.check_circle,
            isSuccess: true,
      );
      if (widget.onRequestSubmitted != null) {
        widget.onRequestSubmitted!();
      } else {
        Navigator.pop(context);
      }
    } else {
      throw Exception(res["message"] ?? "Submission failed");
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}
void _showVehicleSubmitConfirmation() {

  final vehicleNoTxt =
      "${vehiclePrefixController.text.trim()}-${vehicleNumberController.text.trim()}";

  final fromTxt = fromDate == null ? "-" : DateFormat('MM/dd/yyyy').format(fromDate!);
  final toTxt = toDate == null ? "-" : DateFormat('MM/dd/yyyy').format(toDate!);

  final destinationTxt = destinationController.text.trim().isEmpty
      ? "-"
      : destinationController.text.trim();

  showVehicleSubmitDialog(
    context: context,
    vehicleNoTxt: vehicleNoTxt,
    fromTxt: fromTxt,
    toTxt: toTxt,
    destinationTxt: destinationTxt,
    isSubmitting: _isSubmitting,
    onConfirm: _submitForm,
  );
}

    // Call this after vehicle no or dates change
    void checkVehicle() {
      final prefix = vehiclePrefixController.text.trim();
      final number = vehicleNumberController.text.trim();

      if (prefix.length < 2 || number.length < 4 ||
          fromDate == null || toDate == null) {
        setState(() {
          vehicleError = null;
          vehicleTypeName = null;
          vehicleId = null;
          _isCheckingVehicle = false;
        });
        return;
      }

      final gen = ++_checkGeneration;

      setState(() {
        _isCheckingVehicle = true;
        vehicleError = null;
        vehicleTypeName = null;
        vehicleId = null;
      });

      () async {
        try {
          final vehicleNo = "$prefix-$number";
          final start = "${fromDate!.toString().split(' ')[0]} 00:00:00";
          final end = "${toDate!.toString().split(' ')[0]} 23:59:59";

          final response = await http.post(
            Uri.parse(
                "https://exploredrive.lk/api/transport-services/validate-vehicle"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "vehicle_no": vehicleNo,
              "assigned_start_at": start,
              "vehicle_type_name": null,
              "assigned_end_at": end,
              "transport_service_id": null,
            }),
          );

          if (gen != _checkGeneration) return; // stale

          Map<String, dynamic> data;
          try {
            data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
          } catch (_) {
            setState(() {
              vehicleError = "Server error (${response.statusCode}). Please try again.";
              _isCheckingVehicle = false;
            });
            return;
          }

          // Dump full response to find exact field names
          debugPrint("[CheckVehicle] FULL RESPONSE: $data");
          debugPrint("[CheckVehicle] vehicle object: ${data["vehicle"]}");
          debugPrint("[CheckVehicle] vehicle keys: ${(data["vehicle"] as Map?)?.keys.toList()}");

          final typeName = data["vehicle"]?["vehicle_type_name"]?.toString();

          // Try every common key name the API might use for vehicle ID
          final rawId = data["vehicle"]?["id"]
              ?? data["vehicle"]?["vehicle_id"]
              ?? data["vehicle"]?["vehicleId"]
              ?? data["id"]
              ?? data["vehicle_id"];


          if (data["ok"] == false) {
            debugPrint("[CheckVehicle] NOT OK — ${data["message"]}");
            setState(() {
              vehicleTypeName = typeName;
              vehicleError = data["message"]?.toString();
              vehicleId = null;
              _isCheckingVehicle = false;
            });
            return;
          }

          final resolvedId = rawId != null ? int.tryParse(rawId.toString()) : null;
          debugPrint("[CheckVehicle] OK — vehicleId=$resolvedId  typeName=$typeName");

          setState(() {
            vehicleTypeName = typeName;
            vehicleError = null;
            vehicleId = resolvedId;
            _isCheckingVehicle = false;
          });
        } catch (e) {
          debugPrint("[CheckVehicle] EXCEPTION: $e");
          if (gen != _checkGeneration) return;
          setState(() {
            vehicleError = "Could not validate vehicle. Check your connection and try again.";
            _isCheckingVehicle = false;
          });
        }
      }();
    }
  

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------- DISCOUNT NOTICE ----------------
              _buildDiscountNotice(),
              const SizedBox(height: 16),

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

              // Reason (read-only)
              const FormSectionTitle("Reason for request"),
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              const ReadonlyInfoField(value: "Personal Request"),

              const SizedBox(height: 16),

                            // From / To date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FormSectionTitle("From date *"),
                        const SizedBox(height: 8),
                        _buildDatePicker("From date", fromDate, (d) {
                          setState(() {
                            fromDate = d;
                            if (toDate != null && toDate!.isBefore(d)) {
                              toDate = null;
                            }
                          });

                          checkVehicle(); 
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FormSectionTitle("To date *"),
                        const SizedBox(height: 8),
                        _buildDatePicker("To date", toDate, (d) {
                          setState(() => toDate = d);
                          checkVehicle();
                        }, minDate: fromDate),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle number
              const FormSectionTitle("Vehicle Number * (e.g. ABC-1234)"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: vehiclePrefixController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration("ABC").copyWith(counterText: ""),
                      maxLength: 3,
                      onChanged: (_) => checkVehicle(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(
                            text: newValue.text.toUpperCase(),
                            selection: newValue.selection,
                          );
                        }),
                      ],
                      validator: (v) {
                        final s = (v ?? "").trim();

                        if (s.isEmpty) return "Required";

                        if (s.length < 2 || s.length > 3) {
                          return "Enter 2 or 3 letters";
                        }

                        if (!RegExp(r'^[A-Z]{2,3}$').hasMatch(s)) {
                          return "Letters only";
                        }

                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text("—", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: vehicleNumberController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("1234").copyWith(counterText: ""),
                      maxLength: 4,
                      onChanged: (_) => checkVehicle(),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        final s = (v ?? "").trim();
                        if (s.isEmpty) return "Required";
                        if (s.length != 4) return "Exactly 4 digits";
                        if (!RegExp(r'^\d{4}$').hasMatch(s)) return "Numbers only";
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              if (_isCheckingVehicle)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Checking vehicle availability...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isCheckingVehicle && vehicleError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vehicleError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isCheckingVehicle &&
                  vehicleError == null &&
                  vehicleTypeName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        "Vehicle available · Type: $vehicleTypeName",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              const SizedBox(height: 10),
                if (fromDate != null && toDate != null)
                  Builder(
                    builder: (_) {
                      final attempt = _previousRequestCount + 1;
                      final isFreeAttempt = attempt <= 2;
                      final isHalfOffAttempt = attempt >= 3 && attempt <= 5;
                      final requestedDays = toDate!.difference(fromDate!).inDays + 1;
                      final isOverFreeLimit =
                          isFreeAttempt && requestedDays > _maxFocDaysPerRequest;
                      final isOverHalfOffLimit =
                          isHalfOffAttempt && requestedDays > _maxHalfOffDaysPerRequest;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E2A3A)),
                                ),
                                Text(
                                  '$requestedDays days',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                                ),
                              ],
                            ),
                          ),
                          if (isOverFreeLimit)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, left: 2),
                              child: Text(
                                'Free requests are limited to maximum 2 days per request.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                          if (isOverHalfOffLimit)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, left: 2),
                              child: Text(
                                '50% off requests are limited to maximum 3 days per request.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD32F2F),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

              const SizedBox(height: 16),

              // Approving Manager dropdown
              const FormSectionTitle("Select Approving Manager *"),
              const SizedBox(height: 8),

              if (managers.isEmpty)
                const Text("No managers found")
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E6EF)),
                  ),
                  child: Column(

                    // Only show the manager that matches reportingManagerId
                    children: managers
                      .where((m) => m["id"].toString() == reportingManagerId)
                      .map((m) {
                      final managerId = (m["id"] ?? "").toString();
                      final empId = int.tryParse(managerId) ?? 0;

                      return RadioListTile<String>(
                        value: managerId,
                        groupValue: selectedManagerId,
                        onChanged: (v) => setState(() => selectedManagerId = v),

                        // radio on right
                        controlAffinity: ListTileControlAffinity.trailing,

                        // radio color
                        fillColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return Colors.blue;
                          return Colors.grey;
                        }),

                        // photo on left
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
                                    backgroundColor: Colors.white,
                                    color: Colors.blue,
                                    strokeWidth: 2),
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

                        // name
                        title: Text(
                          (m["name"] ?? "-").toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),
              // Submit
            GradientSubmitButton(
              label: 'SUBMIT',
              isLoading: _isSubmitting,
              onPressed: (vehicleError != null || _isCheckingVehicle)
                  ? null
                  : _showVehicleSubmitConfirmation,
            ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------
  // Same input style as login/leave form - clear on all devices
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
  // ── Discount notice ──────────────────────────────────────────────────────
  Widget _buildDiscountNotice() {
    // usage_count from API IS the current attempt number (server increments before we load the form)
    final usageCount = _previousRequestCount;
    final attempt = _previousRequestCount + 1; // no +1: usage_count already equals the attempt number

    String discount;
    Color discountColor;
    if (attempt <= 2) {
      discount = "FREE";
      discountColor = const Color(0xFF2E7D32);
    } else if (attempt <= 5) {
      discount = "50% OFF";
      discountColor = const Color(0xFF1565C0);
    } else {
      discount = "0%";
      discountColor = const Color(0xFFB71C1C);
    }

    final tableRows = [
      ["1",  "1st",  "100%"],
      ["2",  "2nd",  "100%"],
      ["3",  "3rd",  "50%"],
      ["4",  "4th",  "50%"],
      ["5",  "5th",  "50%"],
      ["6+", "6th+", "0%"],
    ];

    String currentKey = attempt >= 6 ? "6+" : attempt.toString();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDD0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 17),
                SizedBox(width: 8),
                Text(
                  "Personal Vehicle Request Policy",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Current attempt summary ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: _loadingRequestCount
                ? const Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                    ),
                    SizedBox(width: 8),
                    Text("Loading your request info...",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7A90))),
                  ])
                : Row(
                    children: [
                      _statBox("Your Attempt", "#$attempt", const Color(0xFF1E2A3A)),
                      const SizedBox(width: 20),
                      _statBox("Discount", discount, discountColor),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBDD0F8)),
                        ),
                        child: Text(
                          "Usage count: $usageCount",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2A3A),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFCDDAF8)),

          // ── Policy table ──
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DISCOUNT POLICY",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7A90),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Table(
                    border: TableBorder.all(
                      color: const Color(0xFFCDDAF8),
                      width: 1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(1.3),
                      1: FlexColumnWidth(1.2),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      // Header row
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFD6E4FF)),
                        children: [
                          //_tableCell("Attempt No.", isHeader: true),
                          _tableCell("Attempt",        isHeader: true),
                          _tableCell("Discount",       isHeader: true),
                        ],
                      ),
                      // Data rows
                      ...tableRows.map((r) {
                        final isCurrent = r[0] == currentKey;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFE3EDFF)
                                : Colors.white,
                          ),
                          children: [
                            //_tableCell(r[0], isCurrent: isCurrent),
                            _tableCell(r[1], isCurrent: isCurrent),
                            _tableCell(r[2], isCurrent: isCurrent, isDiscount: true),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF6B7A90), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }

  Widget _tableCell(String text,
      {bool isHeader = false, bool isCurrent = false, bool isDiscount = false}) {
    Color textColor = const Color(0xFF1E2A3A);
    if (isHeader) textColor = const Color(0xFF1565C0);
    if (isDiscount && !isHeader) {
      if (text == "100%")      textColor = const Color(0xFF2E7D32);
      else if (text == "50%")  textColor = const Color(0xFF1565C0);
      else if (text == "25%")  textColor = const Color(0xFFE65100);
      else                     textColor = const Color(0xFFB71C1C);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: (isHeader || isCurrent) ? FontWeight.w800 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? selected,
    Function(DateTime) onSelect, {
    DateTime? minDate,
  }) {
    return TextFormField(
      readOnly: true,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      decoration: _inputDecoration(
        label,
        suffix: Icon(Icons.calendar_today, color: Colors.grey.shade700),
      ),
      controller: TextEditingController(
        text: selected == null ? '' : DateFormat('MM/dd/yyyy').format(selected),
      ),
      validator: (_) => selected == null ? 'Required' : null,
      onTap: () async {
        final now = DateTime.now();

        final firstDate = minDate ?? DateTime(now.year, now.month, now.day);

        final initialDate = selected ??
            (now.isBefore(firstDate) ? firstDate : now);

        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1565C0),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF1E2A3A),
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