import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a payment receipt PDF whose layout mirrors the HTML template:
/// white header + dark bottom border, light amount bar, 2-column table grid,
/// dashed footer. Pure-Dart pdf package — no platform channel required.
class AirportParkingReceiptBuilder {
  // ── Palette ──────────────────────────────────────────────────────────────────
  static const _navyBg = PdfColor(0.059, 0.090, 0.165); // #0F172A  dark header
  static const _white = PdfColors.white;
  static const _subText = PdfColor(0.75, 0.80, 0.88);  // header sub-text
  static const _dark = PdfColor(0.067, 0.094, 0.153);  // #111827
  static const _grey = PdfColor(0.216, 0.255, 0.318);  // #374151
  static const _border = PdfColor(0.820, 0.831, 0.859);// #d1d5db
  static const _tableBorder = PdfColor(0.898, 0.906, 0.922); // #e5e7eb
  static const _sectionBg = PdfColor(0.953, 0.957, 0.965); // #f3f4f6
  static const _rowAlt = PdfColor(0.980, 0.980, 0.980);     // #fafafa
  static const _amountBg = PdfColor(0.976, 0.980, 0.984);   // #f9fafb
  static const _green = PdfColor(0.086, 0.396, 0.204);      // #166534
  static const _greenBg = PdfColor(0.863, 0.988, 0.910);    // #dcfce7

  // ──────────────────────────────────────────────────────────────────────────
  //  PUBLIC ENTRY POINT
  // ──────────────────────────────────────────────────────────────────────────

  static Future<File> generate(Map<String, dynamic> bookingData) async {
    // ── Parse fields ─────────────────────────────────────────────────────────
    final reference = bookingData['reference_number'] as String? ?? '—';
    final name = bookingData['name'] as String? ?? '—';
    final rawContact =
        (bookingData['whatsapp_number'] as String? ?? '').trim();
    final contact =
        rawContact.isNotEmpty ? '+$rawContact' : '—';
    final vehicleRaw =
        (bookingData['vehicle_number'] as String? ?? '').trim();
    final vehicle = vehicleRaw.isNotEmpty ? vehicleRaw : 'N/A';
    final totalPrice = bookingData['total_price'] as String? ?? '0.00';
    final startRaw = bookingData['start_date'] as String? ?? '';
    final endRaw = bookingData['end_date'] as String? ?? '';

    final now = DateTime.now();
    final receiptNo =
        'RCPT-${DateFormat('yyyyMMddHHmmss').format(now)}-${now.millisecond.toString().padLeft(3, '0')}';
    final generatedAt = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    final priceFormatted =
        NumberFormat('#,##0.00').format(double.tryParse(totalPrice) ?? 0.0);

    // Parking duration as date range string
    String parkingDuration = '—';
    try {
      final s = DateTime.parse(startRaw.replaceFirst(' ', 'T'));
      final e = DateTime.parse(endRaw.replaceFirst(' ', 'T'));
      parkingDuration =
          '${DateFormat('yyyy-MM-dd hh:mm a').format(s)} to\n${DateFormat('yyyy-MM-dd hh:mm a').format(e)}';
    } catch (_) {}

    // ── Build document ────────────────────────────────────────────────────────
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(reference, receiptNo, generatedAt),
            pw.SizedBox(height: 10),
            _metaRow(receiptNo, reference, generatedAt),
            pw.SizedBox(height: 10),
            _amountBar(priceFormatted),
            pw.SizedBox(height: 12),
            _grid(
              name: name,
              contact: contact,
              vehicle: vehicle,
              reference: reference,
              receiptNo: receiptNo,
              parkingDuration: parkingDuration,
              generatedAt: generatedAt,
            ),
            pw.SizedBox(height: 12),
            _footer(),
          ],
        ),
      ),
    );

    final pdfBytes = await doc.save();
    final dir = await getApplicationSupportDirectory();
    final safeName =
        reference.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    final file = File('${dir.path}/receipt_$safeName.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  HEADER  — white bg, thick dark bottom border
  // ──────────────────────────────────────────────────────────────────────────

  // ── dark navy header — no borderRadius (avoids color+radius artefact) ──────
  static pw.Widget _header(
      String reference, String receiptNo, String generatedAt) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const pw.BoxDecoration(
        color: _navyBg, // safe: color without borderRadius
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: company info
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Airport Parking',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'No. 371/5, Negombo Road, Seeduwa, Sri Lanka',
                style: pw.TextStyle(fontSize: 9, color: _subText),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'info@airportparking.lk  |  +94 76 141 4557',
                style: pw.TextStyle(fontSize: 9, color: _subText),
              ),
            ],
          ),
          // Right: receipt title
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'PAYMENT RECEIPT',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Official payment confirmation',
                style: pw.TextStyle(fontSize: 9, color: _subText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4 meta boxes (border+borderRadius only — no color, no artefact) ─────────
  static pw.Widget _metaRow(
      String receiptNo, String reference, String generatedAt) {
    final boxes = [
      ['RECEIPT NO', receiptNo],
      ['BOOKING REF', reference],
      ['GENERATED AT', generatedAt],
      ['GENERATED BY', 'Admin'],
    ];
    return pw.Row(
      children: boxes.asMap().entries.map((e) {
        final isLast = e.key == boxes.length - 1;
        return pw.Expanded(
          child: pw.Container(
            margin: isLast
                ? pw.EdgeInsets.zero
                : const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _border),
              borderRadius: pw.BorderRadius.circular(6),
              // no color — safe with borderRadius
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
                pw.SizedBox(height: 5),
                pw.Text(
                  e.value[1],
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
  //  AMOUNT BAR
  // ──────────────────────────────────────────────────────────────────────────

  static pw.Widget _amountBar(String priceFormatted) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _amountBg,
        border: pw.Border.all(color: _border),
        // no borderRadius — color+borderRadius causes a pdf render artefact
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
                  'Payment successfully collected',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _navyBg,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'This receipt confirms the collected amount for the\nrelated Airport Parking booking.',
                  style: pw.TextStyle(fontSize: 8.5, color: _grey),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: _greenBg,
                    // no borderRadius — color+borderRadius causes artefact
                  ),
                  child: pw.Text(
                    'Paid Fully',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Right: amount
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
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  2-COLUMN GRID
  // ──────────────────────────────────────────────────────────────────────────

  static pw.Widget _grid({
    required String name,
    required String contact,
    required String vehicle,
    required String reference,
    required String receiptNo,
    required String parkingDuration,
    required String generatedAt,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _box(
            title: 'Customer Details',
            rows: [
              ['Customer Name', name],
              ['Contact Number', contact],
              ['Vehicle Number', vehicle],
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _box(
            title: 'Receipt Details',
            rows: [
              ['Receipt Number', receiptNo],
              ['Booking Reference', reference],
              ['Parking Duration', parkingDuration],
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
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Title bar — color only, no borderRadius (color+radius causes artefact)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _sectionBg,
            ),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _dark,
              ),
            ),
          ),
          pw.Divider(height: 0, color: _border, thickness: 0.8),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            return pw.Container(
              decoration: isLast
                  ? null
                  : pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                            color: _tableBorder, width: 0.5),
                      ),
                    ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Label cell
                  pw.Container(
                    width: 70,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: pw.BoxDecoration(color: _rowAlt),
                    child: pw.Text(
                      entry.value[0],
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _dark,
                      ),
                    ),
                  ),
                  // Value cell
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: pw.Text(
                        entry.value[1],
                        style: pw.TextStyle(
                            fontSize: 9.5, color: _dark),
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

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey500,
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
              'This is a system-generated receipt issued by Airport Parking.'
              ' Please retain this document\nfor your records and future reference.',
              style: pw.TextStyle(fontSize: 9, color: _grey),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(height: 28),
              pw.SizedBox(
                width: 130,
                child: pw.Divider(
                    color: _dark, thickness: 0.8),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Airport Parking',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _dark,
                ),
              ),
              pw.Text(
                'Authorized Signature',
                style: pw.TextStyle(fontSize: 8, color: _grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
