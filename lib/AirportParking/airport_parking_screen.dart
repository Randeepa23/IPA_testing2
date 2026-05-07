import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Services/airport_parking_service.dart';
import 'invoice_pdf_viewer_screen.dart';

class AirportParkingScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AirportParkingScreen({super.key, required this.user});

  @override
  State<AirportParkingScreen> createState() => _AirportParkingScreenState();
}

class _AirportParkingScreenState extends State<AirportParkingScreen> {
  final TextEditingController gNumberController = TextEditingController();
  final TextEditingController apNumberController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  File? invoiceFile;
  String? loadedReference;

  static const _blue1 = Color(0xFF1565C0);
  static const _blue2 = Color(0xFF003580);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);

  @override
  void dispose() {
    gNumberController.dispose();
    apNumberController.dispose();
    super.dispose();
  }

  String get _composedReference {
    final g = gNumberController.text.trim();
    final ap = apNumberController.text.trim();
    return "G$g-AP-$ap";
  }

  Future<void> _fetchInvoice() async {
    final g = gNumberController.text.trim();
    final ap = apNumberController.text.trim();

    if (g.isEmpty || ap.isEmpty) {
      setState(() {
        errorMessage = "Please fill in both reference parts.";
        invoiceFile = null;
        loadedReference = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      invoiceFile = null;
      loadedReference = null;
    });

    final reference = _composedReference;
    final result = await AirportParkingService.fetchInvoice(reference);

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (result.status && result.file != null) {
        invoiceFile = result.file;
        loadedReference = reference;
      } else {
        errorMessage = result.message;
      }
    });

    if (result.status && result.file != null && mounted) {
      // Open the fullscreen viewer right after a successful fetch so the
      // user can see the invoice immediately, then return to this screen
      // where the preview tile remains available for re-opening.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openFullScreen();
      });
    }
  }

  void _openFullScreen() {
    if (invoiceFile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoicePdfViewerScreen(
          file: invoiceFile!,
          reference: loadedReference ?? "",
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  SEARCH INPUT CARD
  // ──────────────────────────────────────────────
  Widget _buildInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_parking_rounded,
                color: Colors.black,
                size: 44,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Airport Parking Invoice",
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Search by reference number to view invoice",
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 8),

          const Text(
            "Enter Reference Number",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),

          const SizedBox(height: 16),

          // Reference parts: G[number] - AP - [number]
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: gNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Group No.",
                    hintText: "7",
                    prefixText: "G",
                    prefixStyle: const TextStyle(
                      color: _blue2,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _blue1, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "– AP –",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textMuted.withOpacity(0.85),
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: apNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    labelText: "Invoice No.",
                    hintText: "05",
                    labelStyle:
                        const TextStyle(color: _textMuted, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _blue2, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "Example: G7-AP-05",
              style: TextStyle(
                fontSize: 11.5,
                color: _textMuted.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Search button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLoading
                    ? [
                        const Color(0xFF1565C0).withOpacity(0.5),
                        const Color(0xFF003580).withOpacity(0.5),
                      ]
                    : const [Color(0xFF1565C0), Color(0xFF003580)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _fetchInvoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "View Invoice",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  ERROR CARD
  // ──────────────────────────────────────────────
  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  EMPTY STATE CARD
  // ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 34,
              color: _blue2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "No Invoice Yet",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Enter a reference number above and\ntap View Invoice to load your PDF.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFFC107).withOpacity(0.45)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF8A2C00),
                  size: 22,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Notice: Reference numbers must be in the format G{n}-AP-{n}, for example G7-AP-05.",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF8A2C00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  //  RESULT CARD (with tappable PDF tile)
  // ──────────────────────────────────────────────
  Widget _buildResultCard() {
    final fileSize = _formatFileSize(_safeFileSize(invoiceFile));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_blue1, _blue2]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loadedReference ?? "",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      const Text(
                        "Airport Parking Invoice",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Ready",
                    style: TextStyle(
                      color: _blue2,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // PDF preview tile — tappable
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: InkWell(
              onTap: _openFullScreen,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue1, _blue2],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _blue2.withOpacity(0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${loadedReference ?? "invoice"}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "PDF Document · $fileSize",
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: _blue2,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // View button
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF003580)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _openFullScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "View Invoice",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _safeFileSize(File? file) {
    try {
      return file?.lengthSync() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "—";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
  }

  // ──────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Airport Parking",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputCard(),
            const SizedBox(height: 16),
            if (!isLoading) ...[
              if (errorMessage != null) _buildErrorCard(),
              if (errorMessage == null && invoiceFile == null)
                _buildEmptyState(),
              if (invoiceFile != null) _buildResultCard(),
            ],
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: CircularProgressIndicator(
                    color: _blue2,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
