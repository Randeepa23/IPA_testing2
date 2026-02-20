import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<void> showStartTripDialog({
  required BuildContext context,
  required String vehicleNo,     
  required String destination,
  required bool isSubmitting,
  required Future<void> Function({
    required String meterReading,
    required String fuelPercent,
    required File meterPhoto,
  }) onConfirm,
}) async {
  final meterCtrl = TextEditingController();
  final fuelCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  File? photoFile;
  String? photoName;

  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      final w = MediaQuery.of(ctx).size.width;
      final dialogW = (w * 0.92).clamp(290.0, 440.0);

      Future<void> pickPhoto(ImageSource source) async {
        final x = await ImagePicker().pickImage(source: source, imageQuality: 80);
        if (x == null) return;
        photoFile = File(x.path);
        photoName = x.name;

        // refresh dialog UI
        (ctx as Element).markNeedsBuild();
      }

      return Stack(
        children: [
          // Blur background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.20)),
          ),

          Center(
            child: Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: SizedBox(
                width: dialogW,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Green Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF118A1A),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Start Trip",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$vehicleNo - $destination",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.90),
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label("Current Meter Reading (km) *"),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: meterCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDeco("Enter current odometer reading"),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return "Required";
                                if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(v.trim())) return "Numbers only";
                                return null;
                              },
                            ),

                            const SizedBox(height: 10),

                            _label("Current Fuel Reading (%) *"),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: fuelCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDeco("Enter current fuel reading"),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return "Required";
                                final val = double.tryParse(v.trim());
                                if (val == null) return "Numbers only";
                                if (val < 0 || val > 100) return "0 - 100 only";
                                return null;
                              },
                            ),

                            const SizedBox(height: 10),

                            _label("Upload Meter Photo *"),
                            const SizedBox(height: 8),

                            GestureDetector(
                              onTap: () async {
                                // bottom sheet choose camera/gallery
                                await showModalBottomSheet(
                                  context: ctx,
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
                                              Navigator.pop(ctx);
                                              await pickPhoto(ImageSource.camera);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.photo_library),
                                            title: const Text("Choose from gallery"),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await pickPhoto(ImageSource.gallery);
                                            },
                                          ),
                                          if (photoFile != null)
                                            ListTile(
                                              leading: const Icon(Icons.delete, color: Colors.red),
                                              title: const Text("Remove photo"),
                                              onTap: () {
                                                Navigator.pop(ctx);
                                                photoFile = null;
                                                photoName = null;
                                                (ctx as Element).markNeedsBuild();
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.photo_camera_outlined, size: 26, color: Colors.black54),
                                    const SizedBox(height: 6),
                                    Text(
                                      photoFile == null
                                          ? "Tap to take/upload meter photo JPG, PNG\n(Max 5MB)"
                                          : "Selected: ${photoName ?? "meter_photo"}",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            const Text(
                              "• Ensure the photo clearly shows the meter reading\n"
                              "• Double-check the number you entered matches the photo",
                              style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700, color: Colors.black54, height: 1.25),
                            ),

                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : () async {
                                              if (!formKey.currentState!.validate()) return;
                                              if (photoFile == null) {
                                                ScaffoldMessenger.of(ctx).showSnackBar(
                                                  const SnackBar(content: Text("Please upload meter photo")),
                                                );
                                                return;
                                              }

                                              await onConfirm(
                                                meterReading: meterCtrl.text.trim(),
                                                fuelPercent: fuelCtrl.text.trim(),
                                                meterPhoto: photoFile!,
                                              );

                                              if (ctx.mounted) Navigator.pop(ctx);
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0B5FA5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                            )
                                          : const Text(
                                              "Start Trip Now",
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _label(String t) => Text(
      t,
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E2A3A)),
    );

InputDecoration _fieldDeco(String hint) => InputDecoration(
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