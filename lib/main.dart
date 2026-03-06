import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/dashboard_state.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/mqtt_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.web,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => MqttService()),
        ChangeNotifierProxyProvider3<AuthService, FirestoreService, MqttService, DashboardState>(
          create: (_) => DashboardState(null, null, null),
          update: (_, auth, firestore, mqtt, previous) => DashboardState(auth, firestore, mqtt),
        ),
      ],
      child: const SmartHomeApp(),
    ),
  );
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home Dashboard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent, // Background will show
        primaryColor: const Color(0xFFFFD54F), // Bright Yellow
        cardColor: const Color(0xFF4A4440), // Earthy Dark Grey base
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme), // Clean, rounder font
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD54F),
          surface: Colors.transparent, 
        ),
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, _) {
          return StreamBuilder(
            stream: authService.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
