import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/dashboard_state.dart';
import '../services/voice_command_service.dart';
import 'home_control_screen.dart';
import 'smart_garage_screen.dart'; 
import 'smart_garden_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final VoiceCommandService _voiceCommandService = VoiceCommandService();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  bool _handledCurrentSpeechSession = false;
  String _lastExecutedNormalized = '';

  final List<Widget> _pages = [
    const HomeControlScreen(),
    const SmartGarageScreen(), 
    const SmartGardenScreen(),
  ];

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _ensureSpeechReady() async {
    if (_speechAvailable) return;

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _executeRecognizedFallbackIfNeeded();
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        _showVoiceMessage('Voice error: ${error.errorMsg}');
      },
    );

    if (!mounted) return;

    setState(() {
      _speechAvailable = available;
    });

    if (!available) {
      _showVoiceMessage('Voice assistant is not available on this device/browser.');
    }
  }

  Future<void> _toggleListening() async {
    await _ensureSpeechReady();
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      return;
    }

    setState(() {
      _lastRecognizedWords = '';
      _handledCurrentSpeechSession = false;
    });

    _lastExecutedNormalized = '';

    await _speech.listen(
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _lastRecognizedWords = result.recognizedWords;
        });

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _executeVoiceCommandIfNeeded(result.recognizedWords);
        }
      },
    );

    if (!mounted) return;
    setState(() => _isListening = _speech.isListening);
  }

  void _executeVoiceCommand(String transcript) {
    final dashboardState = context.read<DashboardState>();
    final message = _voiceCommandService.executeCommand(transcript, dashboardState);
    _showVoiceMessage(message);
  }

  void _executeVoiceCommandIfNeeded(String transcript) {
    final normalized = transcript.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (_handledCurrentSpeechSession && _lastExecutedNormalized == normalized) return;

    _handledCurrentSpeechSession = true;
    _lastExecutedNormalized = normalized;
    _executeVoiceCommand(transcript);
  }

  void _executeRecognizedFallbackIfNeeded() {
    final text = _lastRecognizedWords.trim();
    if (text.isEmpty) return;
    if (_handledCurrentSpeechSession) return;
    _executeVoiceCommandIfNeeded(text);
  }

  void _showVoiceMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFFFD54F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2E2622), // Deep dark brown fallback
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?ixlib=rb-4.0.3&auto=format&fit=crop&w=2000&q=80'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken), // Darken the image heavily
        ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            // Solid Sidebar matches Image 2
            if (!isMobile)
              _buildSidebar(),
            
            // Main Content Area
            Expanded(
              child: _pages[_currentIndex],
            ),
          ],
        ),
        
        // Drawer for mobile devices
        drawer: isMobile ? Drawer(
          backgroundColor: const Color(0xFF3E352F),
          child: Column(
            children: [
              _buildSidebarHeader(),
              ..._buildSidebarItems(),
            ],
          ),
        ) : null,

        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'voice-fab',
              backgroundColor: _isListening ? Colors.redAccent : Theme.of(context).primaryColor,
              tooltip: _lastRecognizedWords.isEmpty
                  ? (_isListening ? 'Listening...' : 'Voice command')
                  : _lastRecognizedWords,
              onPressed: _toggleListening,
              child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.black),
            ),
            if (isMobile) ...[
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'menu-fab',
                backgroundColor: Theme.of(context).primaryColor,
                tooltip: 'Menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(Icons.menu, color: Colors.black),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: const Color(0xFF3E352F), // Solid dark gray/brown from Image 2
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 20),
          ..._buildSidebarItems(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "v1.0 - Smart Dashboard",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle)),
              const SizedBox(width: 12),
              const Text("SmartHome", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "IOT DASHBOARD",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSidebarItems() {
    return [
      _buildNavItem(0, "Home Control", Icons.home_outlined),
      const SizedBox(height: 8),
      _buildNavItem(1, "Smart Garage", Icons.garage_outlined),
      const SizedBox(height: 8),
      _buildNavItem(2, "Smart Garden", Icons.eco_outlined),
    ];
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    bool isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
            // Only mobile has a drawer — close it if we're on mobile screen
            if (MediaQuery.of(context).size.width <= 800) {
              Navigator.of(context).pop();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent, // Subtle highlight
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? primaryColor : Colors.white54, size: 20),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? primaryColor : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

