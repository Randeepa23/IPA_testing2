import 'package:flutter/material.dart';

class VehicleRequestScreen extends StatefulWidget {
  const VehicleRequestScreen({super.key});

  @override
  State<VehicleRequestScreen> createState() => _VehicleRequestScreenState();
}

class _VehicleRequestScreenState extends State<VehicleRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Text(
          "Vehicle Request Screen",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}