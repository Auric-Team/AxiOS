import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import '../services/key_service.dart';
import '../services/detection_service.dart';
import '../services/launcher_service.dart';
import '../widgets/cyber_card.dart';
import '../widgets/cyber_button.dart';
import '../widgets/cyber_text_field.dart';
import '../widgets/cyber_console.dart';
import '../widgets/pulse_indicator.dart';
import '../models/system_status.dart';
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
  String _downloadSpeed = '0.00 MB/s';
  String _downloadEta = '--:--';
  String _downloadSizeInfo = '0 MB / 0 MB';
  String _errorMessage = '';
  final List<String> _consoleLogs = [];
  bool _showConsoleLogs = true;

  // Connection Diagnostics Status
  int? _serverLatencyMs;
  bool _isCheckingLatency = false;
  SystemStatus? _serverStatus;

  // Stepper Status: 'pending', 'active', 'success', 'failed'
  String _step1Status = 'pending'; // Key Authorization
  String _step2Status = 'pending'; // Storage Permissions
  String _step3Status = 'pending'; // Target Path Detection
  String _step4Status = 'pending'; // Binary Streaming
  String _step5Status = 'pending'; // Game Booting

  @override
  void initState() {
    super.initState();
    _measureLatency();
  }

  Future<void> _measureLatency() async {
    if (_isCheckingLatency) return;
    setState(() {
      _isCheckingLatency = true;
    });
    try {
      final config = ConfigService();
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final statusJson = await _downloadService.checkStatus(config.backendUrl);
      final endTime = DateTime.now().millisecondsSinceEpoch;
      if (statusJson != null && mounted) {
        setState(() {
          _serverLatencyMs = endTime - startTime;
          _serverStatus = SystemStatus.fromJson(statusJson);
        });
      } else if (mounted) {
        setState(() {
          _serverLatencyMs = null;
          _serverStatus = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverLatencyMs = null;
          _serverStatus = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingLatency = false;
        });
      }
    }
  }

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
      _deployProgress = 0.0;
      _downloadSpeed = '0.00 MB/s';
      _downloadEta = '--:--';
      _downloadSizeInfo = '0 MB / 0 MB';

      // Reset steps
      _step1Status = 'active';
      _step2Status = 'pending';
      _step3Status = 'pending';
      _step4Status = 'pending';
      _step5Status = 'pending';
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
        _step1Status = 'failed';
      });
      _addLog('Error: Key authentication failed.');
      return;
    }

    final targetPackage = res['targetGame'] as String;
    _addLog('Access key authorized for target: $targetPackage');
    
    setState(() {
      _isValidating = false;
      _isDeploying = true;
      _step1Status = 'success';
      _step2Status = 'active';
    });

    // 1. Check Permissions
    _addLog('Requesting storage management permissions...');
    final hasPerm = await _detectionService.requestStoragePermission();
    if (!hasPerm) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Storage permission denied. Deployment aborted.';
        _step2Status = 'failed';
      });
      _addLog('Error: Permission request rejected.');
      return;
    }
    
    setState(() {
      _step2Status = 'success';
      _step3Status = 'active';
    });
    _addLog('Storage permissions granted.');

    // 2. Scan Directory
    _addLog('Scanning storage for package $targetPackage...');
    final gamePath = await _detectionService.detectGameDirectory(targetPackage);
    if (gamePath == null) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Target game directory not found on device.';
        _step3Status = 'failed';
      });
      _addLog('Error: Game folders not found. Please install the game first.');
      return;
    }

    setState(() {
      _step3Status = 'success';
      _step4Status = 'active';
    });
    _addLog('Target directory detected: $gamePath');

    // 3. Resolve Destination
    final destPath = '$gamePath/${config.subpath}';
    _addLog('Resolved installation subpath: $destPath');

    // 4. Download and deploy
    _addLog('Downloading payload binary...');
    final downloadSuccess = await _downloadService.downloadAndDeploy(
      backendUrl: config.backendUrl,
      targetPath: destPath,
      key: key,
      username: config.username,
      onProgress: (prog, speed, eta, sizeInfo) {
        setState(() {
          _deployProgress = prog;
          _downloadSpeed = speed;
          _downloadEta = eta;
          _downloadSizeInfo = sizeInfo;
        });
      },
      onLog: (log) => _addLog(log),
    );

    if (!mounted) return;

    if (!downloadSuccess) {
      setState(() {
        _isDeploying = false;
        _errorMessage = 'Binary download/deployment failed.';
        _step4Status = 'failed';
      });
      return;
    }

    setState(() {
      _step4Status = 'success';
      _step5Status = 'active';
    });
    _addLog('Deployment completed successfully. Booting game...');
    
    // 5. Launch Game
    final launched = await _launcherService.launchApp(targetPackage);
    if (!launched) {
      _addLog('Warning: Could not launch app automatically. Please start it manually.');
      setState(() {
        _step5Status = 'failed';
      });
    } else {
      _addLog('Game launched successfully.');
      setState(() {
        _step5Status = 'success';
      });
    }

    setState(() {
      _isDeploying = false;
      _keyController.clear();
    });
  }

  Widget _buildStepRow(String title, String status, {bool isLast = false}) {
    Color iconColor;
    IconData iconData;
    Widget leadingWidget;

    switch (status) {
      case 'success':
        iconColor = const Color(0xFF00FFCC);
        iconData = Icons.check_circle_outlined;
        leadingWidget = Icon(iconData, color: iconColor, size: 20);
        break;
      case 'failed':
        iconColor = const Color(0xFFFF2A6D);
        iconData = Icons.cancel_outlined;
        leadingWidget = Icon(iconData, color: iconColor, size: 20);
        break;
      case 'active':
        iconColor = const Color(0xFFBD00FF);
        leadingWidget = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFBD00FF),
          ),
        );
        break;
      case 'pending':
      default:
        iconColor = const Color(0xFF475569);
        iconData = Icons.radio_button_off_outlined;
        leadingWidget = Icon(iconData, color: iconColor, size: 20);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                child: leadingWidget,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: status == 'success'
                        ? const Color(0xFF00FFCC).withAlpha((255 * 0.4).round())
                        : const Color(0xFF1E293B),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: status == 'active'
                          ? Colors.white
                          : status == 'success'
                              ? const Color(0xFF00FFCC)
                              : status == 'failed'
                                  ? const Color(0xFFFF2A6D)
                                  : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWorking = _isValidating || _isDeploying;

    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      appBar: AppBar(
        backgroundColor: const Color(0xDD0B0F19),
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection Diagnostics Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _measureLatency,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_tethering_outlined,
                                size: 16,
                                color: _serverLatencyMs != null ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isCheckingLatency
                                    ? 'DIAGNOSING...'
                                    : _serverLatencyMs != null
                                        ? 'LATENCY: $_serverLatencyMs ms'
                                        : 'LATENCY: OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: _serverLatencyMs != null
                                      ? const Color(0xFF00FFCC)
                                      : const Color(0xFFFF2A6D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PulseIndicator(status: _serverLatencyMs != null ? 'ONLINE' : 'OFFLINE'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // UI Info Card
                  CyberCard(
                    borderGlowColors: const [Color(0xFFBD00FF), Color(0xFF00FFCC)],
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
                          prefixIcon: Icons.key_outlined,
                          focusColor: const Color(0xFF00FFCC),
                          enabled: !isWorking,
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
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                                ),
                              )
                            : _isDeploying
                                ? const SizedBox.shrink()
                                : CyberButton(
                                    text: 'AUTHENTICATE & DEPLOY',
                                    onPressed: _activateAndDeploy,
                                    gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Deployment Stepper Card
                  if (isWorking || _step1Status != 'pending') ...[
                    CyberCard(
                      borderGlowColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'INSTALLATION WORKFLOW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildStepRow('1. Key Authorization', _step1Status),
                          _buildStepRow('2. Permission Verification', _step2Status),
                          _buildStepRow('3. Target Path Detection', _step3Status),
                          _buildStepRow('4. Streaming Binary', _step4Status),
                          _buildStepRow('5. Executing Target Game', _step5Status, isLast: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // High-tech Download Progress Card (Visible during download step)
                  if (_step4Status == 'active' && _isDeploying) ...[
                    CyberCard(
                      borderGlowColors: const [Color(0xFF00FFCC), Color(0xFF0F172A)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'STREAMING PAYLOAD',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '${(_deployProgress * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF00FFCC),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _deployProgress,
                              minHeight: 8,
                              color: const Color(0xFF00FFCC),
                              backgroundColor: const Color(0xFF030508),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('SPEED', style: TextStyle(fontSize: 8.5, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(_downloadSpeed, style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Text('TRANSFERRED', style: TextStyle(fontSize: 8.5, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(_downloadSizeInfo, style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('EST. TIME', style: TextStyle(fontSize: 8.5, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(_downloadEta, style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Collapsible Logs Console
                  if (_consoleLogs.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SYSTEM TERMINAL FEEDBACK',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_all_outlined, size: 18, color: Color(0xFF00FFCC)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _consoleLogs.join('\n')));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All logs copied to clipboard!'),
                                    backgroundColor: Color(0xFF00FFCC),
                                  ),
                                );
                              },
                              tooltip: 'Copy all logs',
                            ),
                            IconButton(
                              icon: Icon(
                                _showConsoleLogs ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: const Color(0xFF64748B),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showConsoleLogs = !_showConsoleLogs;
                                });
                              },
                              tooltip: _showConsoleLogs ? 'Collapse' : 'Expand',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_showConsoleLogs)
                      CyberConsole(
                        logs: _consoleLogs,
                        height: 180,
                      ),
                    const SizedBox(height: 16),
                  ],

                  // Connected Server Details Bar
                  if (_serverStatus != null)
                    Text(
                      'CONNECTED TO SECURE HOST: ${_serverStatus!.system.platform.toUpperCase()} (${_serverStatus!.system.cpuCores} CPU CORES)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
