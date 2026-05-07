import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AirportInvoiceResult {
  final bool status;
  final String message;
  final File? file;

  AirportInvoiceResult({
    required this.status,
    required this.message,
    this.file,
  });
}

class AirportParkingService {
  static const String _baseUrl = "https://airportparking.lk/get-invoice.php";

  /// Same URL [fetchInvoice] uses — safe to load in a [WebView] (no native PDF plugin).
  static Uri invoiceRequestUri(String reference) {
    final ref = reference.trim().toUpperCase();
    return Uri.parse(_baseUrl).replace(queryParameters: {'reference': ref});
  }

  /// Validate the reference format: G\d+-AP-\d+ (e.g. G7-AP-05)
  static bool isValidReference(String reference) {
    final regex = RegExp(r'^G\d+-AP-\d+$');
    return regex.hasMatch(reference.trim().toUpperCase());
  }

  /// Download the invoice PDF for a given reference.
  /// Returns an [AirportInvoiceResult] indicating success/failure with a
  /// readable message and the downloaded [File] when available.
  static Future<AirportInvoiceResult> fetchInvoice(String reference) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return AirportInvoiceResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    if (!isValidReference(ref)) {
      return AirportInvoiceResult(
        status: false,
        message: "Invalid reference format. Expected format: G7-AP-05",
      );
    }

    try {
      final uri = invoiceRequestUri(ref);
      final response = await http.get(uri).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        return AirportInvoiceResult(
          status: false,
          message: "Server returned ${response.statusCode}. Please try again.",
        );
      }

      final contentType =
          (response.headers['content-type'] ?? '').toLowerCase();

      // The PHP endpoint returns plain-text errors with 200 status code
      // (e.g. "Folder not found", "No invoices found"). Detect them via
      // content-type or by inspecting the body bytes for the PDF magic.
      final isPdf = contentType.contains('application/pdf') ||
          _hasPdfMagic(response.bodyBytes);

      if (!isPdf) {
        final body = response.body.trim();
        return AirportInvoiceResult(
          status: false,
          message: body.isEmpty
              ? "Invoice not found for this reference."
              : body,
        );
      }

      // App support dir is more reliable for native PDF engines than cache/temp
      // (read permissions + stable path on Android).
      final dir = await getApplicationSupportDirectory();
      final safeName = ref.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final file = File('${dir.path}/airport_invoice_$safeName.pdf');
      await file.writeAsBytes(response.bodyBytes, flush: true);

      return AirportInvoiceResult(
        status: true,
        message: "Invoice loaded successfully.",
        file: file,
      );
    } on SocketException {
      return AirportInvoiceResult(
        status: false,
        message: "No internet connection. Please check your network.",
      );
    } on HttpException {
      return AirportInvoiceResult(
        status: false,
        message: "Could not reach the invoice server.",
      );
    } catch (e) {
      return AirportInvoiceResult(
        status: false,
        message: "Something went wrong: $e",
      );
    }
  }

  /// PDF files start with the bytes "%PDF" (0x25 0x50 0x44 0x46).
  static bool _hasPdfMagic(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }
}
