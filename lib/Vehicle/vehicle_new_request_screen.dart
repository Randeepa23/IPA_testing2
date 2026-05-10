import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../Services/vehicle_api_service.dart';
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

  final apiKey = await VehicleApiService.getGooglePlacesApiKey();
  if (apiKey == null || apiKey.isEmpty) {
    debugPrint("Places: could not load API key from backend");
    return [];
  }

  final uri = Uri.https(
    "maps.googleapis.com",
    "/maps/api/place/autocomplete/json",
    {
      "input": input,
      "key": apiKey,
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

  // Vehicle number parts
  final TextEditingController _vehicleLettersController = TextEditingController();
  final TextEditingController _vehicleNumbersController = TextEditingController();

  // Manager
  List<Map<String, String>> managers = [];
  String? selectedManagerId;
  bool loadingManagers = true;
  String? managerError;

  bool _isSubmitting = false;

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
    _vehicleLettersController.dispose();
    _vehicleNumbersController.dispose();
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

    final letters = _vehicleLettersController.text.trim().toUpperCase();
    final numbers = _vehicleNumbersController.text.trim();
    final vehicleNo = "$letters-$numbers";

    final fromDateTxt = DateFormat("yyyy-MM-dd").format(fromDate!);
    final toDateTxt = DateFormat("yyyy-MM-dd").format(toDate!);

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
      vehicleType: "-",
      vehicleId: 0,
    );

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
  final letters = _vehicleLettersController.text.trim().toUpperCase();
  final numbers = _vehicleNumbersController.text.trim();
  final vehicleNoTxt = (letters.isNotEmpty || numbers.isNotEmpty)
      ? "$letters-$numbers"
      : "-";

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
                        }, minDate: fromDate),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Vehicle number entry
              const FormSectionTitle("Vehicle Number"),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _vehicleLettersController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        "Letters (e.g. ABC)",
                        icon: Icons.directions_car_outlined,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Text(
                      "-",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black54),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _vehicleNumbersController,
                      style: const TextStyle(color: Colors.black, fontSize: 15),
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("Numbers (e.g. 1234)"),
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
              onPressed: _isSubmitting ? null : _showVehicleSubmitConfirmation,
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