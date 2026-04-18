import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_state.dart';
import '../widgets/custom_card.dart';

class SmartGardenScreen extends StatelessWidget {
  const SmartGardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.eco, color: Colors.green, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('Smart Garden', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              ],
            ),
            const Text('Automated Garden Management', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Live Stats", Icons.dashboard_outlined),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildCircularStatCard("Soil Moisture", state.soilMoisture.toInt(), "%", Colors.greenAccent)),
                const SizedBox(width: 16),
                Expanded(child: _buildSmokeStatusCard(state)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildClimateCard(state)),
                const SizedBox(width: 16),
                Expanded(child: _buildTankCard(state)),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionHeader("Garden Irrigation", Icons.cloud_outlined),
            const SizedBox(height: 16),
            _buildIrrigationControls(state),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildCircularStatCard(String title, int value, String unit, Color color) {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("$value", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.water_drop_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildClimateCard(DashboardState state) {
    final double displayTemp = state.temperature;
    final int displayHumidity = state.humidity;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            const Icon(Icons.thermostat, color: Colors.redAccent, size: 20),
            const SizedBox(height: 8),
            Text("${displayTemp.toStringAsFixed(1)}°C", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Temperature", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(color: Colors.white12),
            ),
            const Icon(Icons.water_drop_outlined, color: Colors.blueAccent, size: 20),
            const SizedBox(height: 8),
            Text("$displayHumidity%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Humidity", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmokeStatusCard(DashboardState state) {
    final isHigh = state.smokeLevel.toUpperCase() == 'HIGH';
    final color = isHigh ? Colors.redAccent : Colors.greenAccent;

    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: isHigh ? 1.0 : 0.2,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Text(
                      state.smokeLevel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                const Text("Smoke Level", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTankCard(DashboardState state) {
    return CustomCard(
      child: Column(
        children: [
          const Text("Tank Level", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          Container(
            height: 120,
            width: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 120 * (state.tankLevel / 100),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade400,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(6), bottomRight: Radius.circular(6)),
              ),
              child: Center(
                child: Text("${state.tankLevel.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Icon(Icons.water_drop_outlined, color: Colors.blueAccent, size: 20),
        ],
      ),
    );
  }

  Widget _buildIrrigationControls(DashboardState state) {
    return CustomCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(Icons.power_settings_new, color: Colors.greenAccent, size: 18),
                SizedBox(width: 12),
                Text("Irrigation Controls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          _buildControlRow(
            "Garden Water Pump", 
            state.gardenPumpRunning, 
            (val) => state.toggleGardenPump(val), 
            statusText: state.gardenPumpRunning ? "Running" : "Stopped"
          ),
          const Divider(height: 1, color: Colors.white12),
          _buildControlRow(
            "Fire System Pump", 
            state.firePumpRunning, 
            (val) => state.toggleFirePump(val), 
            statusText: state.firePumpRunning ? "Running" : "Stopped", 
            activeColor: Colors.redAccent
          ),
          const Divider(height: 1, color: Colors.white12),
          _buildControlRow(
            "Auto Mode", 
            state.autoGardenMode, 
            (val) => state.toggleAutoGardenMode(val), 
            activeColor: Colors.amber
          ),
          const Divider(height: 1, color: Colors.white12),
          _buildControlRow(
            "Emergency Stop", 
            !state.systemEnabled, 
            (val) => state.toggleSystemEnabled(!val), 
            statusText: state.systemEnabled ? "Safe" : "STOPPED",
            activeColor: Colors.redAccent
          ),
          const Divider(height: 1, color: Colors.white12),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Auto: Pumps run dynamically based on smart schedules & sensors. Manual overrides will disable Auto Mode.",
              style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(String title, bool value, Function(bool) onChanged, {String? statusText, Color? activeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              if (statusText != null) ...[
                Text(statusText, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 12),
              ],
              Switch(
                value: value,
                activeColor: activeColor ?? Colors.greenAccent,
                onChanged: onChanged,
              ),
            ],
          )
        ],
      ),
    );
  }
}
