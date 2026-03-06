import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';

class SmartGarageScreen extends StatelessWidget {
  const SmartGarageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final bool isDisabled = state.garageLocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Garage'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                const Text("Manual Lock"),
                Switch(
                  value: state.garageLocked,
                  activeColor: Colors.redAccent,
                  onChanged: (val) => state.toggleGarageLock(val),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildMainDoorControl(state, isDisabled),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAuthAndDetection(state, context)),
                const SizedBox(width: 16),
                Expanded(child: _buildAutoSettings(state, isDisabled)),
              ],
            ),
            const SizedBox(height: 16),
            _buildHistoryLog(state),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDoorControl(DashboardState state, bool isDisabled) {
    bool isOpen = state.garageStatus == 'OPEN' || state.garageStatus == 'OPENING';
    
    return CustomCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Garage Door", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              StatusBadge(
                label: state.garageStatus,
                color: isOpen ? Colors.green : Colors.red,
                icon: isDisabled ? Icons.lock : null,
              ),
            ],
          ),
          const SizedBox(height: 30),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border(
                top: BorderSide(color: Colors.grey.shade700, width: 4),
                left: BorderSide(color: Colors.grey.shade700, width: 4),
                right: BorderSide(color: Colors.grey.shade700, width: 4),
              ),
            ),
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                // Background interior
                Container(color: Colors.black12),
                // The Door
                AnimatedPositioned(
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                  top: isOpen ? -140 : 0, // Slide up to open
                  left: 0,
                  right: 0,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade800,
                      border: Border.all(color: Colors.blueGrey.shade600),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(4, (index) => Container(
                        height: 2,
                        color: Colors.blueGrey.shade900,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text("OPEN", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.2), 
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isDisabled ? null : () => state.setGarageDoor(true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text("CLOSE", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.2), 
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isDisabled ? null : () => state.setGarageDoor(false),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAuthAndDetection(DashboardState state, BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sensors & Auth", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.bluetooth, color: Colors.blue),
              const SizedBox(width: 12),
              const Expanded(child: Text("Authorized Car Bluetooth")),
              StatusBadge(
                label: state.garageBluetoothConnected ? 'YES' : 'NO',
                color: state.garageBluetoothConnected ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.directions_car, color: state.garageCarPresent ? Colors.green : Colors.grey),
              const SizedBox(width: 12),
              const Expanded(child: Text("Car in front (Ultrasonic)")),
              StatusBadge(
                label: state.garageCarPresent ? 'YES' : 'NO',
                color: state.garageCarPresent ? Colors.amber : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoSettings(DashboardState state, bool isDisabled) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Automation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Auto-Open"),
              Switch(
                value: state.autoOpenGarage,
                activeColor: Colors.blueAccent,
                onChanged: isDisabled ? null : (val) => state.toggleAutoOpenGarage(val),
              )
            ],
          ),
          Text(
            "Requires Bluetooth + Car Detection",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Auto-Close"),
              Switch(
                value: state.autoCloseGarage,
                activeColor: Colors.blueAccent,
                onChanged: (val) => state.toggleAutoCloseGarage(val),
              )
            ],
          ),
          if (state.autoCloseGarage) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: state.autoCloseTimer,
                    min: 10,
                    max: 60,
                    divisions: 5,
                    label: "${state.autoCloseTimer.toInt()}s",
                    onChanged: (val) => state.setAutoCloseTimer(val),
                  ),
                ),
                Text("${state.autoCloseTimer.toInt()}s"),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildHistoryLog(DashboardState state) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Door Status History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (state.garageLog.isEmpty)
            const Text("No recent events", style: TextStyle(color: Colors.grey)),
          ...state.garageLog.map((log) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.grey),
                const SizedBox(width: 12),
                Text(log),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
