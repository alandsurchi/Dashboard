import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_state.dart';
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

  final List<Widget> _pages = [
    const HomeControlScreen(),
    const SmartGarageScreen(), 
    const SmartGardenScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            // Solid Sidebar matches Image 2
            if (MediaQuery.of(context).size.width > 800)
              _buildSidebar(),
            
            // Main Content Area
            Expanded(
              child: _pages[_currentIndex],
            ),
          ],
        ),
        
        // Drawer for mobile devices
        drawer: MediaQuery.of(context).size.width <= 800 ? Drawer(
          backgroundColor: const Color(0xFF3E352F),
          child: Column(
            children: [
              _buildSidebarHeader(),
              ..._buildSidebarItems(),
            ],
          ),
        ) : null,
        
        // Add a floating menu button for mobile
        floatingActionButton: MediaQuery.of(context).size.width <= 800 ? Builder(
          builder: (context) => FloatingActionButton(
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
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
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.pop(context); // Close drawer on mobile
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

