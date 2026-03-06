import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_state.dart';
import '../widgets/custom_card.dart';

class EnergyScreen extends StatelessWidget {
  const EnergyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
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
            Text("Energy Optimization", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
            Text("Monitor and control home energy usage", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Status Overview
            Row(
              children: [
                Expanded(child: _buildStatusCard("Temperature", "${state.temperature.toStringAsFixed(1)}°C", Icons.thermostat, Colors.orangeAccent)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatusCard("Energy Mode", "Normal", Icons.bolt, Colors.blueAccent)),
                const SizedBox(width: 15),
                Expanded(child: _buildStatusCard("Motion", state.motionDetected ? "Yes" : "No", Icons.directions_walk, state.motionDetected ? Colors.redAccent : Colors.green)),
              ],
            ),
            const SizedBox(height: 30),

            // 2. Room Light Controls
            Text("Room Light Controls", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            CustomCard(
              child: Column(
                children: [
                   _buildLightControl("Main Light (L1)", state.led1On, (val) => state.toggleLed1(val)),
                   const Divider(),
                   _buildLightControl("Ambient Light (L2)", state.led2On, (val) => state.toggleLed2(val)),
                   const Divider(),
                   _buildLightControl("Reading Light (L3)", state.led3On, (val) => state.toggleLed3(val)),
                ],
              ),
            ),
             const SizedBox(height: 30),

            // 3. Fan Automation
             Text("Fan Automation", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 15),
              CustomCard(
               child: Column(
                 children: [
                   Row(
                     children: [
                       const Icon(Icons.cyclone, size: 40, color: Colors.teal),
                       const SizedBox(width: 15),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text("Fan Speed", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                             Text("Status: ${state.fanOn ? 'ON' : 'OFF'}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                           ],
                         ),
                       ),
                       Switch(
                         value: state.fanOn, 
                         onChanged: (val) {
                           state.toggleFan(val);
                         },
                         activeTrackColor: Colors.teal,
                       )
                     ],
                   ),
                   const SizedBox(height: 10),
                   Slider(
                     value: 50, 
                     min: 0, 
                     max: 100, 
                     divisions: 10,
                     label: "50%",
                     activeColor: Colors.teal,
                     onChanged: (val) {},
                   )
                 ],
               ),
             ),
             const SizedBox(height: 30),

             // 4. Power-Saving Automation
             CustomCard(
               color: const Color(0xFFE8F5E9),
               child: Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                     child: const Icon(Icons.eco, color: Colors.green),
                   ),
                   const SizedBox(width: 15),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("Automated Energy Saving", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                         Text("Reduces usage based on motion + time.", style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 12)),
                       ],
                     ),
                   ),
                   Switch(
                     value: false,
                     onChanged: (val) {},
                     activeTrackColor: Colors.green,
                   )
                 ],
               ),
             ),
             const SizedBox(height: 30),

             // 5. Voice Control
             Center(
               child: Column(
                 children: [
                   GestureDetector(
                     onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Listening... (Voice Control Mock)"), duration: Duration(seconds: 1)),
                        );
                     },
                     child: Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: const Color(0xFF6C63FF),
                         shape: BoxShape.circle,
                         boxShadow: [
                           BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))
                         ]
                       ),
                       child: const Icon(Icons.mic, color: Colors.white, size: 40),
                     ),
                   ),
                   const SizedBox(height: 10),
                   Text("Tap to Speak", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w500)),
                 ],
               ),
             ),
             const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return CustomCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(title, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildLightControl(String name, bool isOn, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: isOn ? Colors.orangeAccent : Colors.grey[300]),
          const SizedBox(width: 15),
          Expanded(child: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
          Switch(
            value: isOn, 
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF6C63FF),
          )
        ],
      ),
    );
  }
}
