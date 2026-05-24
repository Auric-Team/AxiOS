import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import '../widgets/common/cyber_card.dart';
import '../widgets/common/cyber_button.dart';
import '../widgets/common/cyber_text_field.dart';
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
      body: Stack(
        children: [
          // Background Gradient with high-tech mesh elements
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF030712), Color(0xFF0B1528), Color(0xFF020617)],
              ),
            ),
          ),
          
          // Glow Background Effects
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBD00FF).withAlpha(35),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FFCC).withAlpha(25),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Cyber Badge with long-press action to toggle Server URL setup
                    GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _showServerConfig = !_showServerConfig;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_showServerConfig
                                ? 'Host config panel activated.'
                                : 'Host config panel hidden.'),
                            backgroundColor: const Color(0xFF00FFCC),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FFCC).withAlpha(80),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.black,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'AxiOS Terminal',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SECURE LOGISTICS ENVELOPE DEPLOYER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Main Auth Panel
                    CyberCard(
                      borderGlowColors: const [Color(0xFFBD00FF), Color(0xFF00FFCC)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Segmented Tab Selector
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF02040A),
                              borderRadius: BorderRadius.circular(14),
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
                                        color: _isLoginMode ? const Color(0xFF00FFCC) : Colors.transparent,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'SIGN IN',
                                        style: TextStyle(
                                          color: _isLoginMode ? Colors.black : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.5,
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
                                        color: !_isLoginMode ? const Color(0xFFBD00FF) : Colors.transparent,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'REGISTER',
                                        style: TextStyle(
                                          color: !_isLoginMode ? Colors.white : const Color(0xFF64748B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Backend URL Input
                          if (_showServerConfig) ...[
                            CyberTextField(
                              controller: _serverController,
                              label: 'BACKEND IP / HOST',
                              prefixIcon: Icons.dns_outlined,
                              focusColor: const Color(0xFFBD00FF),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Username Input
                          CyberTextField(
                            controller: _usernameController,
                            label: 'OPERATOR USERNAME',
                            prefixIcon: Icons.alternate_email_outlined,
                            focusColor: _isLoginMode ? const Color(0xFF00FFCC) : const Color(0xFFBD00FF),
                          ),
                          const SizedBox(height: 14),

                          // Password Input
                          CyberTextField(
                            controller: _passwordController,
                            label: 'SECURITY SYNC KEY',
                            obscureText: true,
                            prefixIcon: Icons.fingerprint_outlined,
                            focusColor: _isLoginMode ? const Color(0xFF00FFCC) : const Color(0xFFBD00FF),
                          ),
                          
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2A6D).withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFF2A6D).withAlpha(50)),
                              ),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Action Button
                          _isLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10.0),
                                    child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                                  ),
                                )
                              : CyberButton(
                                  text: _isLoginMode ? 'CONNECT TERMINAL' : 'ESTABLISH CREDENTIALS',
                                  onPressed: _submitAuth,
                                  gradientColors: _isLoginMode 
                                      ? const [Color(0xFF00FFCC), Color(0xFF05BFA0)]
                                      : const [Color(0xFFBD00FF), Color(0xFF7B00C7)],
                                  textColor: _isLoginMode ? Colors.black : Colors.white,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
