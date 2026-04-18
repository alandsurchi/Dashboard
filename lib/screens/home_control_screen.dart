import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/dashboard_state.dart';
import '../widgets/custom_card.dart';
import '../widgets/status_badge.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeControlScreen extends StatelessWidget {
  const HomeControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  state.solarCharging ? Icons.solar_power : Icons.nightlight,
                  color: state.solarCharging ? Colors.orangeAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('${state.batteryLevel}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.battery_full, color: Colors.green),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClockAndClimateRow(state),
            const SizedBox(height: 16),
            _buildNightModeMaster(state),
            const SizedBox(height: 16),
            const Text("Lighting", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildLedControlsRow(state),
            const SizedBox(height: 16),
            const Text("Appliances", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildAppliancesRow(state),
            const SizedBox(height: 16),
            _buildRgbControlCard(context, state),
            const SizedBox(height: 16),
            const Text("Security & Motion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildSecurityRow(state),
            const SizedBox(height: 16),
            const Text("Device Scheduling", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildSchedulingCard(context),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildClockAndClimateRow(DashboardState state) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _format12HourTime(state.currentTime),
                  style: GoogleFonts.shareTechMono(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                Text(
                  _getWeekday(state.currentTime.weekday),
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const StatusBadge(label: "Auto-sync Active", color: Colors.blue, icon: Icons.sync),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: CustomCard(
            child: Column(
              children: [
                const Icon(Icons.thermostat, color: Colors.orange),
                const SizedBox(height: 8),
                Text(
                  state.hasLiveHomeSensorData ? "${state.temperature.toStringAsFixed(1)}°C" : "--.-°C",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text("Temp", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: CustomCard(
            child: Column(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  state.hasLiveHomeSensorData ? "${state.humidity}%" : "--%",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text("Humidity", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNightModeMaster(DashboardState state) {
    return CustomCard(
      color: state.nightMode ? Colors.indigo.withValues(alpha: 0.2) : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode, color: state.nightMode ? Colors.indigoAccent : Colors.grey, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Night Mode", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    state.nightMode ? "Lights off, doors locked" : "System normal",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Switch(
            value: state.nightMode,
            activeColor: Colors.indigoAccent,
            onChanged: (val) => state.toggleNightMode(val),
          )
        ],
      ),
    );
  }

  Widget _buildLedControlsRow(DashboardState state) {
    return Row(
      children: [
        _buildLedToggle("LED 1", state.led1On, state.toggleLed1, state.nightMode, Colors.amber),
        const SizedBox(width: 16),
        _buildLedToggle("LED 2", state.led2On, state.toggleLed2, state.nightMode, Colors.amber),
        const SizedBox(width: 16),
        _buildLedToggle("LED 3", state.led3On, state.toggleLed3, state.nightMode, Colors.amber),
      ],
    );
  }

  Widget _buildLedToggle(String label, bool isOn, Function(bool) onChanged, bool nightMode, Color color) {
    return Expanded(
      child: CustomCard(
        color: isOn ? color.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          children: [
            Icon(Icons.lightbulb, color: isOn ? color : Colors.grey, size: 36),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Switch(
              value: isOn,
              activeColor: color,
              onChanged: nightMode ? null : onChanged,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAppliancesRow(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: _buildAppToggle("Fan", state.fanOn, state.toggleFan, state.nightMode, Colors.blueAccent, Icons.mode_fan_off, Icons.ac_unit),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAppToggle("TV", state.tvOn, state.toggleTv, state.nightMode, Colors.purpleAccent, Icons.tv_off, Icons.tv),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildAppToggle("Washing Machine", state.washOn, state.toggleWash, state.nightMode, Colors.teal, Icons.local_laundry_service_outlined, Icons.local_laundry_service),
        ),
      ],
    );
  }

  Widget _buildAppToggle(String label, bool isOn, Function(bool) onChanged, bool nightMode, Color color, IconData iconOff, IconData iconOn) {
    return CustomCard(
      color: isOn ? color.withValues(alpha: 0.1) : null,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        children: [
          Icon(isOn ? iconOn : iconOff, color: isOn ? color : Colors.grey, size: 36),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Switch(
            value: isOn,
            activeColor: color,
            onChanged: nightMode && label == "TV" ? null : onChanged, // TV disabled in night mode, fan can work
          )
        ],
      ),
    );
  }

  Widget _buildRgbControlCard(BuildContext context, DashboardState state) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: state.rgbOn ? state.rgbColor : Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  const Text("RGB LED", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              Switch(
                value: state.rgbOn,
                activeColor: state.rgbColor,
                onChanged: state.nightMode ? null : (val) => state.toggleRgb(val),
              )
            ],
          ),
          if (state.rgbOn && !state.nightMode) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.rgbColor,
                      foregroundColor: useWhiteForeground(state.rgbColor) ? Colors.white : Colors.black,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          Color pickedColor = state.rgbColor;
                          return AlertDialog(
                            title: const Text('Pick a color'),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                pickerColor: pickedColor,
                                onColorChanged: (Color color) {
                                  pickedColor = color;
                                },
                                pickerAreaHeightPercent: 0.8,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Done'),
                                onPressed: () {
                                  state.setRgbColor(pickedColor);
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Pick Color'),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Icon(Icons.brightness_low, size: 20, color: Colors.grey),
                      Expanded(
                        child: Slider(
                          value: state.rgbBrightness,
                          activeColor: state.rgbColor,
                          onChanged: (val) => state.setRgbBrightness(val),
                        ),
                      ),
                      Text("${(state.rgbBrightness * 100).toInt()}%"),
                    ],
                  ),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSecurityRow(DashboardState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Door Status
        Expanded(
          child: CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Door Control", style: TextStyle(fontWeight: FontWeight.bold)),
                    StatusBadge(
                      label: state.doorStatus,
                      color: state.doorStatus == 'OPEN' ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Icon(
                    state.doorStatus == 'OPEN' ? Icons.door_front_door_outlined : Icons.door_front_door,
                    size: 48,
                    color: state.doorStatus == 'OPEN' ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.2), foregroundColor: Colors.green),
                        onPressed: state.nightMode ? null : () => state.setDoor('OPEN'),
                        child: const Text("OPEN"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.2), foregroundColor: Colors.redAccent),
                        onPressed: state.nightMode ? null : () => state.setDoor('CLOSED'),
                        child: const Text("CLOSE"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.doorLog.isNotEmpty ? state.doorLog.first : "No history",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Motion
        Expanded(
          child: CustomCard(
            child: Column(
              children: [
                const Text("Motion Sensor", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Icon(
                  Icons.directions_walk,
                  size: 48,
                  color: state.motionDetected ? Colors.red : Colors.grey,
                ),
                const SizedBox(height: 20),
                StatusBadge(
                  label: state.motionDetected ? "MOTION DETECTED" : "CLEAR",
                  color: state.motionDetected ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 12),
                if (state.motionDetected)
                  ElevatedButton(
                    onPressed: () {
                      state.clearMotion();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("CLEAR"),
                  ),
                const SizedBox(height: 12),
                Text("Last motion: ${state.lastMotionTime}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (state.nightMode) ...[
                  const SizedBox(height: 8),
                  const Text("⚠️ High Sensitivity", style: TextStyle(fontSize: 12, color: Colors.orange)),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulingCard(BuildContext context) {
    final state = context.watch<DashboardState>();
    
    return CustomCard(
      child: Column(
        children: [
          // Dynamic Schedule Builder Form
          _ScheduleFormBuilder(state: state),
          
          if (state.activeSchedules.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Active Schedules", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
            const SizedBox(height: 12),
            // Display active list
            ...state.activeSchedules.map((schedule) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(schedule.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "${schedule.onTime?.format(context) ?? '--'} - ${schedule.offTime?.format(context) ?? '--'}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => state.removeSchedule(schedule),
                        )
                      ],
                    )
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
      case 6: return "Saturday";
      case 7: return "Sunday";
      default: return "";
    }
  }

  String _format12HourTime(DateTime dt) {
    int hour = dt.hour % 12;
    if (hour == 0) hour = 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }
}

// Stateful widget broken out just for the form to handle temporary form state cleanly
class _ScheduleFormBuilder extends StatefulWidget {
  final DashboardState state;
  const _ScheduleFormBuilder({required this.state});

  @override
  State<_ScheduleFormBuilder> createState() => _ScheduleFormBuilderState();
}

class _ScheduleFormBuilderState extends State<_ScheduleFormBuilder> {
  String selectedDevice = 'LED 1';
  TimeOfDay? selectedOnTime;
  TimeOfDay? selectedOffTime;

  Future<void> _selectTime(BuildContext context, bool isOnTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isOnTime) {
          selectedOnTime = picked;
        } else {
          selectedOffTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Text("Select Device:")),
            DropdownButton<String>(
              value: selectedDevice,
              dropdownColor: const Color(0xFF4A4440),
              underline: const SizedBox(),
              items: <String>['LED 1', 'LED 2', 'LED 3', 'RGB Light', 'Fan', 'TV', 'Washing Machine', 'Garden Pump', 'Fire Pump'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    selectedDevice = val;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text("ON Time", style: TextStyle(color: Colors.grey)),
                TextButton.icon(
                  icon: Icon(Icons.access_time, color: selectedOnTime != null ? Colors.amber : Colors.grey),
                  label: Text(
                    selectedOnTime != null ? selectedOnTime!.format(context) : "Select",
                    style: TextStyle(color: selectedOnTime != null ? Colors.white : Colors.grey),
                  ),
                  onPressed: () => _selectTime(context, true),
                )
              ],
            ),
            const Icon(Icons.arrow_forward, color: Colors.grey),
            Column(
              children: [
                const Text("OFF Time", style: TextStyle(color: Colors.grey)),
                TextButton.icon(
                  icon: Icon(Icons.access_time, color: selectedOffTime != null ? Colors.amber : Colors.grey),
                  label: Text(
                    selectedOffTime != null ? selectedOffTime!.format(context) : "Select",
                    style: TextStyle(color: selectedOffTime != null ? Colors.white : Colors.grey),
                  ),
                  onPressed: () => _selectTime(context, false),
                )
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (selectedOnTime == null && selectedOffTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select at least one time.'), backgroundColor: Colors.redAccent),
                );
                return;
              }
              
              widget.state.addSchedule(DeviceSchedule(
                deviceName: selectedDevice,
                onTime: selectedOnTime,
                offTime: selectedOffTime,
              ));
              
              // Reset
              setState(() {
                selectedOnTime = null;
                selectedOffTime = null;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Schedule created for $selectedDevice'), backgroundColor: Colors.green),
              );
            },
            child: const Text("Save Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }
}

