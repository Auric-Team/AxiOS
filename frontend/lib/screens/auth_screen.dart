import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_text_field.dart';
import 'admin/admin_dashboard_screen.dart';
import 'user_key_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final DownloadService _downloadService = DownloadService();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = ConfigService().backendUrl;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final String server = _serverController.text.trim();
    final String user = _usernameController.text.trim();
    final String pass = _passwordController.text;

    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() {
        _errorMessage = 'All fields are required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await ConfigService().setBackendUrl(server);

    if (_isLoginMode) {
      final res = await _downloadService.login(
        backendUrl: server,
        username: user,
        password: pass,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (res['success'] == true && res['token'] != null) {
        await ConfigService().setToken(res['token'] as String);
        await ConfigService().setUsername(user);
        final role = res['role'] as String;

        if (!mounted) return;
        if (role == 'admin') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const AdminDashboardScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (ctx) => const UserKeyScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Login failed.';
        });
      }
    } else {
      final res = await _downloadService.register(
        backendUrl: server,
        username: user,
        password: pass,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (res['success'] == true) {
        setState(() {
          _isLoginMode = true;
          _errorMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration completed. Please log in!'),
            backgroundColor: Color(0xFF00FFCC),
          ),
        );
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Registration failed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06090F), Color(0xFF0B0F19)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Cyber Badge
                GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _showServerConfig = !_showServerConfig;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_showServerConfig
                            ? 'Server configuration unlocked.'
                            : 'Server configuration locked.'),
                        backgroundColor: const Color(0xFF00FFCC),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBD00FF).withAlpha((255 * 0.4).round()),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.vpn_key_sharp, color: Colors.black, size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AxiOS Terminal',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PERSISTENT SYSTEM ENCRYPTION KEY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 32),

                // Main Auth Panel
                CyberCard(
                  borderGlowColors: const [Color(0x33BD00FF), Color(0x3300FFCC)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Segmented Tab Selector
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF030508),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1E293B), width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isLoginMode = true;
                                  _errorMessage = '';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: _isLoginMode
                                        ? const LinearGradient(
                                            colors: [Color(0xFF00FFCC), Color(0xAA00FFCC)],
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'SIGN IN',
                                    style: TextStyle(
                                      color: _isLoginMode ? Colors.black : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _isLoginMode = false;
                                  _errorMessage = '';
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: !_isLoginMode
                                        ? const LinearGradient(
                                            colors: [Color(0xFFBD00FF), Color(0xAABD00FF)],
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'REGISTER',
                                    style: TextStyle(
                                      color: !_isLoginMode ? Colors.white : const Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Backend URL Input
                      if (_showServerConfig) ...[
                        CyberTextField(
                          controller: _serverController,
                          label: 'HOST SERVER URL',
                          prefixIcon: Icons.lan,
                          focusColor: const Color(0xFFBD00FF),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Username Input
                      CyberTextField(
                        controller: _usernameController,
                        label: 'SECURITY ACCOUNT',
                        prefixIcon: Icons.account_circle_outlined,
                      ),
                      const SizedBox(height: 12),

                      // Password Input
                      CyberTextField(
                        controller: _passwordController,
                        label: 'SECURITY ACCESS KEY',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Action Button
                      _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                          : CyberButton(
                              text: _isLoginMode ? 'INITIATE CONNECTION' : 'CREATE CREDENTIALS',
                              onPressed: _submitAuth,
                              gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
