import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shizuku_api/shizuku_api.dart';
import '../services/config_service.dart';
import '../services/download_service.dart';
import '../services/key_service.dart';
import '../services/detection_service.dart';
import '../services/launcher_service.dart';
import '../services/preset_service.dart';
import '../widgets/common/cyber_card.dart';
import '../widgets/common/cyber_button.dart';
import '../widgets/common/cyber_text_field.dart';
import '../widgets/dashboard/cyber_console.dart';
import '../widgets/common/pulse_indicator.dart';
import '../widgets/dashboard/system_hud_sheet.dart';
import '../widgets/dashboard/latency_sparkline.dart';
import '../models/system_status.dart';
import '../config.dart';
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
  final PresetService _presetService = PresetService();

  bool _isValidating = false;
  bool _isDeploying = false;
  double _deployProgress = 0.0;
  String _downloadSpeed = '0.00 MB/s';
  String _downloadEta = '--:--';
  String _downloadSizeInfo = '0 MB / 0 MB';
  String _errorMessage = '';
  final List<String> _consoleLogs = [];
  bool _showConsoleLogs = true;

  // Presets and Diagnostics State
  List<PresetGame> _activePresets = [];
  bool _loadingPresets = false;
  bool _rootAvailable = false;
  String _shizukuStatus = 'UNKNOWN'; // RUNNING, NOT_RUNNING, NO_PERMISSION, UNKNOWN
  String _deviceArch = 'UNKNOWN';
  Map<String, bool> _installedPresets = {}; 
  bool _isRunningDiagnostics = false;

  // Connection Diagnostics Status
  int? _serverLatencyMs;
  final List<double> _latencyHistory = [];
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
    _loadPresetsAndDiagnostics();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadPresetsAndDiagnostics() async {
    setState(() {
      _loadingPresets = true;
    });
    final config = ConfigService();
    final list = await _presetService.getPresets(
      backendUrl: config.backendUrl,
      token: config.token ?? '',
    );
    if (mounted) {
      setState(() {
        _activePresets = list.isNotEmpty ? list : config.presets;
        _loadingPresets = false;
      });
      _runSystemDiagnostics(_activePresets);
    }
  }

  Future<void> _runSystemDiagnostics(List<PresetGame> currentPresets) async {
    if (_isRunningDiagnostics) return;
    setState(() {
      _isRunningDiagnostics = true;
    });

    _addLog('Initiating hardware & environment diagnostics...');

    // 1. Check Architecture
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        setState(() {
          _deviceArch = androidInfo.supportedAbis.isNotEmpty 
              ? androidInfo.supportedAbis.first.toUpperCase()
              : 'UNKNOWN';
        });
      } else {
        setState(() {
          _deviceArch = 'MOCK_X86_64';
        });
      }
    } catch (_) {
      setState(() {
        _deviceArch = 'ERR_ARCH';
      });
    }

    // 2. Check Root Access
    try {
      if (Platform.isAndroid) {
        final suCheck = await Process.run('su', ['-v']).timeout(
          const Duration(seconds: 1),
          onTimeout: () => ProcessResult(-1, -1, '', 'Timeout'),
        );
        setState(() {
          _rootAvailable = suCheck.exitCode == 0;
        });
      } else {
        setState(() {
          _rootAvailable = false;
        });
      }
    } catch (_) {
      setState(() {
        _rootAvailable = false;
      });
    }

    // 3. Check Shizuku Service status
    try {
      if (Platform.isAndroid) {
        final shizuku = ShizukuApi();
        final isRunning = await shizuku.pingBinder() ?? false;
        if (isRunning) {
          var hasPermission = await shizuku.checkPermission() ?? false;
          if (!hasPermission) {
            _addLog('Shizuku active but unauthorized. Prompting user for permission...');
            hasPermission = await shizuku.requestPermission() ?? false;
          }
          setState(() {
            _shizukuStatus = hasPermission ? 'RUNNING' : 'NO_PERMISSION';
          });
        } else {
          setState(() {
            _shizukuStatus = 'NOT_RUNNING';
          });
        }
      } else {
        setState(() {
          _shizukuStatus = 'RUNNING'; // mock
        });
      }
    } catch (_) {
      setState(() {
        _shizukuStatus = 'UNAVAILABLE';
      });
    }

    // 4. Check Installed Targets
    final Map<String, bool> tempInstalled = {};
    for (var preset in currentPresets) {
      try {
        if (Platform.isAndroid) {
          final dir = Directory('/storage/emulated/0/Android/data/${preset.package}');
          final exists = await dir.exists();
          tempInstalled[preset.package] = exists;
        } else {
          tempInstalled[preset.package] = true; // mock
        }
      } catch (_) {
        tempInstalled[preset.package] = false;
      }
    }
    
    if (mounted) {
      setState(() {
        _installedPresets = tempInstalled;
        _isRunningDiagnostics = false;
      });
    }

    _addLog('Diagnostics complete. Arch: $_deviceArch, Root: ${_rootAvailable ? "YES" : "NO"}, Shizuku: $_shizukuStatus');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFFF2A6D) : const Color(0xFF00FFCC),
      ),
    );
  }

  Future<void> _handleShizukuBadgeTap() async {
    if (_shizukuStatus == 'RUNNING') {
      _showSnackBar('Shizuku is active and authorized.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFBD00FF), width: 1.5),
          ),
          title: const Text(
            'SHIZUKU INTERFACE SETUP',
            style: TextStyle(
              color: Color(0xFF00FFCC),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 1.0,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current Status: ${_shizukuStatus.toUpperCase()}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Instructions:\n'
                '1. Ensure Shizuku Manager is installed and started.\n'
                '2. If status is "NO AUTH", tap "REQUEST PERMISSION" or authorize this app manually inside Shizuku Manager.\n'
                '3. On some devices (MIUI/HyperOS/Realme), you must enable "Disable permission monitoring" in Developer Options.',
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 16),
              CyberButton(
                text: 'REQUEST PERMISSION',
                height: 38,
                onPressed: () async {
                  Navigator.pop(context);
                  final shizuku = ShizukuApi();
                  final success = await shizuku.requestPermission() ?? false;
                  if (success) {
                    _loadPresetsAndDiagnostics();
                  } else {
                    _showSnackBar('Permission request failed or denied.', isError: true);
                  }
                },
                gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
              ),
              const SizedBox(height: 8),
              CyberButton(
                text: 'LAUNCH SHIZUKU MANAGER',
                height: 38,
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await LauncherService().launchApp('moe.shizuku.manager');
                  if (!success) {
                    _showSnackBar('Could not launch Shizuku. Is it installed?', isError: true);
                  }
                },
                gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                textColor: Colors.white70,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          ],
        );
      },
    );
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
          _latencyHistory.add(_serverLatencyMs!.toDouble());
          if (_latencyHistory.length > 10) _latencyHistory.removeAt(0);
        });
      } else if (mounted) {
        setState(() {
          _serverLatencyMs = null;
          _serverStatus = null;
          _latencyHistory.add(0.0);
          if (_latencyHistory.length > 10) _latencyHistory.removeAt(0);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverLatencyMs = null;
          _serverStatus = null;
          _latencyHistory.add(0.0);
          if (_latencyHistory.length > 10) _latencyHistory.removeAt(0);
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

  Widget _buildDiagnosticsCard() {
    Color shizukuColor;
    String shizukuText;
    switch (_shizukuStatus) {
      case 'RUNNING':
        shizukuColor = const Color(0xFF00FFCC);
        shizukuText = 'RUNNING';
        break;
      case 'NO_PERMISSION':
        shizukuColor = const Color(0xFFFFCC00);
        shizukuText = 'NO AUTH';
        break;
      case 'NOT_RUNNING':
        shizukuColor = const Color(0xFFFF2A6D);
        shizukuText = 'OFFLINE';
        break;
      default:
        shizukuColor = const Color(0xFF64748B);
        shizukuText = 'UNKNOWN';
    }

    final isArchOk = _deviceArch.contains('ARM64') || _deviceArch.contains('AARCH64') || _deviceArch.contains('MOCK');

    return CyberCard(
      borderGlowColors: const [Color(0xFF00FFCC), Color(0xFF0F172A)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ENVIRONMENT DIAGNOSTICS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => const FractionallySizedBox(
                          heightFactor: 0.75,
                          child: SystemHudSheet(),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.analytics_outlined, color: Color(0xFFBD00FF), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'HUD',
                          style: TextStyle(color: Color(0xFFBD00FF), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _isRunningDiagnostics
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00FFCC)),
                        )
                      : InkWell(
                          onTap: () => _runSystemDiagnostics(_activePresets),
                          child: const Icon(Icons.refresh, color: Color(0xFF00FFCC), size: 16),
                        ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildDiagBadge('ARCH', _deviceArch, isArchOk ? const Color(0xFF00FFCC) : const Color(0xFFFFCC00)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDiagBadge('ROOT LINK', _rootAvailable ? 'ROOTED' : 'NON-ROOT', _rootAvailable ? const Color(0xFF00FFCC) : const Color(0xFFBD00FF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDiagBadge(
                  'SHIZUKU',
                  shizukuText,
                  shizukuColor,
                  onTap: _handleShizukuBadgeTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          
          const Text(
            'TARGET APK DIRECTORIES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          
          _loadingPresets
              ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activePresets.length,
                  itemBuilder: (ctx, idx) {
                    final preset = _activePresets[idx];
                    final isInstalled = _installedPresets[preset.package] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF030508),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  preset.package,
                                  style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isInstalled ? const Color(0xFF00FFCC).withAlpha(15) : const Color(0xFFFF2A6D).withAlpha(10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isInstalled ? const Color(0xFF00FFCC).withAlpha(60) : const Color(0xFFFF2A6D).withAlpha(30),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isInstalled ? 'DETECTED' : 'MISSING',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: isInstalled ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildDiagBadge(String title, String value, Color color, {VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF030508),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }
    return card;
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
                  if (_latencyHistory.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    LatencySparkline(history: _latencyHistory),
                  ],
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

                  // Diagnostics Dashboard Card
                  _buildDiagnosticsCard(),
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
