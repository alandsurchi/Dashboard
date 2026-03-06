import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class GarageScreen extends StatelessWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final isDoorOpen = state.garageStatus == 'OPEN';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
       appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
         leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Garage Automation", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
            Text("Smart access and vehicle intelligence", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Garage Door Control
            CustomCard(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                   Icon(
                    isDoorOpen ? Icons.garage_outlined : Icons.garage, 
                    size: 80, 
                    color: isDoorOpen ? Colors.orange : Colors.blueGrey
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isDoorOpen ? "DOOR OPEN" : "DOOR CLOSED",
                    style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: isDoorOpen ? Colors.orange : Colors.blueGrey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      state.setGarageDoor(!isDoorOpen);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDoorOpen ? Colors.redAccent : Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      isDoorOpen ? "CLOSE DOOR" : "OPEN DOOR", 
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Bluetooth & 3. Car Detection
            Row(
              children: [
                Expanded(
                  child: CustomCard(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        const Icon(Icons.bluetooth, color: Colors.blue, size: 30),
                        const SizedBox(height: 10),
                        Text("Auth Device?", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 5),
                        StatusBadge(
                          label: state.garageBluetoothConnected ? "YES" : "NO", 
                          color: state.garageBluetoothConnected ? Colors.green[100]! : Colors.red[100]!,
                          textColor: state.garageBluetoothConnected ? Colors.green : Colors.red,
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: CustomCard(
                     padding: const EdgeInsets.all(15),
                     child: Column(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.purple, size: 30),
                        const SizedBox(height: 10),
                         Text("Car Detected?", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 5),
                         StatusBadge(
                          label: state.garageCarPresent ? "YES" : "NO", 
                          color: state.garageCarPresent ? Colors.green[100]! : Colors.grey[200]!,
                          textColor: state.garageCarPresent ? Colors.green : Colors.grey,
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
