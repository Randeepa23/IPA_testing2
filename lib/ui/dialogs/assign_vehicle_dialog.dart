import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upperText = newValue.text.toUpperCase();

    return TextEditingValue(
      text: upperText,
      selection: newValue.selection,
    );
  }
}
showAssignVehicleDialog({
  required BuildContext context,
  required String vehicleType,
  required String title,
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

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 430.0);

      return StatefulBuilder(
        builder: (context, setState) {
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  onPressed: submitting
                                      ? null
                                      : () => Navigator.pop(ctx),
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

                            const Text(
                              "Vehicle Type",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              controller: vehicleTypeController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: "Vehicle type",
                                filled: true,
                                //fillColor: const Color(0xFFF3F4F6),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Vehicle type is required";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            const Text(
                              "Vehicle Number",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: prefixController,
                                    textCapitalization: TextCapitalization.characters,
                                    maxLength: 3,
                                    inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                                    UpperCaseTextFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      counterText: "",
                                      hintText: "ABC",
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD9D9D9),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD9D9D9),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1565C0),
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      final v = value?.trim() ?? "";
                                      if (v.isEmpty) {
                                        return "Required";
                                      }
                                      if (!RegExp(r'^[A-Za-z]+$').hasMatch(v)) {
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
                                      fontWeight: FontWeight.w800,
                                    ),
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
                                    decoration: InputDecoration(
                                      counterText: "",
                                      hintText: "1234",
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD9D9D9),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD9D9D9),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1565C0),
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      final v = value?.trim() ?? "";
                                      if (v.isEmpty) {
                                        return "Required";
                                      }
                                      if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                                        return "Numbers only";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            const Text(
                              "Reason / Note",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),

                            TextFormField(
                              controller: reasonController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "Enter reason / note",
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD9D9D9),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1565C0),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Reason is required";
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 18),

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
                                        vertical: 12,
                                      ),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF0060A6),
                                          Color(0xFF003580),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: submitting
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }

                                              setState(() => submitting = true);

                                              final vehicleNo =
                                                  "${prefixController.text.trim().toUpperCase()}-${numberController.text.trim()}";

                                              try {
                                                await onConfirm(
                                                  vehicleType: vehicleTypeController.text.trim(),
                                                  vehicleNo: vehicleNo,
                                                  reason: reasonController.text.trim(),
                                                );

                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx);
                                                }
                                              } catch (e) {
                                                setState(
                                                  () => submitting = false,
                                                );
                                                ScaffoldMessenger.of(ctx)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      "Failed to assign vehicle: $e",
                                                    ),
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
                                          vertical: 12,
                                        ),
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
                                          : Text(title == "Change Vehicle" ? "Change" : "Assign",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
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