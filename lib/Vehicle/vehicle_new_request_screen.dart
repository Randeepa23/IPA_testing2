import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/dialogs/vehicle_submit_dialog.dart';

class VehicleRequestFormScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const VehicleRequestFormScreen({super.key, required this.user});

  @override
  State<VehicleRequestFormScreen> createState() => _VehicleRequestFormScreenState();
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
  List<Map<String, String>> managers = [
    {"id": "EMP-UUID-010", "name": "Srimal Perera"},
    {"id": "EMP-UUID-011", "name": "Navodaya Silva"},
  ];
  String? selectedManagerId;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    nameController.text = widget.user['name'] ?? '';
    employeeController.text = widget.user['employeeCode'] ?? '';
    departmentController.text = widget.user['department'] ?? '';
    contactController.text = widget.user['primaryContact'] ?? '';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (fromDate == null || toDate == null) return;

    setState(() => _isSubmitting = true);

    try {
      final vehicleNo = "${vehiclePrefixController.text.trim()}-${vehicleNumberController.text.trim()}";

      // TODO: call API here
      // final res = await ApiService.createVehicleRequest(...)

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submitted: $vehicleNo")),
      );

      Navigator.pop(context);
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
              _sectionTitle("Vehicle Number *"),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: vehiclePrefixController,
                      decoration: _inputDecoration("Enter Later"),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
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
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration("Enter Numbers"),
                      // Only validate if prefix is entered
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "Required";
                        if (!RegExp(r'^\d+$').hasMatch(v.trim())) return "Only numbers";
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

              // Destination
              _sectionTitle("Destination *"),
              const SizedBox(height: 8),
              TextFormField(
                controller: destinationController,
                decoration: _inputDecoration("Enter your destination").copyWith(
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
              ),

              const SizedBox(height: 16),

              // Approving Manager dropdown
              _sectionTitle("Select Approving Manager *"),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedManagerId,
                decoration: _inputDecoration("Select Manager.."),
                hint: const Text("Select Manager.."),
                items: managers
                    .map((m) => DropdownMenuItem(
                          value: m["id"],
                          child: Text(m["name"] ?? ""),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedManagerId = v),
                validator: (v) => v == null ? "Select a manager" : null,
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
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
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
      decoration: _inputDecoration(label).copyWith(
        hintText: label,
        suffixIcon: const Icon(Icons.calendar_today),
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
        );
        if (picked != null) onSelect(picked);
      },
    );
  }
}