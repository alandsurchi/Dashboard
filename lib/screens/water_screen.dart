import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import '../widgets/custom_card.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final ApiService _apiService = ApiService();
  
  // Mock Data
  double moistureLevel = 0.38; // 38%
  double tankLevel = 0.75; // 75%
  bool isPumpActive = false;
  bool isAutoWatering = true;
  int outsideTemp = 23;

  void _togglePump() {
    setState(() {
      isPumpActive = !isPumpActive;
    });
    _apiService.sendCommand(AppConstants.gardenIP, isPumpActive ? "/on" : "/off");
  }

  @override
  Widget build(BuildContext context) {
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
            Text("Smart Water System", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
            Text("Efficient irrigation and water tracking", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(20),
         child: Column(
           children: [
             // 1. Soil Moisture
             CustomCard(
               padding: const EdgeInsets.all(20),
               child: Column(
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(
                         children: [
                           const Icon(Icons.grass, color: Colors.green),
                            const SizedBox(width: 10),
                           Text("Soil Moisture", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                         ],
                       ),
                       Text("${(moistureLevel * 100).toInt()}%", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.green)),
                     ],
                   ),
                   const SizedBox(height: 15),
                   ClipRRect(
                     borderRadius: BorderRadius.circular(10),
                     child: LinearProgressIndicator(
                       value: moistureLevel,
                       minHeight: 20,
                       backgroundColor: Colors.grey[200],
                       color: Colors.green,
                     ),
                   ),
                   const SizedBox(height: 10),
                   Text(
                     moistureLevel < 0.3 ? "DRY - Needs Water" : (moistureLevel > 0.7 ? "WET" : "OPTIMAL"),
                     style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600),
                   )
                 ],
               ),
             ),
             const SizedBox(height: 20),

             Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // 2. Water Tank Level
                 Expanded(
                   child: CustomCard(
                     padding: const EdgeInsets.all(20),
                     child: Column(
                       children: [
                         const Icon(Icons.water_drop, color: Colors.blue, size: 30),
                         const SizedBox(height: 10),
                         Text("Tank Level", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                         Stack(
                           alignment: Alignment.bottomCenter,
                           children: [
                             Container(
                               width: 40,
                               height: 150,
                               decoration: BoxDecoration(
                                 color: Colors.grey[200],
                                 borderRadius: BorderRadius.circular(20),
                               ),
                             ),
                             Container(
                               width: 40,
                               height: 150 * tankLevel,
                               decoration: BoxDecoration(
                                 color: Colors.blue,
                                 borderRadius: BorderRadius.circular(20),
                               ),
                             ),
                           ],
                         ),
                         const SizedBox(height: 10),
                         Text("${(tankLevel * 100).toInt()}% Full", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.blue)),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 20),
                 
                 Expanded(
                   child: Column(
                     children: [
                       // 3. Water Pump Control
                        CustomCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.waves, color: Colors.indigo, size: 30),
                              const SizedBox(height: 10),
                              Text("Pump Control", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _togglePump,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isPumpActive ? Colors.green : Colors.grey,
                                  shape: const CircleBorder(),
                                  padding: const EdgeInsets.all(20),
                                ),
                                child: const Icon(Icons.power_settings_new, color: Colors.white, size: 30),
                              ),
                              const SizedBox(height: 5),
                              Text(isPumpActive ? "ACTIVE" : "OFF", style: GoogleFonts.poppins(color: isPumpActive ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. Temperature Display
                        CustomCard(
                          child: Column(
                            children: [
                              const Icon(Icons.wb_sunny, color: Colors.orange),
                              const SizedBox(height: 5),
                              Text("$outsideTemp°C", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                              Text("Outside", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        )
                     ],
                   ),
                 )
               ],
             ),
             const SizedBox(height: 20),

             // 4. Auto-Watering
             CustomCard(
               child: ListTile(
                 leading: const Icon(Icons.smart_toy, color: Colors.teal),
                 title: Text("Auto-Watering", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                 subtitle: Text("Waters when moisture < 30%", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                 trailing: Switch(
                   value: isAutoWatering, 
                   onChanged: (val) => setState(() => isAutoWatering = val),
                   activeTrackColor: Colors.teal,
                 ),
               ),
             )
           ],
         ),
      ),
    );
  }
}
