import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import 'dart:convert';
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
const String googlePlacesKey = "https://maps.googleapis.com/maps/api/js?key=AIzaSyAHmbwBrk0OKY0Nhp9FrR_zn8HKLGZ54OU&libraries=places%22></script>";

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
  if (input.isEmpty) return [];

  final url = Uri.parse(
    "https://maps.googleapis.com/maps/api/place/autocomplete/json"
    "?input=$input"
    "&key=$googlePlacesKey"
    "&components=country:lk",
  );

  final response = await http.get(url);
  if (response.statusCode != 200) return [];

  final data = json.decode(response.body);
  if (data['status'] != 'OK') return [];

  return (data['predictions'] as List)
      .map((e) => PlaceSuggestion.fromJson(e))
      .toList();
}

class _VehicleRequestFormScreenState extends State<VehicleRequestFormScreen> {
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

  // Manager
  List<Map<String, String>> managers = [];
  String? selectedManagerId;
  bool loadingManagers = true;
  String? managerError;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
      _loadManagers();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['phone'] ?? '';
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

              // Reason (read-only)
              _sectionTitle("Reason for request"),
              const SizedBox(height: 8),
              _readonlyInput(value: "Office Service"),

              const SizedBox(height: 16),

              // Vehicle number
              _sectionTitle("Vehicle Number * (e.g. ABC-1234)"),
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

              const SizedBox(height: 16),

              // From / To date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("From date *"),
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
                        _sectionTitle("To date *"),
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
              
              // Destination (Autocomplete)
              _sectionTitle("Destination *"),
              const SizedBox(height: 8),

              TypeAheadField<PlaceSuggestion>(
                debounceDuration: const Duration(milliseconds: 300),
                suggestionsCallback: (pattern) {
                  return fetchPlaceSuggestions(pattern);
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(suggestion.description),
                  );
                },
                onSelected: (suggestion) {
                  destinationController.text = suggestion.description;
                },
                builder: (context, textController, focusNode) {
                  textController.text = destinationController.text;

                  textController.addListener(() {
                    destinationController.text = textController.text;
                  });

                  return TextFormField(
                    controller: destinationController,
                    style: const TextStyle(color: Colors.black, fontSize: 15),
                    focusNode: focusNode,
                    decoration: _inputDecoration("Enter your destination", icon: Icons.location_on_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                  );
                },
              ),

              const SizedBox(height: 16),

              // Approving Manager dropdown
              _sectionTitle("Select Approving Manager *"),
              const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: (selectedManagerId != null &&
                          managers.any((m) => m["id"] == selectedManagerId))
                      ? selectedManagerId
                      : null,
                  dropdownColor: Colors.white,
                  decoration: _dropdownDecoration().copyWith(
                    hintText: "Select Manager",
                  ),
                  items: managers.map((m) {
                    return DropdownMenuItem<String>(
                      value: m["id"],
                      child: Text(m["name"] ?? "-"),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedManagerId = v),
                  validator: (v) => v == null ? "Select manager" : null,
                ),
              const SizedBox(height: 18),
              // Submit
              SizedBox(
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF003580)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _showVehicleSubmitConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'SUBMIT',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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

  // ---------------- UI HELPERS ----------------

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }
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
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      hintStyle: TextStyle(color: Colors.grey.shade600),
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
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? now,
          firstDate: (minDate ?? now).subtract(const Duration(days: 0)),
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