import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import '../services/key_service.dart';
import '../services/detection_service.dart';
import '../services/launcher_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_text_field.dart';
import '../widgets/cyber_console.dart';
import 'auth_screen.dart';

class UserKeyScreen extends StatefulWidget {
  const UserKeyScreen({super.key});

  @override
  State<UserKeyScreen> createState() => _UserKeyScreenState();
}

class _UserKeyScreenState extends State<UserKeyScreen> {
  final TextEditingController _keyController = TextEditingController();
  final KeyService _keyService = KeyService();
  final DownloadService _downloadService = DownloadService();
  final DetectionService _detectionService = DetectionService();
  final LauncherService _launcherService = LauncherService();

  bool _isValidating = false;
  bool _isDeploying = false;
  double _deployProgress = 0.0;
  String _errorMessage = '';
  final List<String> _consoleLogs = [];

  void _addLog(String msg) {
    setState(() {
      _consoleLogs.add('[${DateTime.now().toLocal().toString().substring(11, 19)}] $msg');
    });
  }

  Future<void> _logout() async {
    await ConfigService().clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
    );
  }

  Future<void> _activateAndDeploy() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Activation key cannot be empty.';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _isDeploying = false;
      _errorMessage = '';
      _consoleLogs.clear();
    });

    _addLog('Contacting validation server...');
    final config = ConfigService();
    final res = await _keyService.verifyKey(
      backendUrl: config.backendUrl,
      key: key,
      username: config.username,
    );

    if (!mounted) return;

    if (res['success'] != true) {
      setState(() {
        _isValidating = false;
        _errorMessage = res['error'] ?? 'Invalid access key.';
      });
      _addLog('Error: Key authentication failed.');
      return;
    }

    final targetPackage = res['targetGame'] as String;
    _addLog('Access key authorized for target: $targetPackage');
    
    setState(() {
      _isValidating = false;
      _isDeploying = true;
    });

    // 1. Check Permissions
    _addLog('Requesting storage management permissions...');
    final hasPerm = await _detectionService.requestStoragePermission();
    if (!hasPerm) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Storage permission denied. Deployment aborted.';
      });
      _addLog('Error: Permission request rejected.');
      return;
    }
    _addLog('Storage permissions granted.');

    // 2. Scan Directory
    _addLog('Scanning storage for package $targetPackage...');
    final gamePath = await _detectionService.detectGameDirectory(targetPackage);
    if (gamePath == null) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Target game directory not found on device.';
      });
      _addLog('Error: Game folders not found. Please install the game first.');
      return;
    }
    _addLog('Target directory detected: $gamePath');

    // 3. Resolve Destination
    final destPath = '$gamePath/${config.subpath}';
    _addLog('Resolved installation subpath: $destPath');

    // 4. Download and deploy
    _addLog('Downloading payload binary...');
    final downloadSuccess = await _downloadService.downloadAndDeploy(
      backendUrl: config.backendUrl,
      targetPath: destPath,
      onProgress: (prog) {
        setState(() {
          _deployProgress = prog;
        });
      },
      onLog: (log) => _addLog(log),
    );

    if (!mounted) return;

    if (!downloadSuccess) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Binary download/deployment failed.';
      });
      return;
    }

    _addLog('Deployment completed successfully. Booting game...');
    
    // 5. Launch Game
    final launched = await _launcherService.launchApp(targetPackage);
    if (!launched) {
      _addLog('Warning: Could not launch app automatically. Please start it manually.');
    } else {
      _addLog('Game launched successfully.');
    }

    setState(() {
      _isDeploying = false;
      _keyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AXIOS SYSTEM ACTIVATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: Color(0xFF00FFCC),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF2A6D)),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              
              // App Logo Branding
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3300FFCC),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.vpn_key_outlined,
                    size: 32,
                    color: Color(0xFF00FFCC),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // UI Info Card
              CyberCard(
                borderGlowColors: const [Color(0x3300FFCC), Color(0x33BD00FF)],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ACTIVATE LICENSE KEY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Access Key Text Field
                    CyberTextField(
                      controller: _keyController,
                      label: 'ENTER LICENSE KEY',
                      prefixIcon: Icons.lock_outline,
                      focusColor: const Color(0xFF00FFCC),
                      enabled: !_isValidating && !_isDeploying,
                    ),
                    
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Action Activation button
                    _isValidating
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                          )
                        : _isDeploying
                            ? Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _deployProgress,
                                    color: const Color(0xFF00FFCC),
                                    backgroundColor: const Color(0xFF0B132B),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'DEPLOYING PAYLOAD: ${(_deployProgress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00FFCC),
                                    ),
                                  ),
                                ],
                              )
                            : CyberButton(
                                text: 'AUTHENTICATE & DEPLOY',
                                onPressed: _activateAndDeploy,
                                gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                              ),
                  ],
                ),
              ),

              if (_consoleLogs.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'SYSTEM TERMINAL FEEDBACK',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                // Custom console log widget
                CyberConsole(
                  logs: _consoleLogs,
                  height: 160,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
