import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

Future<void> showAssignVehicleDialog({
  required BuildContext context,
  required String vehicleType,
  required String title,
  required String assignedStartAt,
  required String assignedEndAt,
  required int? transportServiceId,
  required Future<void> Function({
    required String vehicleType,
    required String vehicleNo,
    required String reason,
  }) onConfirm,
}) async {
  final prefixController = TextEditingController();
  final numberController = TextEditingController();
  final reasonController = TextEditingController();
  final vehicleTypeController = TextEditingController(text: vehicleType);
  final formKey = GlobalKey<FormState>();

  bool submitting = false;
  bool isCheckingVehicle = false;
  String? vehicleError;
  String? validatedTypeName;
  int checkGeneration = 0;

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 430.0);

      return StatefulBuilder(
        builder: (context, setState) {
          // Validates the entered vehicle number against the API using the
          // trip's vehicle_type_name, date range, and transport_service_id.
          void checkVehicle() {
            final prefix = prefixController.text.trim();
            final number = numberController.text.trim();

            if (prefix.length < 2 || number.length < 4) {
              setState(() {
                vehicleError = null;
                validatedTypeName = null;
                isCheckingVehicle = false;
              });
              return;
            }

            final gen = ++checkGeneration;
            setState(() {
              isCheckingVehicle = true;
              vehicleError = null;
              validatedTypeName = null;
            });

            () async {
              try {
                final vNo = "$prefix-$number";
                final response = await http.post(
                  Uri.parse(
                      "https://exploredrive.lk/api/transport-services/validate-vehicle"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "vehicle_no": vNo,
                    "assigned_start_at": assignedStartAt,
                    "vehicle_type_name":
                        vehicleType.isNotEmpty ? vehicleType : null,
                    "assigned_end_at": assignedEndAt,
                    "transport_service_id": null,
                  }),
                );

                if (gen != checkGeneration) return;

                Map<String, dynamic> data;
                try {
                  data = Map<String, dynamic>.from(
                      jsonDecode(response.body) as Map);
                } catch (_) {
                  setState(() {
                    vehicleError =
                        "Server error (${response.statusCode}). Please try again.";
                    isCheckingVehicle = false;
                  });
                  return;
                }

                final typeName =
                    data["vehicle"]?["vehicle_type_name"]?.toString();

                if (data["ok"] == false) {
                  setState(() {
                    validatedTypeName = typeName;
                    vehicleError = data["message"]?.toString();
                    isCheckingVehicle = false;
                  });
                  return;
                }

                setState(() {
                  validatedTypeName = typeName;
                  vehicleError = null;
                  isCheckingVehicle = false;
                });
              } catch (_) {
                if (gen != checkGeneration) return;
                setState(() {
                  vehicleError =
                      "Could not validate vehicle. Check your connection and try again.";
                  isCheckingVehicle = false;
                });
              }
            }();
          }

          return Stack(
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.transparent),
              ),
              Center(
                child: Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: dialogW,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header ──
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Assign Vehicle",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed:
                                      submitting ? null : () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title == "Change Vehicle"
                                  ? "Vehicle type is fixed for this trip. Enter the new vehicle number and reason for the change."
                                  : "Vehicle type is fixed for this trip. Enter vehicle number and reason.",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Vehicle Type (read-only) ──
                            const Text(
                              "Vehicle Type",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: vehicleTypeController,
                              readOnly: true,
                              decoration: _fieldDecoration("Vehicle type"),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Vehicle type is required"
                                      : null,
                            ),
                            const SizedBox(height: 14),

                            // ── Vehicle Number ──
                            const Text(
                              "Vehicle Number",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: prefixController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    maxLength: 3,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z]')),
                                      UpperCaseTextFormatter(),
                                    ],
                                    decoration: _fieldDecoration("ABC")
                                        .copyWith(counterText: ""),
                                    onChanged: (_) => checkVehicle(),
                                    validator: (v) {
                                      final s = v?.trim() ?? "";
                                      if (s.isEmpty) return "Required";
                                      if (!RegExp(r'^[A-Za-z]+$').hasMatch(s)) {
                                        return "Letters only";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    "-",
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: TextFormField(
                                    controller: numberController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 4,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: _fieldDecoration("1234")
                                        .copyWith(counterText: ""),
                                    onChanged: (_) => checkVehicle(),
                                    validator: (v) {
                                      final s = v?.trim() ?? "";
                                      if (s.isEmpty) return "Required";
                                      if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                        return "Numbers only";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // ── Validation feedback ──
                            if (isCheckingVehicle)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 13,
                                      height: 13,
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
                            if (!isCheckingVehicle && vehicleError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Colors.red, size: 14),
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
                            if (!isCheckingVehicle &&
                                vehicleError == null &&
                                validatedTypeName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline,
                                        color: Colors.green, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Vehicle available · Type: $validatedTypeName",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 14),

                            // ── Reason / Note ──
                            const Text(
                              "Reason / Note",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: reasonController,
                              maxLines: 3,
                              decoration:
                                  _fieldDecoration("Enter reason / note"),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? "Reason is required"
                                      : null,
                            ),

                            const SizedBox(height: 18),

                            // ── Action buttons ──
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: submitting
                                        ? null
                                        : () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0060A6),
                                      side: const BorderSide(
                                        color:
                                            Color.fromARGB(255, 196, 196, 196),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: (submitting ||
                                                isCheckingVehicle ||
                                                vehicleError != null)
                                            ? const [
                                                Color(0xFFBDBDBD),
                                                Color(0xFF9E9E9E)
                                              ]
                                            : const [
                                                Color(0xFF0060A6),
                                                Color(0xFF003580)
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: (submitting ||
                                              isCheckingVehicle ||
                                              vehicleError != null)
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }
                                              setState(
                                                  () => submitting = true);
                                              final vehicleNo =
                                                  "${prefixController.text.trim().toUpperCase()}-${numberController.text.trim()}";
                                              try {
                                                await onConfirm(
                                                  vehicleType:
                                                      vehicleTypeController
                                                          .text
                                                          .trim(),
                                                  vehicleNo: vehicleNo,
                                                  reason: reasonController
                                                      .text
                                                      .trim(),
                                                );
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx);
                                                }
                                              } catch (e) {
                                                setState(() =>
                                                    submitting = false);
                                                ScaffoldMessenger.of(ctx)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        "Failed to assign vehicle: $e"),
                                                  ),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        elevation: 0,
                                      ),
                                      child: submitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              title == "Change Vehicle"
                                                  ? "Change"
                                                  : "Assign",
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
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
              ),
            ],
          );
        },
      );
    },
  );
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.4),
    ),
  );
}
