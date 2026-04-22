import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Services/transport_service_config.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
import '../Services/api_service.dart';
import '../ui/widgets/common_form_widgets.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;


class VehicleRequestFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRequestSubmitted;

  const VehicleRequestFormScreen({super.key, required this.user, this.onRequestSubmitted});

  @override
  State<VehicleRequestFormScreen> createState() => _VehicleRequestFormScreenState();
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

class AvailableVehicleOption {
  final int id;
  final String regNo;
  final String make;
  final String model;
  final String companyName;
  final String vehicleTypeName;

  AvailableVehicleOption({
    required this.id,
    required this.regNo,
    required this.make,
    required this.model,
    required this.companyName,
    required this.vehicleTypeName,
  });

  factory AvailableVehicleOption.fromJson(Map<String, dynamic> json) {
    return AvailableVehicleOption(
      id: int.tryParse((json["id"] ?? "").toString()) ?? 0,
      regNo: (json["reg_no"] ?? "").toString().trim(),
      make: (json["make"] ?? "").toString().trim(),
      model: (json["model"] ?? "").toString().trim(),
      companyName: (json["company_name"] ?? "").toString().trim(),
      vehicleTypeName: (json["vehicle_type_name"] ?? "").toString().trim(),
    );
  }

  String get displayLabel {
    final vehicleName = "$make $model".trim();
    return "$regNo - $vehicleName";
  }
}

class _VehicleRequestFormScreenState extends State<VehicleRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Read-only user details
  final nameController = TextEditingController();
  final employeeController = TextEditingController();
  final departmentController = TextEditingController();
  final contactController = TextEditingController();
  final FocusNode _destinationFocusNode = FocusNode();

  // Fields
  final destinationController = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;

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

  bool _isSubmitting = false;

  int? vehicleId;

  // Photo cache for manager avatars
  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

  @override
  void initState() {
    super.initState();
      _loadManagers();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['phone'] ?? '';
  }

  @override
  void dispose() {
    _availableVehicleController.dispose();
    super.dispose();
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

    final list = raw.map<Map<String, String>>((e) {
      return {
        "id": e["id"].toString(),
        "name": (e["name"] ?? "").toString(),
      };
    }).toList();

    debugPrint("[LoadManagers] loaded: $list  reportingId: $reportingId");

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
  if (_selectedVehicle == null) {
    TopBanner.show(
      context,
      title: "Vehicle Required",
      message: "Please select an available vehicle for the selected date range.",
      icon: Icons.error_outline,
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

    final vehicleNo = _selectedVehicle!.regNo;

    final fromDateTxt = DateFormat("yyyy-MM-dd").format(fromDate!);
    final toDateTxt = DateFormat("yyyy-MM-dd").format(toDate!);

    final vehicleType = _selectedVehicle!.vehicleTypeName.isEmpty
        ? (vehicleTypeName ?? "-")
        : _selectedVehicle!.vehicleTypeName;

    final res = await VehicleApiService.createOfficeVehicleRequest(
      employeeId: empId,
      managerId: managerId,
      vehicleNo: vehicleNo,
      fromDate: fromDateTxt,
      toDate: toDateTxt,
      destination: destinationController.text.trim(),
      contactNo: employeePhone,
      employeeName: employeeName,
      reason: "Office Service",
      vehicleType: vehicleType,   // ← new optional param
      vehicleId: _selectedVehicle!.id, // <-- pass the ID here

      
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
  final vehicleNoTxt = _selectedVehicle?.regNo ?? "-";

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
    });

    try {
      final start = DateFormat("yyyy-MM-dd").format(fromDate!);
      final end = DateFormat("yyyy-MM-dd").format(toDate!);
      final uri = Uri.parse(TransportServiceConfig.availableVehiclesUrl).replace(
        queryParameters: {
          "start_date": start,
          "end_date": end,
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          "Accept": "application/json",
        },
      );

      if (gen != _checkGeneration) return;

      final body = response.body.trim();
      if (body.isEmpty) {
        setState(() {
          _availableVehicleError = "No response from server.";
          _isLoadingAvailableVehicles = false;
        });
        return;
      }

      final decoded = jsonDecode(body);
      final payload = Map<String, dynamic>.from(decoded as Map);
      final isSuccess = payload["success"] == true;
      final data = (payload["data"] as List? ?? [])
          .whereType<Map>()
          .map((e) => AvailableVehicleOption.fromJson(Map<String, dynamic>.from(e)))
          .where((v) => v.id > 0 && v.regNo.isNotEmpty)
          .toList();

      if (!isSuccess) {
        setState(() {
          _availableVehicleError = (payload["message"] ?? "Could not load available vehicles.").toString();
          _isLoadingAvailableVehicles = false;
        });
        return;
      }

      setState(() {
        _availableVehicles = data;
        _availableVehicleError = data.isEmpty ? "No available vehicles for this date range." : null;
        _isLoadingAvailableVehicles = false;
      });
    } catch (e) {
      if (gen != _checkGeneration) return;
      setState(() {
        _availableVehicleError = "Could not load available vehicles. Please try again.";
        _isLoadingAvailableVehicles = false;
      });
    }
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
              const ReadonlyInfoField(value: "Office Service"),

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
                  return _availableVehicles.where((vehicle) {
                    final full = "${vehicle.regNo} ${vehicle.make} ${vehicle.model} ${vehicle.vehicleTypeName}".toLowerCase();
                    return full.contains(q);
                  }).toList();
                },
                itemBuilder: (context, suggestion) => ListTile(
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
                onSelected: (suggestion) {
                  setState(() {
                    _selectedVehicle = suggestion;
                    _availableVehicleController.text = suggestion.displayLabel;
                    vehicleId = suggestion.id;
                    vehicleTypeName = suggestion.vehicleTypeName;
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
                      if (fromDate == null || toDate == null) {
                        return "Select date range first";
                      }
                      if (_selectedVehicle == null) return "Please select an available vehicle";
                      return null;
                    },
                  );
                },
                loadingBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                      backgroundColor: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Text("No matching vehicles found."),
                  ),
                ),
              ),
              if (_isLoadingAvailableVehicles)
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
                        "Loading available vehicles...",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
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
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 15),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _availableVehicleError!,
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
              if (!_isLoadingAvailableVehicles && _selectedVehicle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        "Selected: ${_selectedVehicle!.regNo} · Type: ${_selectedVehicle!.vehicleTypeName}",
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
                          '${toDate!.difference(fromDate!).inDays + 1} days',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              const FormSectionTitle("Destination *"),
              const SizedBox(height: 8),
              // Destination (Autocomplete)
              TypeAheadField<PlaceSuggestion>(
                controller: destinationController, 
                focusNode: _destinationFocusNode,          

                debounceDuration: const Duration(milliseconds: 400),
                suggestionsCallback: (pattern) async => fetchPlaceSuggestions(pattern),

                loadingBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                      backgroundColor: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),

                itemBuilder: (context, suggestion) => ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(suggestion.description),
                ),

                onSelected: (suggestion) {
                  destinationController.text = suggestion.description; 
                  _destinationFocusNode.unfocus();     
                },

                builder: (context, controller, focusNode) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,

                        style: const TextStyle(
                        color: Colors.black,
                      ),
                    decoration: _inputDecoration(
                      "Enter your destination",
                      icon: Icons.location_on_outlined,
                      
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
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
                    children: managers.map((m) {
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
              onPressed: (_isLoadingAvailableVehicles || _selectedVehicle == null)
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