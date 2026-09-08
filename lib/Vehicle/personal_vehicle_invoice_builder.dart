import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates an official Personal Vehicle Request Invoice / Payment Receipt PDF
/// branded with Explore Holdings logo, structured meta boxes, amount banner,
/// 2-column details table, and General Manager (Ralston Gerreyn) approval signature.
class PersonalVehicleInvoiceBuilder {
  // ── Palette ──────────────────────────────────────────────────────────────────
  static const _headerBg    = PdfColor(0.950, 0.965, 0.985); // Light corporate tint
  static const _primary     = PdfColor(0.000, 0.400, 0.702); // #0066B3 Brand Blue
  static const _subText     = PdfColor(0.250, 0.300, 0.380);
  static const _dark        = PdfColor(0.078, 0.118, 0.180);
  static const _grey        = PdfColor(0.380, 0.420, 0.480);
  static const _border      = PdfColor(0.820, 0.850, 0.890);
  static const _tableBorder = PdfColor(0.890, 0.910, 0.930);
  static const _sectionBg   = PdfColor(0.950, 0.960, 0.975);
  static const _rowAlt      = PdfColor(0.980, 0.985, 0.995);
  static const _amountBg    = PdfColor(0.970, 0.980, 0.990);
  static const _green       = PdfColor(0.086, 0.450, 0.220);
  static const _greenBg     = PdfColor(0.860, 0.980, 0.910);
  static const _orange      = PdfColor(0.820, 0.420, 0.000);
  static const _orangeBg    = PdfColor(0.995, 0.945, 0.850);

  // ──────────────────────────────────────────────────────────────────────────
  //  PUBLIC ENTRY POINT
  // ──────────────────────────────────────────────────────────────────────────
  static Future<File> generate({
    required Map<String, dynamic> tripData,
    required Map<String, dynamic> user,
  }) async {
    final now = DateTime.now();

    // ── 1. Parse Trip & User details ─────────────────────────────────────────
    final tripId = (tripData['id'] ?? '').toString();
    final tripCodeRaw = (tripData['tripCode'] ?? tripData['trip_code'] ?? '').toString().trim();
    final tripCode = tripCodeRaw.isNotEmpty && tripCodeRaw != '-' ? tripCodeRaw : 'TRP-PV-${tripId.padLeft(4, '0')}';

    final invoiceNo = 'INV-PV-${DateFormat('yyyyMMdd').format(now)}-$tripId';
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    const approvedBy = 'Ralston Gerreyn';
    const approverTitle = 'General Manager';

    final employeeName = (user['name'] ?? tripData['employee_name'] ?? tripData['name'] ?? 'Staff Member').toString();
    final employeeCode = (user['employeeCode'] ?? user['employeeId'] ?? user['employee_id'] ?? '—').toString();
    final department = (user['department'] ?? 'Explore Holdings').toString();
    final rawContact = (user['phone'] ?? user['contact'] ?? '').toString().trim();
    final contact = rawContact.isNotEmpty ? rawContact : '—';

    final vehicleNo = (tripData['vehicleNo'] ?? tripData['vehicle_no'] ?? '—').toString();
    final vehicleName = (tripData['vehicleName'] ?? tripData['vehicle_name'] ?? '').toString().trim();
    final fullVehicle = (vehicleName.isNotEmpty && vehicleName != '-')
        ? '$vehicleNo ($vehicleName)'
        : vehicleNo;

    final fromDateStr = (tripData['fromDate'] ?? tripData['assignedDate'] ?? '').toString();
    final toDateStr = (tripData['toDate'] ?? '').toString();

    int days = 1;
    try {
      if (fromDateStr.isNotEmpty && toDateStr.isNotEmpty) {
        final f = DateTime.parse(fromDateStr.replaceFirst(' ', 'T'));
        final t = DateTime.parse(toDateStr.replaceFirst(' ', 'T'));
        days = (t.difference(f).inDays + 1).clamp(1, 999);
      }
    } catch (_) {}

    final durationFormatted = (fromDateStr.isNotEmpty && toDateStr.isNotEmpty)
        ? '$days Day${days == 1 ? '' : 's'} ($fromDateStr to $toDateStr)'
        : '$days Day${days == 1 ? '' : 's'}';

    // ── 2. Scenario-based Pricing & Attempt calculation ──────────────────────
    final rawAttempt = tripData['attempt_number'] ?? tripData['attemptNumber'];
    final int attemptNum = (rawAttempt is num)
        ? rawAttempt.toInt()
        : (int.tryParse(rawAttempt?.toString() ?? '') ?? 1);

    const double baseDailyRate = 5000.0;
    final double grossAmount = baseDailyRate * days;

    final bool isFree = attemptNum <= 2;
    final int discountPct = isFree ? 100 : (attemptNum <= 5 ? 50 : 0);
    final double discountAmount = isFree ? grossAmount : grossAmount * (discountPct / 100.0);
    final double netPayable = isFree ? 0.0 : (grossAmount - discountAmount);

    final String attemptLabel;
    final String statusBadge;
    final PdfColor badgeColor;
    final PdfColor badgeBg;

    if (isFree) {
      attemptLabel = attemptNum == 1 ? '1st Attempt (Free Allocation)' : '2nd Attempt (Free Allocation)';
      statusBadge = 'Free Allocation (100% OFF)';
      badgeColor = _green;
      badgeBg = _greenBg;
    } else if (attemptNum <= 5) {
      attemptLabel = '${attemptNum}th Attempt (50% Staff Discount)';
      statusBadge = 'Staff Subsidized (50% OFF)';
      badgeColor = _orange;
      badgeBg = _orangeBg;
    } else {
      attemptLabel = 'More / Standard Staff Rate';
      statusBadge = 'Standard Staff Rate';
      badgeColor = _primary;
      badgeBg = _headerBg;
    }

    final priceFormatted = NumberFormat('#,##0.00').format(netPayable);
    final dailyRateFormatted = NumberFormat('#,##0.00').format(baseDailyRate);
    final grossFormatted = NumberFormat('#,##0.00').format(grossAmount);
    final discountFormatted = NumberFormat('#,##0.00').format(discountAmount);

    // ── 3. Load Brand Logo & Signature Assets ────────────────────────────────
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/ExploreHoldingLogo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('PersonalVehicleInvoiceBuilder: could not load logo: $e');
    }

    pw.ImageProvider? sigImage;
    try {
      final sigData = await rootBundle.load('assets/signatures/signature1.png');
      sigImage = pw.MemoryImage(sigData.buffer.asUint8List());
    } catch (e) {
      debugPrint('PersonalVehicleInvoiceBuilder: could not load signature: $e');
    }

    // ── 4. Build Document ────────────────────────────────────────────────────
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(22),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(logoImage),
            pw.SizedBox(height: 10),
            _metaRow(
              invoiceNo: invoiceNo,
              tripCode: tripCode,
              generatedAt: generatedAt,
              approvedBy: approvedBy,
            ),
            pw.SizedBox(height: 10),
            _amountBar(
              isFree: isFree,
              priceFormatted: priceFormatted,
              statusBadge: statusBadge,
              badgeColor: badgeColor,
              badgeBg: badgeBg,
              discountPct: discountPct,
              grossFormatted: grossFormatted,
              discountFormatted: discountFormatted,
            ),
            pw.SizedBox(height: 12),
            _grid(
              employeeName: employeeName,
              employeeCode: employeeCode,
              department: department,
              contact: contact,
              vehicle: fullVehicle,
              invoiceNo: invoiceNo,
              tripCode: tripCode,
              attemptLabel: attemptLabel,
              durationFormatted: durationFormatted,
              dailyRateFormatted: dailyRateFormatted,
              generatedAt: generatedAt,
            ),
            pw.SizedBox(height: 14),
            _footer(
              signatureImage: sigImage,
              approverName: approvedBy,
              approverTitle: approverTitle,
            ),
          ],
        ),
      ),
    );

    // ── 5. Save & Return File ────────────────────────────────────────────────
    final pdfBytes = await doc.save();
    final dir = await getApplicationSupportDirectory();
    final safeTrip = tripCode.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final file = File('${dir.path}/invoice_${safeTrip}_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HEADER
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _header(pw.ImageProvider? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const pw.BoxDecoration(
        color: _headerBg,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: logo + company address
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Image(logoImage, height: 42, fit: pw.BoxFit.contain)
              else
                pw.Text(
                  'Explore HOLDINGS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
              pw.SizedBox(height: 5),
              pw.Text(
                'No. 371/5, Negombo Road, Seeduwa, Sri Lanka',
                style: const pw.TextStyle(fontSize: 8.5, color: _subText),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'info@exploreholdings.lk  |  +94 11 234 5678',
                style: const pw.TextStyle(fontSize: 8.5, color: _subText),
              ),
            ],
          ),
          // Right: invoice title
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PAYMENT RECEIPT',
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Official vehicle request invoice',
                style: const pw.TextStyle(fontSize: 8.5, color: _subText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  4 META BOXES
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _metaRow({
    required String invoiceNo,
    required String tripCode,
    required String generatedAt,
    required String approvedBy,
  }) {
    final boxes = [
      ['INVOICE NO', invoiceNo],
      ['TRIP CODE', tripCode],
      ['GENERATED AT', generatedAt],
      ['APPROVED BY', approvedBy],
    ];

    return pw.Row(
      children: boxes.asMap().entries.map((e) {
        final isLast = e.key == boxes.length - 1;
        return pw.Expanded(
          child: pw.Container(
            margin: isLast ? pw.EdgeInsets.zero : const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(9),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  e.value[0],
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: _grey,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  e.value[1],
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  PAYMENT AMOUNT BAR
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _amountBar({
    required bool isFree,
    required String priceFormatted,
    required String statusBadge,
    required PdfColor badgeColor,
    required PdfColor badgeBg,
    required int discountPct,
    required String grossFormatted,
    required String discountFormatted,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _amountBg,
        border: pw.Border.all(color: _border),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: title, description + badge
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Payment successfully confirmed',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  isFree
                      ? 'This receipt confirms the approved vehicle allocation under staff free annual benefits.'
                      : 'This receipt confirms the subsidized staff vehicle allocation and payable amount.',
                  style: const pw.TextStyle(fontSize: 8.5, color: _grey),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: pw.BoxDecoration(color: badgeBg),
                  child: pw.Text(
                    statusBadge,
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
                if (!isFree && discountPct > 0) ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Gross: LKR $grossFormatted  |  Staff Subsidy ($discountPct%): -LKR $discountFormatted',
                    style: const pw.TextStyle(fontSize: 8, color: _grey),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 14),
          // Right: final amount
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PAYMENT AMOUNT',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _grey,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'LKR $priceFormatted',
                style: pw.TextStyle(
                  fontSize: 21,
                  fontWeight: pw.FontWeight.bold,
                  color: isFree ? _green : _dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  2-COLUMN DETAIL GRID
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _grid({
    required String employeeName,
    required String employeeCode,
    required String department,
    required String contact,
    required String vehicle,
    required String invoiceNo,
    required String tripCode,
    required String attemptLabel,
    required String durationFormatted,
    required String dailyRateFormatted,
    required String generatedAt,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _box(
            title: 'Employee Details',
            rows: [
              ['Employee Name', employeeName],
              ['Employee No', employeeCode],
              ['Department', department],
              ['Contact Number', contact],
              ['Vehicle', vehicle],
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _box(
            title: 'Request Details',
            rows: [
              ['Invoice Number', invoiceNo],
              ['Trip Code', tripCode],
              ['Attempt', attemptLabel],
              ['Duration', durationFormatted],
              ['Daily Rate', 'LKR $dailyRateFormatted / day'],
              ['System Date & Time', generatedAt],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _box({
    required String title,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: const pw.BoxDecoration(color: _sectionBg),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: _dark,
              ),
            ),
          ),
          pw.Divider(height: 0, color: _border, thickness: 0.8),
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return pw.Container(
              decoration: isLast
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: _tableBorder, width: 0.5),
                      ),
                    ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 78,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                    decoration: const pw.BoxDecoration(color: _rowAlt),
                    child: pw.Text(
                      entry.value[0],
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _dark,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6.5),
                      child: pw.Text(
                        entry.value[1],
                        style: const pw.TextStyle(fontSize: 8.5, color: _dark),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  FOOTER
  // ──────────────────────────────────────────────────────────────────────────
  static pw.Widget _footer({
    pw.ImageProvider? signatureImage,
    required String approverName,
    required String approverTitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey400,
            style: pw.BorderStyle.dashed,
            width: 0.8,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            child: pw.Text(
              'This is a system-generated invoice issued by Explore Holdings (Pvt) Ltd.'
              '\nPlease retain this document for your records and vehicle audit reference.',
              style: const pw.TextStyle(fontSize: 8.5, color: _grey),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (signatureImage != null) ...[
                pw.Image(
                  signatureImage,
                  height: 36,
                  fit: pw.BoxFit.contain,
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Container(
                width: 140,
                height: 0.8,
                color: _dark,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                approverName,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                approverTitle,
                style: const pw.TextStyle(fontSize: 8.5, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
