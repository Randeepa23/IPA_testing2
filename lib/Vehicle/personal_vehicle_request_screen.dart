import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../home_screen.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../ui/dialogs/personal_vehicle_policy_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Services/transport_service_config.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
import '../Services/api_service.dart';
import '../ui/widgets/common_form_widgets.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
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

class AvailableVehicleOption {
  final int id;
  final String regNo;
  final String make;
  final String model;
  final String vehicleTypeName;

  AvailableVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.vehicleTypeName,
  });

  factory AvailableVehicleOption.fromJson(Map<String, dynamic> json) {
    return AvailableVehicleOption(
      id: int.tryParse((json["id"] ?? "").toString()) ?? 0,
      regNo: (json["reg_no"] ?? "").toString().trim(),
      make: (json["make"] ?? "").toString().trim(),
      model: (json["model"] ?? "").toString().trim(),
      vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
    );
  }

  String get displayLabel => "$regNo - ${"$make $model".trim()}";
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
  bool _policyDialogVisible = false;
  bool _policyAccepted = false;

  // Read-only user details
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();

  // Fields
  final destinationController = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;

  String? vehicleError;
  String? vehicleTypeName;
  int _checkGeneration = 0;
  final TextEditingController _availableVehicleController = TextEditingController();
  List<AvailableVehicleOption> _availableVehicles = [];
  AvailableVehicleOption? _selectedVehicle;
  bool _isLoadingAvailableVehicles = false;
  String? _availableVehicleError;

  // Manager
  List<Map<String, String>> managers = [];
  String? selectedManagerId;
  bool loadingManagers = true;
  String? managerError;
  String? reportingManagerId;

  bool _isSubmitting = false;

  // Attempt slots
  List<AttemptSlot> _attemptSlots = [];
  AttemptSlot? _selectedSlot;
  bool _loadingSlots = true;
  String? _slotsError;

  int? vehicleId;

  // Photo cache for manager avatars
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};
  final remarkController = TextEditingController();

  bool _isCarTypeForFreeAttempt(String? typeName) {
    final t = (typeName ?? "").trim().toLowerCase();
    return t.contains("car");
  }

  @override
  void initState() {
    super.initState();
    _loadManagers();
    _loadAttemptSlots();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['phone'] ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => _enforcePolicyAcceptance());
  }

  @override
  void dispose() {
    _availableVehicleController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _enforcePolicyAcceptance() async {
    if (!mounted || _policyAccepted || _policyDialogVisible) return;
    _policyDialogVisible = true;

    final agreed = await showPersonalVehiclePolicyDialog(context: context);
    _policyDialogVisible = false;
    if (!mounted) return;

    if (agreed) {
      setState(() => _policyAccepted = true);
      return;
    }
    TopBanner.show(
      context,
      title: "Policy Required",
      message: "You must agree to the vehicle policy to continue.",
      icon: Icons.error_outline,
      isSuccess: false,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(
        username: widget.user["username"]?.toString() ?? "",
        name: widget.user["name"]?.toString() ?? "",
        user: widget.user,
      )),
      (route) => false,
    );
  }

  Future<void> _loadAttemptSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final employeeId = widget.user["employeeId"]?.toString()
          ?? widget.user["employee_id"]?.toString()
          ?? "";

      final slots = await VehicleApiService.getPersonalAttemptSlots(employeeId);

      if (!mounted) return;
      setState(() {
        _attemptSlots = slots;
        _loadingSlots = false;
        _slotsError = null;
        if (_selectedSlot == null && slots.isNotEmpty) {
          final firstAvailable = slots.where((s) => s.isSelectable).firstOrNull;
          if (firstAvailable != null) {
            _selectedSlot = firstAvailable;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _slotsError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
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

      final res = await VehicleApiService.getDefaultManagers(
        employeeId: int.parse(empId),
      );

      if (res["success"] != true) {
        throw Exception(res["message"] ?? "API failed");
      }

      final data = res["data"] ?? {};
      final raw  = List.from(data["managers"] ?? []);
      final resolvedManagerId = data["reporting_manager_id"]?.toString();

      final list = raw.map<Map<String, String>>((e) {
        return {
          "id":   e["id"].toString(),
          "name": (e["name"] ?? "").toString(),
        };
      }).toList();

      setState(() {
        managers           = list;
        reportingManagerId = resolvedManagerId;
        selectedManagerId  = resolvedManagerId;
        loadingManagers    = false;
      });

      debugPrint("Resolved manager: $resolvedManagerId");
      debugPrint("Fallback reason: ${data["fallback_reason"]}");
    } catch (e) {
      setState(() {
        loadingManagers   = false;
        managerError      = e.toString();
        managers          = [];
        selectedManagerId = null;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (fromDate == null || toDate == null) return;
    if (_selectedSlot == null) return;

    final requestedDays = toDate!.difference(fromDate!).inDays + 1;
    final maxDays = _selectedSlot!.maxDays;

    if (maxDays != null && requestedDays > maxDays) {
      TopBanner.show(
        context,
        title: "Request Failed",
        message: "This slot allows a maximum of $maxDays day(s) per request.",
        icon: Icons.error,
        isSuccess: false,
      );
      return;
    }
    if (_selectedSlot!.carOnly && !_isCarTypeForFreeAttempt(vehicleTypeName)) {
      TopBanner.show(
        context,
        title: "Request Failed",
        message: "For this slot, only Car type vehicles are allowed.",
        icon: Icons.error,
        isSuccess: false,
      );
      return;
    }

    if (_isLoadingAvailableVehicles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please wait for vehicle availability check to complete.")),
      );
      return;
    }
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an available vehicle.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String employeeIdFromUser() {
        final u = widget.user;
        final v = u["employee_id"] ?? u["employeeId"] ?? u["id"] ?? u["user_id"];
        return (v ?? "").toString().trim();
      }

      final empId        = employeeIdFromUser();
      final managerId    = selectedManagerId!;
      final employeeName = nameController.text.trim();
      final employeePhone = contactController.text.trim();
      final vehicleNo    = _selectedVehicle!.regNo;
      final fromDateTxt  = DateFormat("yyyy-MM-dd").format(fromDate!);
      final toDateTxt    = DateFormat("yyyy-MM-dd").format(toDate!);
      final vehicleType  = _selectedVehicle!.vehicleTypeName.isEmpty
          ? (vehicleTypeName ?? "-")
          : _selectedVehicle!.vehicleTypeName;

      debugPrint("[SubmitForm] ── Payload ──────────────────────");
      debugPrint("[SubmitForm] employeeId    : $empId");
      debugPrint("[SubmitForm] managerId     : $managerId");
      debugPrint("[SubmitForm] vehicleNo     : $vehicleNo");
      debugPrint("[SubmitForm] vehicleType   : $vehicleType");
      debugPrint("[SubmitForm] vehicleId     : $vehicleId");
      debugPrint("[SubmitForm] fromDate      : $fromDateTxt");
      debugPrint("[SubmitForm] toDate        : $toDateTxt");
      debugPrint("[SubmitForm] attemptNumber : ${_selectedSlot!.attemptNumber}");
      debugPrint("[SubmitForm] remark        : ${remarkController.text}");
      debugPrint("[SubmitForm] ────────────────────────────────");

      final res = await VehicleApiService.createPersonalVehicleRequest(
        employeeId:    empId,
        managerId:     managerId,
        vehicleNo:     vehicleNo,
        fromDate:      fromDateTxt,
        toDate:        toDateTxt,
        contactNo:     employeePhone,
        employeeName:  employeeName,
        reason:        "Personal Request",
        vehicleType:   vehicleType,
        vehicleId:     _selectedVehicle!.id,
        attemptNumber: _selectedSlot!.attemptNumber,
        remark: remarkController.text.trim().isEmpty
                ? null
                : remarkController.text.trim(),
      );
      debugPrint("Vehicle Type Name: $vehicleType");

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
      if (!mounted) return;
      final errText = e
          .toString()
          .replaceFirst(RegExp(r'^Exception:\s*'), '')
          .trim();
      TopBanner.show(
        context,
        title: "Submission Failed",
        message: errText.isEmpty ? "Something went wrong." : errText,
        icon: Icons.error_outline,
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showVehicleSubmitConfirmation() {
    final vehicleNoTxt   = _selectedVehicle?.regNo ?? "-";
    final fromTxt        = fromDate == null ? "-" : DateFormat('MM/dd/yyyy').format(fromDate!);
    final toTxt          = toDate   == null ? "-" : DateFormat('MM/dd/yyyy').format(toDate!);
    final destinationTxt = destinationController.text.trim().isEmpty
        ? "-"
        : destinationController.text.trim();

    showVehicleSubmitDialog(
      context:         context,
      vehicleNoTxt:    vehicleNoTxt,
      fromTxt:         fromTxt,
      toTxt:           toTxt,
      destinationTxt:  destinationTxt,
      isSubmitting:    _isSubmitting,
      onConfirm:       _submitForm,
      showDestination: false,
    );
  }

  Future<void> _fetchAvailableVehicles() async {
    if (fromDate == null || toDate == null) {
      setState(() {
        _availableVehicles = [];
        _selectedVehicle = null;
        _availableVehicleController.clear();
        _availableVehicleError = null;
        vehicleTypeName = null;
        vehicleId = null;
        _isLoadingAvailableVehicles = false;
      });
      return;
    }
    final gen = ++_checkGeneration;

    setState(() {
      _isLoadingAvailableVehicles = true;
      _availableVehicleError = null;
      _availableVehicles = [];
      _selectedVehicle = null;
      _availableVehicleController.clear();
      vehicleTypeName = null;
      vehicleId = null;
      vehicleError = null;
    });

    try {
      final start = DateFormat("yyyy-MM-dd").format(fromDate!);
      final end   = DateFormat("yyyy-MM-dd").format(toDate!);
      final uri   = Uri.parse(TransportServiceConfig.availableVehiclesUrl).replace(
        queryParameters: {"start_date": start, "end_date": end},
      );

      final response = await http.get(uri, headers: const {"Accept": "application/json"});

      if (gen != _checkGeneration) return;
      final body = response.body.trim();
      if (body.isEmpty) {
        setState(() {
          _availableVehicleError = "No response from server.";
          _isLoadingAvailableVehicles = false;
        });
        return;
      }

      final payload = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final carOnly = _selectedSlot?.carOnly ?? false;
      final list = (payload["data"] as List? ?? [])
          .whereType<Map>()
          .map((e) => AvailableVehicleOption.fromJson(Map<String, dynamic>.from(e)))
          .where((v) => v.id > 0 && v.regNo.isNotEmpty)
          .where((v) {
            if (!carOnly) return true;
            return _isCarTypeForFreeAttempt(v.vehicleTypeName);
          })
          .toList();

      if (payload["success"] != true) {
        setState(() {
          _availableVehicleError = (payload["message"] ?? "Could not load available vehicles.").toString();
          _isLoadingAvailableVehicles = false;
        });
        return;
      }

      setState(() {
        _availableVehicles     = list;
        _availableVehicleError = list.isEmpty
            ? (carOnly
                  ? "No available Car type vehicles for selected dates."
                  : "No available vehicles for selected dates.")
            : null;
        _isLoadingAvailableVehicles = false;
      });
    } catch (_) {
      if (gen != _checkGeneration) return;
      setState(() {
        _availableVehicleError = "Could not load available vehicles. Please try again.";
        _isLoadingAvailableVehicles = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
              // ---------------- YOUR DETAILS ----------------
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
                    const Text(
                      'Your Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFDDE5F8)),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCell('Name', nameController.text, Icons.badge_outlined)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Employee No.', employeeController.text, Icons.tag_rounded)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _infoCell('Department', departmentController.text, Icons.apartment_rounded)),
                        const SizedBox(width: 20),
                        Expanded(child: _infoCell('Contact No.', contactController.text, Icons.phone_outlined)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
                            // ---------------- ATTEMPT SLOT SELECTOR ----------------
              _buildAttemptSelector(),
              const SizedBox(height: 16),

              // Reason (read-only)
              const FormSectionTitle("Reason for request"),
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
                            if (toDate != null && toDate!.isBefore(d)) toDate = null;
                          });
                          _fetchAvailableVehicles();
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
                          _fetchAvailableVehicles();
                        }, minDate: fromDate),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Available vehicles
              const FormSectionTitle("Available Vehicle *"),
              const SizedBox(height: 8),
              TypeAheadField<AvailableVehicleOption>(
                controller: _availableVehicleController,
                hideOnEmpty: true,
                hideOnError: false,
                hideOnUnfocus: false,
                hideWithKeyboard: false,
                decorationBuilder: (context, child) => Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
                suggestionsCallback: (pattern) {
                  final q = pattern.trim().toLowerCase();
                  if (q.isEmpty) return _availableVehicles;
                  return _availableVehicles.where((v) {
                    final full = "${v.regNo} ${v.make} ${v.model} ${v.vehicleTypeName}".toLowerCase();
                    return full.contains(q);
                  }).toList();
                },
                itemBuilder: (context, suggestion) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    tileColor: Colors.white,
                    title: Text(
                      suggestion.displayLabel,
                      style: const TextStyle(fontSize: 13.5, color: Colors.black87),
                    ),
                    subtitle: Text(
                      suggestion.vehicleTypeName,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),
                onSelected: (suggestion) {
                  setState(() {
                    _selectedVehicle = suggestion;
                    _availableVehicleController.text = suggestion.displayLabel;
                    vehicleId = suggestion.id;
                    vehicleTypeName = suggestion.vehicleTypeName;
                    vehicleError = null;
                  });
                },
                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    decoration: _inputDecoration(
                      "Search vehicle by number or model",
                      icon: Icons.directions_car_outlined,
                    ),
                    validator: (_) {
                      if (fromDate == null || toDate == null) return "Select date range first";
                      if (_selectedVehicle == null) return "Please select an available vehicle";
                      return null;
                    },
                  );
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("No matching vehicles found."),
                ),
              ),
              if (_isLoadingAvailableVehicles)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)),
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Loading available vehicles...",
                        style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingAvailableVehicles && _availableVehicleError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _availableVehicleError!,
                          style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isLoadingAvailableVehicles && _selectedVehicle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        "Selected: ${_selectedVehicle!.regNo} · Type: ${_selectedVehicle!.vehicleTypeName}",
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              const SizedBox(height: 10),
              if (fromDate != null && toDate != null)
                Builder(
                  builder: (_) {
                    final requestedDays = toDate!.difference(fromDate!).inDays + 1;
                    final maxDays      = _selectedSlot?.maxDays;
                    final isOverLimit  = maxDays != null && requestedDays > maxDays;
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
                        if (isOverLimit)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 2),
                            child: Text(
                              'This slot allows a maximum of $maxDays day(s) per request.',
                              style: const TextStyle(
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

              const SizedBox(height: 2),

              // ── Remark (Optional) ──────────────────────────────────────────
              const FormSectionTitle("Remark (Optional)"),
              const SizedBox(height: 8),
              TextFormField(
                controller: remarkController,
                style: const TextStyle(color: Colors.black, fontSize: 15),
                maxLines: 2,
                maxLength: 300,
                decoration: _inputDecoration("Enter any additional notes or remarks..."),
              ),

              const SizedBox(height: 14),

              // ── Estimated Payment Calculation ─────────────────────────────
              _buildPaymentCalculationSection(),

              const SizedBox(height: 16),

              // Approving Manager dropdown
              const FormSectionTitle("Select Approving Manager *"),
              const SizedBox(height: 8),

              if (managers.isEmpty)
                const Text("No managers found")
              else
                Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE1E6EF)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: managers
                        .where((m) => m["id"].toString() == reportingManagerId)
                        .map((m) {
                      final managerId = (m["id"] ?? "").toString();
                      final empId     = int.tryParse(managerId) ?? 0;

                      return Material(
                        color: Colors.transparent,
                        child: RadioListTile<String>(
                          value: managerId,
                          groupValue: selectedManagerId,
                          onChanged: (v) => setState(() => selectedManagerId = v),
                          controlAffinity: ListTileControlAffinity.trailing,
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) return Colors.blue;
                            return Colors.grey;
                          }),
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
                                      backgroundColor: Colors.white,
                                      color: Colors.blue,
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
                            (m["name"] ?? "-").toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 18),
              GradientSubmitButton(
                label: 'SUBMIT',
                isLoading: _isSubmitting,
                onPressed: (_loadingSlots ||
                        _selectedSlot == null ||
                        _isLoadingAvailableVehicles ||
                        _selectedVehicle == null ||
                        _availableVehicleError != null)
                    ? null
                    : _showVehicleSubmitConfirmation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

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

  // ── Attempt slot selector ─────────────────────────────────────────────────

  // ── Slot discount colour helpers ─────────────────────────────────────────
  Color _discountBadgeBg(int pct) {
    if (pct == 100) return const Color(0xFF1B5E20);   // FREE  → dark green
    if (pct >= 50)  return const Color(0xFFE65100);   // 50%   → orange
    return const Color(0xFF5D4037);                   // 0%    → brown-grey
  }

  Widget _buildAttemptSelector() {
    final usedCount = _attemptSlots.where((s) => s.status == 'approved').length;
    final total     = _attemptSlots.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE5F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Select Your Attempt ",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!_loadingSlots && _slotsError == null && total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$usedCount / $total used",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: _loadingSlots
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1565C0),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Loading your slots...",
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7A90)),
                          ),
                        ],
                      ),
                    ),
                  )
                : _slotsError != null
                ? _buildSlotError()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress dots row
                      if (total > 0) _buildProgressDots(usedCount, total),
                      const SizedBox(height: 12),
                      // 3-column grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: total,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1.3,
                        ),
                        itemBuilder: (_, i) => _buildSlotCard(_attemptSlots[i]),
                      ),
                      // Selected slot details
                      if (_selectedSlot != null) ...[
                        _buildSelectedSlotInfo(_selectedSlot!),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFD32F2F), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Failed to load slots",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD32F2F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _slotsError!,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF9E2A2A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _loadAttemptSlots,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text("Retry"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots(int used, int total) {
    return Row(
      children: List.generate(total, (i) {
        final isUsed = i < used;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isUsed ? const Color(0xFF1565C0) : const Color(0xFFDDE5F8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSlotCard(AttemptSlot slot) {
    final isSelected = _selectedSlot?.attemptNumber == slot.attemptNumber;
    final isPending  = slot.status == 'pending';
    final isApproved = slot.status == 'approved';
    final isDisabled = !slot.isSelectable;

    // Colour scheme
    final Color cardBg;
    final Color cardBorder;
    final Color labelColor;

    if (isApproved) {
      cardBg     = const Color(0xFFF5F5F5);
      cardBorder = const Color(0xFFE0E0E0);
      labelColor = Colors.grey.shade400;
    } else if (isPending) {
      cardBg     = const Color(0xFFFFF8F1);
      cardBorder = const Color(0xFFFFCC80);
      labelColor = const Color(0xFFE65100);
    } else if (isSelected) {
      cardBg     = const Color(0xFF1565C0);
      cardBorder = const Color(0xFF1565C0);
      labelColor = Colors.white;
    } else {
      cardBg     = Colors.white;
      cardBorder = const Color(0xFFBDD0F8);
      labelColor = const Color(0xFF1565C0);
    }

    Widget statusOverlay() {
      if (isApproved) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_rounded, size: 9, color: Colors.white),
              SizedBox(width: 2),
              Text("USED", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }
      if (isPending) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_top_rounded, size: 9, color: Colors.white),
              SizedBox(width: 2),
              Text("PENDING", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }
      if (isSelected) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 9, color: Colors.white),
              SizedBox(width: 2),
              Text("SELECTED", style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Discount badge colour
    final badgeBg   = isDisabled
        ? Colors.grey.shade300
        : (isSelected ? Colors.white.withValues(alpha: 0.22) : _discountBadgeBg(slot.discountPct));
    final badgeText = isDisabled
        ? Colors.grey.shade500
        : (isSelected ? Colors.white : Colors.white);

    return GestureDetector(
      onTap: isDisabled ? null : () {
        setState(() {
          _selectedSlot = slot;
          _selectedVehicle = null;
          _availableVehicleController.clear();
          vehicleTypeName = null;
          vehicleId = null;
          vehicleError = null;
          _availableVehicles = [];
          _availableVehicleError = null;
        });
        _fetchAvailableVehicles();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Attempt label
              Text(
                slot.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: labelColor,
                  letterSpacing: -0.3,
                ),
              ),
              // Discount badge + status in one row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        slot.discount,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              // Status overlay
              statusOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSlotInfo(AttemptSlot slot) {
    final isMax  = slot.maxDays != null;
    final Color accent = slot.discountPct == 100
        ? const Color(0xFF1B5E20)
        : slot.discountPct >= 50
            ? const Color(0xFFE65100)
            : const Color(0xFF5D4037);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDD0F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  slot.discount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "${slot.label} attempt selected",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2A3A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _slotInfoPill(
                icon: Icons.calendar_month_outlined,
                label: isMax ? "Max ${slot.maxDays} day(s)" : "No day limit",
                bg: const Color(0xFFE8F0FE),
                fg: const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              _slotInfoPill(
                icon: Icons.directions_car_outlined,
                label: slot.carOnly ? "Car only" : "All vehicles",
                bg: slot.carOnly
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8F5E9),
                fg: slot.carOnly
                    ? const Color(0xFFE65100)
                    : const Color(0xFF2E7D32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slotInfoPill({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w700),
          ),
        ],
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
        final now       = DateTime.now();
        final firstDate = minDate ?? DateTime(now.year, now.month, now.day);
        final initialDate = selected ?? (now.isBefore(firstDate) ? firstDate : now);

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
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
            ),
            child: child!,
          ),
        );

        if (picked != null) onSelect(picked);
      },
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

  Widget _buildPaymentCalculationSection() {
    final slot = _selectedSlot;
    final int attemptNum = slot?.attemptNumber ?? 1;
    final bool isFreeAttempt = attemptNum <= 2;
    final int discountPct = slot != null
        ? slot.discountPct
        : (isFreeAttempt ? 100 : 50);
    final String attemptLabel = slot?.label ?? "${attemptNum}st";

    // Duration calculation based on picked dates (or 1 day estimate if not picked yet)
    final bool hasDateRange = fromDate != null && toDate != null;
    final int days = hasDateRange ? (toDate!.difference(fromDate!).inDays + 1) : 1;

    // Mock pricing data in LKR
    const double baseDailyRate = 5000.0;
    final double grossAmount = baseDailyRate * days;
    final double discountAmount = isFreeAttempt
        ? grossAmount
        : grossAmount * (discountPct / 100.0);
    final double netPayable = isFreeAttempt ? 0.0 : (grossAmount - discountAmount);

    final currencyFormatter = NumberFormat("#,##0.00", "en_US");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormSectionTitle("Estimated Payment Calculation"),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isFreeAttempt ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFreeAttempt ? const Color(0xFF86EFAC) : const Color(0xFFD0E1FD),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFreeAttempt
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isFreeAttempt
                          ? Icons.card_giftcard_rounded
                          : Icons.receipt_long_rounded,
                      size: 18,
                      color: isFreeAttempt
                          ? const Color(0xFF15803D)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFreeAttempt
                              ? "Free Attempt ($attemptLabel)"
                              : "$attemptLabel Attempt Rate",
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          hasDateRange
                              ? "$days day${days == 1 ? '' : 's'} (${DateFormat('d MMM').format(fromDate!)} – ${DateFormat('d MMM').format(toDate!)})"
                              : "$days day (estimated · select dates above)",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFreeAttempt
                          ? const Color(0xFFDCFCE7)
                          : (discountPct > 0
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFreeAttempt
                          ? "FREE"
                          : (discountPct > 0 ? "$discountPct% OFF" : "STANDARD"),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isFreeAttempt
                            ? const Color(0xFF15803D)
                            : (discountPct > 0
                                ? const Color(0xFFB45309)
                                : const Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Breakdown rows
              _buildCalcRow("Standard Daily Rate",
                  "LKR ${currencyFormatter.format(baseDailyRate)} / day"),
              const SizedBox(height: 5),
              _buildCalcRow("Duration", "$days day${days == 1 ? '' : 's'}"),
              const SizedBox(height: 5),
              _buildCalcRow("Gross Amount",
                  "LKR ${currencyFormatter.format(grossAmount)}"),
              if (discountAmount > 0) ...[
                const SizedBox(height: 5),
                _buildCalcRow(
                  isFreeAttempt
                      ? "Free Benefit (100% OFF)"
                      : "Staff Subsidy ($discountPct% OFF)",
                  "- LKR ${currencyFormatter.format(discountAmount)}",
                  valueColor: const Color(0xFF16A34A),
                ),
              ],

              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Total Payable row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total Payable (LKR)",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    "LKR ${currencyFormatter.format(netPayable)}",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isFreeAttempt
                          ? const Color(0xFF15803D)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              // Footer note
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isFreeAttempt
                          ? "Staff members receive 2 free personal vehicle attempts per year. No payment is required for this attempt."
                          : "Calculated at staff subsidized rate for attempts beyond the 2 free allocations.",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalcRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor ?? const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
