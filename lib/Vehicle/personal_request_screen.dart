import 'dart:math';
import 'package:flutter/material.dart';
import '../Services/vehicle_api_service.dart';
import '../Leaves/top_banner.dart';
import '../Services/api_service.dart';
import '../ui/dialogs/vehicle_reject_dialog.dart';
import '../ui/dialogs/vehicle_approve_dialog.dart';

class PersonalRequestScreen extends StatefulWidget {
  final String managerId;
  const PersonalRequestScreen({super.key, required this.managerId});

  @override
  State<PersonalRequestScreen> createState() => _PersonalRequestScreenState();
}

class _PersonalRequestScreenState extends State<PersonalRequestScreen> {
  List<Map<String, dynamic>> requests = [];
  bool loading = true;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadManagerVehicleRequests();
  }

  Future<void> _loadManagerVehicleRequests() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final data = await VehicleApiService.fetchManagerPersonalRequests(
        managerId: widget.managerId,
      );
      setState(() {
        requests = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        errorText = e.toString();
        loading = false;
      });
    }
  }

  final Map<int, Future<Map<String, dynamic>?>> _photoFutureCache = {};

    Future<Map<String, dynamic>?> _getPhotoFuture(int employeeId) {
      return _photoFutureCache.putIfAbsent(
        employeeId,
        () => ApiService.getProfilePhoto(employeeId: employeeId),
      );
    }

  // ====================== REJECT POPUP (delegated to dialog file) ======================
  Future<void> _showRejectDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(
      (r["request_id"] ?? r["id"] ?? "0").toString(),
    );

    await showVehicleRejectDialog(
      context: context,
      initialNote: "",
      onReject: (comment) async {
        try {
          await VehicleApiService.rejectVehicleRequest(
            requestId: requestId,
            comment: comment,
          );

          await _loadManagerVehicleRequests();

          if (mounted) {
            TopBanner.show(
              context,
              title: "Reject Request",
              message: "Vehicle request rejected successfully.",
              icon: Icons.cancel,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Reject failed: $e")),
            );
          }
        }
      },
    );
  }

  String _generateTripCode(String employeeName) {
    final rnd = Random();
    String cleanName = employeeName
        .replaceAll(RegExp(r'\s+'), '')
        .toUpperCase();
    if (cleanName.length < 4) {
      cleanName = cleanName.padRight(4, 'X');
    }
    final namePart = cleanName.substring(0, 4);
    final numberPart = (1000 + rnd.nextInt(9000)).toString();
    return "#$namePart$numberPart";
  }

  // ====================== APPROVE POPUP (delegated to dialog file) ======================
  Future<void> _showApproveDialog(BuildContext context, Map<String, dynamic> r) async {
    final requestId = int.parse(r["request_id"].toString());
    final employeeName = (r["employee_name"] ?? r["employeeName"] ?? "USER").toString();
    final code = _generateTripCode(employeeName);

    await showVehicleApproveDialog(
      context: context,
      employeeName: employeeName,
      onApprove: () async {
        try {
          await VehicleApiService.approveVehicleRequest(
            requestId: requestId,
          );

          await _loadManagerVehicleRequests();

          if (mounted) {
            TopBanner.show(
              context,
              title: "Request Approved",
              message: "Vehicle request approved successfully. Trip Code: $code",
              icon: Icons.check_circle,
              isSuccess: true,
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Approve failed: $e")),
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;
    final pad = isTablet ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Personal Vehicle Requests"),
        foregroundColor: Colors.black,
        elevation: 0.6,
      ),
      body: RefreshIndicator(
        onRefresh: _loadManagerVehicleRequests,
        color: Colors.blue,
        backgroundColor: Colors.white,
        strokeWidth: 2,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(pad),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Colors.blue, 
                    backgroundColor: Colors.white),
                ),
              )
            else if (errorText != null)
              Column(
                children: [
                  Text(errorText!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _loadManagerVehicleRequests,
                    child: const Text("Retry"),
                  ),
                ],
              )
            else if (requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: Text("No vehicle requests")),
              )
            else
              ...requests.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _VehicleRequestCard(
                      data: r,
                      onReject: () => _showRejectDialog(context, r),
                      onApprove: () => _showApproveDialog(context, r),
                      getPhoto: _getPhotoFuture,

                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ====================== CARD UI ======================
class _VehicleRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final Future<Map<String, dynamic>?> Function(int employeeId) getPhoto;


  const _VehicleRequestCard({
    required this.data,
    required this.onReject,
    required this.onApprove,
    required this.getPhoto,

  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w > 600;

    final employeeName = (data["employee_name"] ?? data["employeeName"] ?? "").toString();
    final employeeCode = (data["employee_code"] ?? data["employeeId"] ?? "").toString();
    final jobTitle = (data["job_title_name"] ?? data["position"] ?? "").toString();

    final vehicleNo = (data["vehicle_no"] ?? data["vehicleNo"] ?? "").toString();
    final reason = (data["type"] ?? data["reason"] ?? "Office Service").toString();

    final fromDate = (data["from_date"] ?? data["fromDate"] ?? "").toString();
    final toDate = (data["to_date"] ?? data["toDate"] ?? "").toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final int empId = int.tryParse((data["employee_id"] ?? data["employeeId"] ?? "0").toString()) ?? 0;
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: empId > 0 ? getPhoto(empId) : Future.value(null),
                    builder: (context, snap) {
                      final url = (snap.data?["fileUrl"] ?? "").toString().trim();

                      if (snap.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEAF1FF),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            backgroundColor: Colors.white,
                            strokeWidth: 2
                            ),
                          ),
                        );
                      }

                      if (url.isNotEmpty) {
                        return CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFEAF1FF),
                          backgroundImage: NetworkImage(url),
                        );
                      }

                      return const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFEAF1FF),
                        child: Icon(Icons.person, color: Color(0xFF1E88E5)),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employeeName,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.black),
                          ),
                        ),
                        // WAITING badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFE08A)),
                          ),
                          child: const Text(
                            "WAITING",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF8A5A00),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$jobTitle\nEmployee ID: $employeeCode",
                      style: const TextStyle(
                        color: Color(0xFF6B7A90),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // details box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E6EF)),
            ),
            child: Column(
              children: [
                _detailRow("Vehicle No", vehicleNo),
                const SizedBox(height: 8),
                _detailRow("Reason", reason),
                const SizedBox(height: 8),
                _detailRow("From date", fromDate),
                const SizedBox(height: 8),
                _detailRow("To date", toDate),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD10A0A), Color(0xFF5B0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Reject",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Approve",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7A90),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2A3A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}