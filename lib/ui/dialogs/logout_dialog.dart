import 'dart:ui';
import 'package:flutter/material.dart';

class LogoutDialog extends StatelessWidget {
  final VoidCallback onLogout;

  const LogoutDialog({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0060A6);
    final w = MediaQuery.of(context).size.width;
    final dialogW = (w * 0.90).clamp(300.0, 420.0);

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.logout, color: blue),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Logout",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Please confirm you want to log out.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Are you sure you want to log out from this account?",
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // close dialog
                              onLogout(); // run logout action
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              "Logout",
                              style: TextStyle(color: Colors.white),
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
      ],
    );
  }
}