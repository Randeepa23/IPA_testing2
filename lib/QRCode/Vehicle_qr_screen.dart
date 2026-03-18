import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Models/vehicle_q_model.dart';
import '../Services/vehicle_qr_service.dart';

class VehicleQrScreen extends StatefulWidget {
  const VehicleQrScreen({super.key});

  @override
  State<VehicleQrScreen> createState() => _VehicleQrScreenState();
}

class _VehicleQrScreenState extends State<VehicleQrScreen> {
  final TextEditingController lettersController = TextEditingController();
  final TextEditingController numbersController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  VehicleQrData? vehicleData;

  Future<void> fetchVehicleQr() async {
    final letters = lettersController.text.trim().toUpperCase();
    final numbers = numbersController.text.trim();

    if (letters.isEmpty || numbers.isEmpty) {
      setState(() {
        errorMessage = "Please enter vehicle letters and number";
        vehicleData = null;
      });
      return;
    }

    final fullVehicleNo = "$letters-$numbers";

    setState(() {
      isLoading = true;
      errorMessage = null;
      vehicleData = null;
    });

    final result = await VehicleQrService.getVehicleDetails(fullVehicleNo);

    setState(() {
      isLoading = false;

      if (result.status && result.data != null) {
        vehicleData = result.data;
      } else {
        errorMessage = result.message;
      }
    });
  }

  @override
  void dispose() {
    lettersController.dispose();
    numbersController.dispose();
    super.dispose();
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            children: const [
              Icon(
                Icons.qr_code_2_rounded,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                "Vehicle QR Search",
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Enter vehicle number to view existing QR code",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: lettersController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                    LengthLimitingTextInputFormatter(4),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: "Letters",
                    hintText: "ABC",
                    filled: true,
                    fillColor: isDark ? Colors.black12 : const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "-",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: numbersController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: "Number",
                    hintText: "1234",
                    filled: true,
                    fillColor: isDark ? Colors.black12 : const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : fetchVehicleQr,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    )
                  : const Icon(Icons.search, color: Colors.blue),
              label: Text(
                isLoading ? "Searching..." : "Search Vehicle",
                style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    if (vehicleData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_2,
              size: 54,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
            const SizedBox(height: 10),
            Text(
              "Search a vehicle to view QR code",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            vehicleData!.vehicleNumber,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vehicleData!.companyName,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black12),
            ),
            child: Image.network(
              vehicleData!.image,
              width: 275,
              height: 275,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 275,
                  height: 275,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) {
                return const SizedBox(
                  width: 275,
                  height: 275,
                  child: Center(
                    child: Text(
                      "Unable to load QR image",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle QR Code"),
        centerTitle: true,
      ),
      backgroundColor: isDark ? const Color(0xFF121212) : const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputCard(isDark),
            const SizedBox(height: 18),
            if (!isLoading) _buildResultCard(isDark),
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}