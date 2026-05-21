import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import 'auth_screen.dart';
import 'user_key_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class InitialRouterScreen extends StatefulWidget {
  const InitialRouterScreen({super.key});

  @override
  State<InitialRouterScreen> createState() => _InitialRouterScreenState();
}

class _InitialRouterScreenState extends State<InitialRouterScreen> {
  final DownloadService _downloadService = DownloadService();
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final config = ConfigService();
    await config.init();

    final savedToken = config.token;
    if (savedToken != null && savedToken.isNotEmpty) {
      final verification = await _downloadService.verifyToken(
        backendUrl: config.backendUrl,
        token: savedToken,
      );

      if (!mounted) return;

      if (verification['success'] == true) {
        final role = verification['role'] as String;
        final verifiedUser = verification['username'] as String;
        await config.setUsername(verifiedUser);

        if (!mounted) return;
        if (role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => const AdminDashboardScreen(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => const UserKeyScreen(),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00FFCC)),
              SizedBox(height: 20),
              Text(
                'VERIFYING CONFIG...',
                style: TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const AuthScreen();
  }
}
