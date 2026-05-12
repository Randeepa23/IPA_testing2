import 'dart:convert';
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

class BookingResult {
  final bool status;
  final String message;
  final Map<String, dynamic>? data;

  BookingResult({required this.status, required this.message, this.data});
}

class UpdateSlotResult {
  final bool status;
  final String message;

  const UpdateSlotResult({required this.status, required this.message});
}

class UpdateStatusResult {
  final bool status;
  final String message;
  final String? bookingStatus;

  const UpdateStatusResult({
    required this.status,
    required this.message,
    this.bookingStatus,
  });
}

class AirportParkingService {
  static const String _baseUrl =
      "https://exploresuite.lk/mobile-api/airport-parking/get-invoice.php";

  static const String _updateSlotUrl =
      "https://airportparking.lk/api/update_reserved_slot.php";

  static const String _getBookingUrl =
      "https://airportparking.lk/api/get-booking.php";

  static const String _updateStatusUrl =
      "https://airportparking.lk/api/update-booking-status.php";

  /// Same URL [fetchInvoice] uses — safe to load in a [WebView] (no native PDF plugin).
  static Uri invoiceRequestUri(String reference) {
    final ref = reference.trim().toUpperCase();
    return Uri.parse(_baseUrl).replace(queryParameters: {'reference': ref});
  }

  /// Validate the reference format: [letters/numbers]-AP-[letters/numbers].
  static bool isValidReference(String reference) {
    final regex = RegExp(r'^[A-Z0-9]+-AP-[A-Z0-9]+$');
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
        message: "Invalid reference format. Expected format: G7-AP-05 or ABC1-AP-05",
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

  /// Fetch booking details for a given [reference] from the airportparking.lk API.
  static Future<BookingResult> fetchBooking(String reference) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return BookingResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    try {
      final uri = Uri.parse(_getBookingUrl)
          .replace(queryParameters: {'reference': ref});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return BookingResult(
          status: false,
          message:
              "Server returned ${response.statusCode}. Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (!json.containsKey('reference_number')) {
        final msg = (json['message'] as String?) ??
            (json['error'] as String?) ??
            'Booking not found for this reference.';
        return BookingResult(status: false, message: msg);
      }

      return BookingResult(
        status: true,
        message: 'Booking loaded.',
        data: json,
      );
    } on SocketException {
      return BookingResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return BookingResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return BookingResult(
        status: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  /// Update the booking status (e.g. "confirmed") for [reference].
  static Future<UpdateStatusResult> updateBookingStatus({
    required String reference,
    required String status,
  }) async {
    final ref = reference.trim().toUpperCase();

    try {
      final uri = Uri.parse(_updateStatusUrl)
          .replace(queryParameters: {'reference': ref, 'status': status});
      final response =
          await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return UpdateStatusResult(
          status: false,
          message:
              "Server error (${response.statusCode}). Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == 'success';
      final msg = (json['message'] as String?) ??
          (ok ? 'Status updated successfully.' : 'Update failed.');
      final newStatus = json['booking_status'] as String?;

      return UpdateStatusResult(
          status: ok, message: msg, bookingStatus: newStatus);
    } on SocketException {
      return const UpdateStatusResult(
        status: false,
        message: 'No internet connection. Please check your network.',
      );
    } on HttpException {
      return const UpdateStatusResult(
        status: false,
        message: 'Could not reach the server.',
      );
    } catch (e) {
      return UpdateStatusResult(
        status: false,
        message: 'Something went wrong: $e',
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

  /// Update the [end_date] of an existing reserved slot.
  /// [reference] should be in the format "G7-AP-05".
  /// [endDate] should be formatted as "YYYY-MM-DD".
  static Future<UpdateSlotResult> updateReservedSlot({
    required String reference,
    required String endDate,
  }) async {
    final ref = reference.trim().toUpperCase();

    if (ref.isEmpty) {
      return const UpdateSlotResult(
        status: false,
        message: "Please enter a reference number.",
      );
    }

    if (!isValidReference(ref)) {
      return const UpdateSlotResult(
        status: false,
        message: "Invalid reference format. Expected format: G7-AP-05",
      );
    }

    if (endDate.isEmpty) {
      return const UpdateSlotResult(
        status: false,
        message: "Please select a new end date.",
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(_updateSlotUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'reference_number': ref,
              'end_date': endDate,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return UpdateSlotResult(
          status: false,
          message: "Server error (${response.statusCode}). Please try again.",
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final ok = json['status'] == true;
      final msg = (json['message'] as String?) ?? (ok ? 'Updated successfully' : 'Update failed');

      return UpdateSlotResult(status: ok, message: msg);
    } on SocketException {
      return const UpdateSlotResult(
        status: false,
        message: "No internet connection. Please check your network.",
      );
    } on HttpException {
      return const UpdateSlotResult(
        status: false,
        message: "Could not reach the server.",
      );
    } catch (e) {
      return UpdateSlotResult(
        status: false,
        message: "Something went wrong: $e",
      );
    }
  }
}
