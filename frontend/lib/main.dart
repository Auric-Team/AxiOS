import 'package:flutter/material.dart';
import 'screens/initial_router_screen.dart';

void main() {
  runApp(const AxiOSInstallerApp());
}

class AxiOSInstallerApp extends StatelessWidget {
  const AxiOSInstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AxiOS Payload Deployer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF06090F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFCC),
          secondary: Color(0xFFBD00FF),
          surface: Color(0xFF0B0F19),
          error: Color(0xFFFF2A6D),
        ),
      ),
      home: const InitialRouterScreen(),
    );
  }
}
