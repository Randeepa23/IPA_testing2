import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';

class PersonalVehicleInvoiceViewerScreen extends StatelessWidget {
  final File file;
  final String tripCode;
  final Map<String, dynamic> tripData;

  const PersonalVehicleInvoiceViewerScreen({
    super.key,
    required this.file,
    required this.tripCode,
    required this.tripData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vehicle Request Invoice",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              "Trip Code: $tripCode",
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFDCEBFA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0B5FA5),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Open in PDF Viewer",
            icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
            onPressed: () async {
              try {
                await OpenFile.open(file.path);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Could not open file: $e")),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => file.readAsBytes(),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Invoice_$tripCode.pdf',
        previewPageMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: (ctx, build, pageFormat) async {
              await OpenFile.open(file.path);
            },
          ),
        ],
      ),
    );
  }
}
