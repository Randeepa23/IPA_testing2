import 'dart:ui';
import 'package:flutter/material.dart';

Future<void> showRemoveVehicleDialog({
  required BuildContext context,
  required Future<void> Function({
    required String reason,
  }) onConfirm,
}) async {
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool submitting = false;

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.15),
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.90).clamp(300.0, 420.0);

      return StatefulBuilder(
        builder: (context, setState) {
          return Stack(
            children: [

              /// Background Blur
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

                            /// Header
                            Row(
                              children: [
                                const Icon(
                                  Icons.remove_circle_outline,
                                  color: Color(0xFFD10A0A),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Remove Assigned Vehicle",
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

                            const Text(
                              "Please provide a reason to remove the assigned vehicle.",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 16),

                            /// Reason field
                            TextFormField(
                              controller: reasonController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: "Enter reason",
                                filled: true,
                                fillColor: Colors.grey.shade50,
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
                                    color: Colors.red,
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

                            /// Buttons
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
                                        color: Color(0xFFC4C4C4),
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
                                      Color(0xFFD10A0A),
                                      Color(0xFF5B0000),
                                    ],
                                  ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: submitting
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!
                                                  .validate()) return;

                                              setState(
                                                  () => submitting = true);

                                              await onConfirm(
                                                reason: reasonController.text
                                                    .trim(),
                                              );

                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
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
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              "Remove Vehicle",
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