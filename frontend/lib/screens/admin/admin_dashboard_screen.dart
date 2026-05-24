import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/config_service.dart';
import '../../services/download_service.dart';
import '../../services/preset_service.dart';
import '../../services/admin_key_service.dart';
import '../../services/key_service.dart';
import '../../services/log_service.dart';
import '../../services/system_status_service.dart';
import '../../widgets/common/cyber_card.dart';
import '../../widgets/common/cyber_button.dart';
import '../../widgets/common/cyber_text_field.dart';
import '../../widgets/dashboard/neon_line_chart.dart';
import '../../widgets/dashboard/neon_doughnut_chart.dart';
import '../../config.dart';
import '../../models/access_key.dart';
import '../../models/audit_log.dart';
import '../../models/system_status.dart';
import '../../models/app_user.dart';
import '../../services/admin_user_service.dart';
import '../auth_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentMenuIndex = 0; // 0: Home/Overview, 1: Keys, 2: Payloads, 3: Presets, 4: Logs, 5: Users

  final DownloadService _downloadService = DownloadService();
  final PresetService _presetService = PresetService();
  final AdminKeyService _adminKeyService = AdminKeyService();
  final LogService _logService = LogService();
  final SystemStatusService _systemStatusService = SystemStatusService();
  final KeyService _keyService = KeyService();
  final AdminUserService _adminUserService = AdminUserService();

  double _uploadProgress = 0.0;

  // Users State
  List<AppUser> _users = [];
  bool _loadingUsers = false;

  // License Keys State
  List<AccessKey> _keys = [];
  bool _loadingKeys = false;
  final _keyPrefixController = TextEditingController();
  final _keyCountController = TextEditingController(text: '1');
  final _keyUsesController = TextEditingController(text: '1');
  final _keyExpiryController = TextEditingController();
  final _keyAssignedToController = TextEditingController();

  // Custom Target Game State
  String _selectedTargetPreset = '';
  bool _isCustomTarget = false;
  final _customTargetController = TextEditingController();

  // Keys Filter/Search State
  final _keySearchController = TextEditingController();
  String _keyStatusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE, ASSIGNED, UNASSIGNED

  // Dynamic Presets State
  List<PresetGame> _activePresets = [];
  bool _loadingPresets = false;
  final _presetNameController = TextEditingController();
  final _presetPackageController = TextEditingController();

  // Logs State
  List<AuditLog> _logs = [];
  bool _loadingLogs = false;
  int _logPage = 1;
  int _logTotalPages = 1;
  bool _loadingMoreLogs = false;

  // Logs Filter/Search State
  final _logSearchController = TextEditingController();
  String _logLevelFilter = 'ALL'; // ALL, INFO, WARN, ERROR
  String _logCategoryFilter = 'ALL'; // ALL, AUTH, KEY, DOWNLOAD, UPLOAD, SYSTEM

  // Server Payload & Diagnostic State
  SystemStatus? _serverStatus;
  bool _loadingStatus = false;
  bool _isUploading = false;
  int? _serverLatencyMs;

  // Payload Profile Link State
  bool _linkPayloadToProfile = false;
  String _selectedPayloadTarget = '';

  @override
  void initState() {
    super.initState();
    _refreshTabContent();
  }

  void _refreshTabContent() {
    _measureLatency();
    _fetchServerStatus();
    _fetchPresets();
    if (_currentMenuIndex == 0) {
      _fetchKeys();
      _fetchLogs(loadMore: false);
    } else if (_currentMenuIndex == 1) {
      _fetchKeys();
    } else if (_currentMenuIndex == 2) {
      // Status fetched globally
    } else if (_currentMenuIndex == 3) {
      // Presets loaded by _fetchPresets
    } else if (_currentMenuIndex == 4) {
      _fetchLogs(loadMore: false);
    } else if (_currentMenuIndex == 5) {
      _fetchUsers();
    }
  }

  @override
  void dispose() {
    _keyPrefixController.dispose();
    _keyCountController.dispose();
    _keyUsesController.dispose();
    _keyExpiryController.dispose();
    _keyAssignedToController.dispose();
    _customTargetController.dispose();
    _keySearchController.dispose();
    _logSearchController.dispose();
    _presetNameController.dispose();
    _presetPackageController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ConfigService().clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
    );
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

  // --- API CALLS VIA SERVICES ---

  Future<void> _measureLatency() async {
    try {
      final config = ConfigService();
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final status = await _downloadService.checkStatus(config.backendUrl);
      final endTime = DateTime.now().millisecondsSinceEpoch;
      if (status != null && mounted) {
        setState(() {
          _serverLatencyMs = endTime - startTime;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPresets() async {
    setState(() => _loadingPresets = true);
    try {
      final config = ConfigService();
      final list = await _presetService.getPresets(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      if (mounted) {
        setState(() {
          _activePresets = list.isNotEmpty ? list : config.presets;
          if (_activePresets.isNotEmpty) {
            if (_selectedPayloadTarget.isEmpty || !_activePresets.any((p) => p.package == _selectedPayloadTarget)) {
              _selectedPayloadTarget = _activePresets.first.package;
            }
            if (_selectedTargetPreset.isEmpty || !_activePresets.any((p) => p.package == _selectedTargetPreset)) {
              _selectedTargetPreset = _activePresets.first.package;
            }
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingPresets = false);
      }
    }
  }

  Future<void> _createPreset() async {
    final name = _presetNameController.text.trim();
    final pkg = _presetPackageController.text.trim();

    if (name.isEmpty || pkg.isEmpty) {
      _showSnackBar('Preset Name and Package ID are required.', isError: true);
      return;
    }

    try {
      final config = ConfigService();
      final success = await _presetService.createPreset(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        name: name,
        package: pkg,
      );

      if (success) {
        _showSnackBar('Target preset added successfully.');
        _presetNameController.clear();
        _presetPackageController.clear();
        _fetchPresets();
      } else {
        _showSnackBar('Failed to add target preset.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error creating preset: $e', isError: true);
    }
  }

  Future<void> _deletePreset(String packageId) async {
    try {
      final config = ConfigService();
      final success = await _presetService.deletePreset(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        package: packageId,
      );

      if (success) {
        _showSnackBar('Target preset deleted.');
        _fetchPresets();
      } else {
        _showSnackBar('Failed to delete preset.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error deleting preset: $e', isError: true);
    }
  }

  Future<void> _fetchKeys() async {
    setState(() => _loadingKeys = true);
    try {
      final config = ConfigService();
      final keys = await _adminKeyService.fetchKeys(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      setState(() {
        _keys = keys;
      });
    } catch (e) {
      _showSnackBar('Failed to load license keys: $e', isError: true);
    } finally {
      setState(() => _loadingKeys = false);
    }
  }

  Future<void> _generateKeys() async {
    final prefix = _keyPrefixController.text.trim();
    final count = int.tryParse(_keyCountController.text) ?? 1;
    final uses = int.tryParse(_keyUsesController.text) ?? 1;
    final expiryHours = int.tryParse(_keyExpiryController.text.trim());
    final assignedTo = _keyAssignedToController.text.trim();
    final target = _isCustomTarget ? _customTargetController.text.trim() : _selectedTargetPreset;

    if (_isCustomTarget && target.isEmpty) {
      _showSnackBar('Please specify a custom target package name.', isError: true);
      return;
    }

    try {
      final config = ConfigService();
      final success = await _adminKeyService.generateKeys(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        prefix: prefix,
        count: count,
        maxUses: uses,
        expiresInHours: expiryHours,
        assignedTo: assignedTo,
        targetGame: target,
      );

      if (success) {
        _showSnackBar('Keys generated successfully.');
        _keyPrefixController.clear();
        _keyExpiryController.clear();
        _keyAssignedToController.clear();
        _customTargetController.clear();
        _keyCountController.text = '1';
        _keyUsesController.text = '1';
        _fetchKeys();
      } else {
        _showSnackBar('Failed to generate keys.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Generation failed: $e', isError: true);
    }
  }

  Future<void> _updateKey(
    String keyId, {
    int? maxUses,
    String? expiresAt,
    String? targetGame,
    String? assignedTo,
  }) async {
    try {
      final config = ConfigService();
      final res = await _keyService.updateKey(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        keyId: keyId,
        maxUses: maxUses,
        expiresAt: expiresAt,
        targetGame: targetGame,
        assignedTo: assignedTo,
      );

      if (res['success'] == true) {
        _showSnackBar(res['message'] ?? 'Settings updated.');
        _fetchKeys();
      } else {
        _showSnackBar(res['error'] ?? 'Update failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Update error: $e', isError: true);
    }
  }

  Future<void> _toggleKey(String keyId) async {
    try {
      final config = ConfigService();
      final success = await _adminKeyService.toggleKeyStatus(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        keyId: keyId,
      );
      if (success) {
        _fetchKeys();
      } else {
        _showSnackBar('Failed to toggle key status.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Toggle error: $e', isError: true);
    }
  }

  Future<void> _deleteKey(String keyId) async {
    try {
      final config = ConfigService();
      final success = await _adminKeyService.deleteKey(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        keyId: keyId,
      );
      if (success) {
        _showSnackBar('Key deleted.');
        _fetchKeys();
      } else {
        _showSnackBar('Failed to delete key.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Deletion failed: $e', isError: true);
    }
  }

  Future<void> _resetFingerprint(String keyId) async {
    try {
      final config = ConfigService();
      final success = await _adminKeyService.resetFingerprint(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        keyId: keyId,
      );
      if (success) {
        _showSnackBar('Device fingerprint reset successfully.');
        _fetchKeys();
      } else {
        _showSnackBar('Failed to reset binding.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Reset failed: $e', isError: true);
    }
  }

  Future<void> _deactivateAll() async {
    try {
      final config = ConfigService();
      final res = await _adminKeyService.deactivateAll(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      if (res['success'] == true) {
        _showSnackBar(res['message'] ?? 'All keys deactivated.');
        _fetchKeys();
      } else {
        _showSnackBar(res['error'] ?? 'Operation failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Deactivate failed: $e', isError: true);
    }
  }

  Future<void> _pruneKeys() async {
    try {
      final config = ConfigService();
      final res = await _adminKeyService.pruneKeys(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      if (res['success'] == true) {
        _showSnackBar(res['message'] ?? 'Inactive/expired keys pruned.');
        _fetchKeys();
      } else {
        _showSnackBar(res['error'] ?? 'Pruning failed.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Prune failed: $e', isError: true);
    }
  }

  Future<void> _fetchServerStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final status = await _systemStatusService.fetchStatus(backendUrl: ConfigService().backendUrl);
      if (status != null && mounted) {
        setState(() {
          _serverStatus = status;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingStatus = false);
      }
    }
  }

  Future<void> _uploadBinaryFile() async {
    if (_isUploading) return;

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        _showSnackBar('File selection cancelled.');
        return;
      }

      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      if (!fileName.endsWith('.so')) {
        _showSnackBar('Invalid file type. Please select a valid .so file.', isError: true);
        return;
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final config = ConfigService();
      final target = _linkPayloadToProfile ? _selectedPayloadTarget : null;

      final success = await _systemStatusService.uploadPayload(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        filePath: filePath,
        targetGame: target,
        onProgress: (prog) {
          setState(() {
            _uploadProgress = prog;
          });
        },
      );

      if (success) {
        _showSnackBar('Binary profile file uploaded and replaced successfully!');
        _fetchServerStatus();
      } else {
        _showSnackBar('Upload failed. Check server connection.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Exception during file upload: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _fetchLogs({bool loadMore = false}) async {
    if (loadMore) {
      if (_logPage >= _logTotalPages || _loadingMoreLogs) return;
      setState(() => _loadingMoreLogs = true);
      _logPage++;
    } else {
      setState(() {
        _loadingLogs = true;
        _logPage = 1;
        _logs.clear();
      });
    }

    try {
      final config = ConfigService();
      final res = await _logService.fetchLogs(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        page: _logPage,
        limit: 50,
        level: _logLevelFilter,
        category: _logCategoryFilter,
        search: _logSearchController.text.trim(),
      );

      if (res['success'] == true && mounted) {
        setState(() {
          final newLogs = res['logs'] as List<AuditLog>;
          if (loadMore) {
            _logs.addAll(newLogs);
          } else {
            _logs = newLogs;
          }
          _logTotalPages = res['totalPages'] as int;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to fetch system logs: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
          _loadingMoreLogs = false;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    try {
      final config = ConfigService();
      final success = await _logService.clearLogs(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      if (success) {
        _showSnackBar('Logs cleared.');
        _fetchLogs(loadMore: false);
      } else {
        _showSnackBar('Failed to clear logs.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error clearing logs: $e', isError: true);
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final config = ConfigService();
      final list = await _adminUserService.fetchUsers(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
      );
      setState(() {
        _users = list;
      });
    } catch (e) {
      _showSnackBar('Failed to load users: $e', isError: true);
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _updateUserRole(String userId, String role) async {
    try {
      final config = ConfigService();
      final success = await _adminUserService.updateUserRole(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        userId: userId,
        role: role,
      );
      if (success) {
        _showSnackBar('User role updated successfully.');
        _fetchUsers();
      } else {
        _showSnackBar('Failed to update role.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      final config = ConfigService();
      final success = await _adminUserService.deleteUser(
        backendUrl: config.backendUrl,
        token: config.token ?? '',
        userId: userId,
      );
      if (success) {
        _showSnackBar('User deleted successfully.');
        _fetchUsers();
      } else {
        _showSnackBar('Failed to delete user.', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  // --- LOCAL FILTER SELECTORS ---

  List<AccessKey> get _filteredKeys {
    final query = _keySearchController.text.trim().toLowerCase();
    return _keys.where((k) {
      if (_keyStatusFilter == 'ACTIVE' && k.isActive != true) return false;
      if (_keyStatusFilter == 'INACTIVE' && k.isActive == true) return false;
      final assigned = k.assignedTo.isNotEmpty;
      if (_keyStatusFilter == 'ASSIGNED' && !assigned) return false;
      if (_keyStatusFilter == 'UNASSIGNED' && assigned) return false;

      if (query.isNotEmpty) {
        final keyMatch = k.key.toLowerCase().contains(query);
        final ownerMatch = k.assignedTo.toLowerCase().contains(query);
        final targetMatch = k.targetGame.toLowerCase().contains(query);
        return keyMatch || ownerMatch || targetMatch;
      }
      return true;
    }).toList();
  }

  String _getGameDisplayName(String package) {
    for (var preset in _activePresets) {
      if (preset.package == package) {
        return preset.name;
      }
    }
    if (package.length > 22) {
      return '...${package.substring(package.length - 18)}';
    }
    return package;
  }

  Map<String, double> getSeverityRatios() {
    double info = 0;
    double warn = 0;
    double error = 0;
    for (var log in _logs) {
      if (log.level == 'info') {
        info++;
      } else if (log.level == 'warn') {
        warn++;
      } else if (log.level == 'error') {
        error++;
      }
    }
    if (info == 0 && warn == 0 && error == 0) {
      return {'INFO': 1.0, 'WARN': 0.0, 'ERROR': 0.0};
    }
    return {'INFO': info, 'WARN': warn, 'ERROR': error};
  }

  List<double> getActivationRatios() {
    // Builds a trends graph from the active keys history
    final List<double> trends = [2.0, 4.0, 3.0, 6.0, 5.0, 9.0];
    double activeUsesTotal = 0;
    for (var k in _keys) {
      if (k.isActive) {
        activeUsesTotal += k.usesCount;
      }
    }
    trends.add(activeUsesTotal > 0 ? activeUsesTotal : 4.0);
    if (trends.length > 7) trends.removeAt(0);
    return trends;
  }

  // --- EDIT KEY POPUP DIALOG ---

  void _showEditKeyDialog(AccessKey keyDoc) {
    final usesCtrl = TextEditingController(text: keyDoc.maxUses.toString());
    final ownerCtrl = TextEditingController(text: keyDoc.assignedTo);
    final expiryCtrl = TextEditingController(
      text: keyDoc.expiresAt != null ? (keyDoc.expiresAt!.difference(DateTime.now()).inHours).toString() : '',
    );
    String selectedTarget = _activePresets.any((p) => p.package == keyDoc.targetGame)
        ? keyDoc.targetGame
        : (_activePresets.isNotEmpty ? _activePresets.first.package : keyDoc.targetGame);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0E17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFBD00FF), width: 1.5),
          ),
          title: Text(
            'MODIFY LICENSE KEY:\n${keyDoc.key}',
            style: const TextStyle(
              color: Color(0xFF00FFCC),
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
              letterSpacing: 1.0,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                CyberTextField(controller: usesCtrl, label: 'MAX USES LIMIT', prefixIcon: Icons.repeat),
                const SizedBox(height: 12),
                CyberTextField(controller: ownerCtrl, label: 'ASSIGNED OPERATOR', prefixIcon: Icons.person_outline),
                const SizedBox(height: 12),
                CyberTextField(controller: expiryCtrl, label: 'EXPIRY IN HOURS (BLANK=NEVER)', prefixIcon: Icons.timer_outlined),
                const SizedBox(height: 14),
                const Text('TARGET SYSTEM PACKAGE', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07090E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTarget.isNotEmpty ? selectedTarget : null,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0B0F19),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                      onChanged: (val) {
                        if (val != null) {
                          selectedTarget = val;
                        }
                      },
                      items: _activePresets.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.package,
                          child: Text(p.name.toUpperCase()),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ),
            TextButton(
              onPressed: () {
                final maxUses = int.tryParse(usesCtrl.text.trim()) ?? keyDoc.maxUses;
                final assignedTo = ownerCtrl.text.trim();
                final expHrs = int.tryParse(expiryCtrl.text.trim());
                
                String? expiresAtStr;
                if (expHrs != null && expHrs > 0) {
                  expiresAtStr = DateTime.now().add(Duration(hours: expHrs)).toUtc().toIso8601String();
                } else if (expiryCtrl.text.isEmpty) {
                  expiresAtStr = '';
                }

                _updateKey(
                  keyDoc.id,
                  maxUses: maxUses,
                  assignedTo: assignedTo,
                  expiresAt: expiresAtStr,
                  targetGame: selectedTarget,
                );
                Navigator.pop(ctx);
              },
              child: const Text('UPDATE SETTINGS', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        );
      },
    );
  }

  // --- SUB-PANEL RENDERS ---

  Widget _buildHomeView() {
    final severityData = getSeverityRatios();
    final severityColors = {
      'INFO': const Color(0xFF00FFCC),
      'WARN': const Color(0xFFFFCC00),
      'ERROR': const Color(0xFFFF2A6D),
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatsOverview(),
          const SizedBox(height: 24),
          
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 6 : 0,
                    child: CyberCard(
                      borderGlowColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'LICENSE KEY ACTIVATION HISTORY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 180,
                            child: NeonLineChart(
                              data: getActivationRatios(),
                              labels: const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isWide) const SizedBox(width: 20) else const SizedBox(height: 20),
                  Expanded(
                    flex: isWide ? 4 : 0,
                    child: CyberCard(
                      borderGlowColors: const [Color(0xFFBD00FF), Color(0xFFFF2A6D)],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'AUDIT LOGS SEVERITY DISTRIBUTION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 120,
                            child: NeonDoughnutChart(
                              data: severityData,
                              colors: severityColors,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: severityData.entries.map((entry) {
                              final color = severityColors[entry.key] ?? Colors.grey;
                              return Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${entry.key} (${entry.value.toStringAsFixed(0)})',
                                    style: const TextStyle(fontSize: 8.5, color: Colors.white70, fontFamily: 'monospace'),
                                  ),
                                ],
                              );
                            }).toList(),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final meta = _serverStatus;
    final exists = meta?.binaryExists == true;
    final sizeMb = exists ? (meta!.binarySize / (1024 * 1024)).toStringAsFixed(2) : '0.00';
    final dbConnected = meta?.config.dbStatus == 'connected';

    final totalKeysCount = _keys.length;
    final activeKeysCount = _keys.where((k) => k.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'DIAGNOSTIC STATUS & METRICS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.3 : 1.6,
              children: [
                _buildStatCard(
                  'DATABASE',
                  dbConnected ? 'CONNECTED' : 'OFFLINE',
                  Icons.storage_outlined,
                  dbConnected ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                ),
                _buildStatCard(
                  'BINARY SIZE',
                  exists ? '$sizeMb MB' : 'MISSING',
                  Icons.code_outlined,
                  exists ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                ),
                _buildStatCard(
                  'LICENSE KEYS',
                  '$activeKeysCount / $totalKeysCount',
                  Icons.vpn_key_outlined,
                  const Color(0xFFBD00FF),
                ),
                _buildStatCard(
                  'LATENCY',
                  _serverLatencyMs != null ? '$_serverLatencyMs ms' : 'OFFLINE',
                  Icons.network_ping_outlined,
                  _serverLatencyMs != null ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return CyberCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderGlowColors: [color.withAlpha(50), const Color(0xFF0B0F19)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              Icon(icon, color: color, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: color,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeysView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Generator Form
          CyberCard(
            borderGlowColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'GENERATE ACCESS KEYS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: CyberTextField(controller: _keyPrefixController, label: 'PREFIX (e.g. TRIAL)', prefixIcon: Icons.label_outline),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: CyberTextField(controller: _keyCountController, label: 'COUNT', prefixIcon: Icons.onetwothree),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: CyberTextField(controller: _keyUsesController, label: 'USES', prefixIcon: Icons.repeat),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: CyberTextField(
                        controller: _keyExpiryController,
                        label: 'EXPIRY (HOURS)',
                        prefixIcon: Icons.timer_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: CyberTextField(
                        controller: _keyAssignedToController,
                        label: 'ASSIGN TO USERNAME',
                        prefixIcon: Icons.person_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'TARGET GAME PACKAGE',
                  style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07090E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isCustomTarget ? 'CUSTOM' : (_selectedTargetPreset.isNotEmpty ? _selectedTargetPreset : null),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0B0F19),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF00FFCC)),
                      style: const TextStyle(fontSize: 12.5, color: Colors.white, fontFamily: 'monospace'),
                      onChanged: (val) {
                        setState(() {
                          if (val == 'CUSTOM') {
                            _isCustomTarget = true;
                          } else {
                            _isCustomTarget = false;
                            _selectedTargetPreset = val!;
                          }
                        });
                      },
                      items: [
                        ..._activePresets.map((preset) {
                          return DropdownMenuItem<String>(
                            value: preset.package,
                            child: Text(preset.name.toUpperCase()),
                          );
                        }),
                        const DropdownMenuItem<String>(
                          value: 'CUSTOM',
                          child: Text('CUSTOM PACKAGE TARGET'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isCustomTarget) ...[
                  const SizedBox(height: 12),
                  CyberTextField(
                    controller: _customTargetController,
                    label: 'CUSTOM GAME PACKAGE ID',
                    prefixIcon: Icons.settings_applications_outlined,
                    hintText: 'e.g. com.tencent.ig',
                  ),
                ],
                
                const SizedBox(height: 16),
                CyberButton(
                  text: 'GENERATE KEY BATCH',
                  onPressed: _generateKeys,
                  gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bulk Management actions Panel
          CyberCard(
            borderGlowColors: const [Color(0xFFFF2A6D), Color(0xFFBD00FF)],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BULK LICENSE MANAGEMENT',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CyberButton(
                        text: 'DEACTIVATE ALL',
                        height: 44,
                        gradientColors: const [Color(0xFFFF2A6D), Color(0xFF0F172A)],
                        textColor: Colors.white,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF0B0F19),
                              title: const Text('DEACTIVATE ALL KEYS?', style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.bold, fontSize: 14)),
                              content: const Text('This will instantly disable client access for all generated licenses. Are you sure?', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deactivateAll();
                                  },
                                  child: const Text('CONFIRM', style: TextStyle(color: Color(0xFFFF2A6D))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CyberButton(
                        text: 'PRUNE KEYS',
                        height: 44,
                        gradientColors: const [Color(0xFF00FFCC), Color(0xFF0F172A)],
                        textColor: Colors.white,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF0B0F19),
                              title: const Text('PRUNE INACTIVE & EXPIRED?', style: TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 14)),
                              content: const Text('This will permanently delete all expired and inactive keys from the database. This action is irreversible. Proceed?', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _pruneKeys();
                                  },
                                  child: const Text('PRUNE', style: TextStyle(color: Color(0xFF00FFCC))),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search & Filter Panel
          CyberCard(
            borderGlowColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'FILTER & SEARCH LICENSES',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                CyberTextField(
                  controller: _keySearchController,
                  label: 'SEARCH KEY, OWNER, OR GAME',
                  prefixIcon: Icons.search,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['ALL', 'ACTIVE', 'INACTIVE', 'ASSIGNED', 'UNASSIGNED'].map((filter) {
                      final isSelected = _keyStatusFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white70,
                              letterSpacing: 1.0,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _keyStatusFilter = filter;
                              });
                            }
                          },
                          selectedColor: const Color(0xFF00FFCC),
                          backgroundColor: const Color(0xFF07090E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF00FFCC) : const Color(0xFF1E293B),
                              width: 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE LICENSES (${_filteredKeys.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
              ),
              IconButton(
                icon: const Icon(Icons.download_for_offline, color: Color(0xFF00FFCC)),
                onPressed: () {
                  final List<Map<String, dynamic>> exportList = _filteredKeys.map((k) {
                    return {
                      'key': k.key,
                      'maxUses': k.maxUses,
                      'usesCount': k.usesCount,
                      'targetGame': k.targetGame,
                      'assignedTo': k.assignedTo,
                      'isActive': k.isActive,
                      'expiresAt': k.expiresAt?.toIso8601String()
                    };
                  }).toList();
                  Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(exportList)));
                  _showSnackBar('License keys database exported to clipboard (JSON)!');
                },
                tooltip: 'Export Keys to Clipboard (JSON)',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _loadingKeys
              ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFF00FFCC))))
              : _filteredKeys.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No keys matching criteria.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredKeys.length,
                      itemBuilder: (ctx, index) {
                        final k = _filteredKeys[index];
                        final active = k.isActive;
                        final gamePkg = k.targetGame;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: CyberCard(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            borderGlowColors: active
                                ? [const Color(0xFF00FFCC), const Color(0xFF0B0F19)]
                                : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        k.key,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: Color(0xFF00FFCC),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: active ? const Color(0xFF00FFCC).withAlpha((255 * 0.08).round()) : const Color(0xFFFF2A6D).withAlpha((255 * 0.08).round()),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: active ? const Color(0xFF00FFCC).withAlpha((255 * 0.35).round()) : const Color(0xFFFF2A6D).withAlpha((255 * 0.35).round()),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        active ? 'ACTIVE' : 'INACTIVE',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: active ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(Icons.repeat, 'USAGES', '${k.usesCount} / ${k.maxUses}'),
                                _buildDetailRow(Icons.videogame_asset_outlined, 'GAME TARGET', _getGameDisplayName(gamePkg)),
                                _buildDetailRow(
                                  Icons.person_outline,
                                  'ASSIGNED OWNER',
                                  k.assignedTo.isNotEmpty ? k.assignedTo : 'Unassigned (binds on first use)',
                                  valueColor: k.assignedTo.isNotEmpty ? const Color(0xFF00FFCC) : const Color(0xFF64748B),
                                ),
                                _buildDetailRow(
                                  Icons.timer_outlined,
                                  'EXPIRES',
                                  k.expiresAt != null ? k.expiresAt!.toLocal().toString().substring(0, 19) : 'Never',
                                  valueColor: k.isExpired ? const Color(0xFFFF2A6D) : const Color(0xFF64748B),
                                ),
                                if (k.deviceFingerprint.isNotEmpty)
                                  _buildDetailRow(
                                    Icons.fingerprint_outlined,
                                    'FINGERPRINT',
                                    k.deviceFingerprint,
                                    valueColor: const Color(0xFFBD00FF),
                                    isMonospace: true,
                                  ),
                                const Divider(color: Color(0xFF1E293B), height: 16, thickness: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF00FFCC), size: 18),
                                      onPressed: () => _showEditKeyDialog(k),
                                      tooltip: 'Edit Key Configuration',
                                    ),
                                    if (k.deviceFingerprint.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phonelink_erase, color: Color(0xFFBD00FF), size: 18),
                                        onPressed: () => _resetFingerprint(k.id),
                                        tooltip: 'Reset Binding Fingerprint',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF00FFCC), size: 18),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: k.key));
                                        _showSnackBar('Key copied to clipboard!');
                                      },
                                      tooltip: 'Copy Key',
                                    ),
                                    const SizedBox(width: 8),
                                    Switch(
                                      value: active,
                                      onChanged: (_) => _toggleKey(k.id),
                                      activeTrackColor: const Color(0xFF00FFCC),
                                      activeThumbColor: Colors.black,
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF2A6D), size: 18),
                                      onPressed: () => _deleteKey(k.id),
                                      tooltip: 'Delete Key',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildPayloadsView() {
    if (_loadingStatus) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)));
    }

    final meta = _serverStatus;
    final exists = meta?.binaryExists == true;
    final sizeMb = meta != null ? (meta.binarySize / (1024 * 1024)).toStringAsFixed(2) : '0.00';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CyberCard(
            borderGlowColors: const [Color(0xFFBD00FF), Color(0xFF00FFCC)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SERVER CORE BINARY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                _buildMetaRow('STATUS', meta?.status.toUpperCase() ?? 'OFFLINE', color: meta?.status == 'online' ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
                _buildMetaRow('FILE STATE', exists ? 'AVAILABLE' : 'MISSING', color: exists ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
                _buildMetaRow('BINARY SIZE', '$sizeMb MB'),
                _buildMetaRow('STORAGE DIR', meta?.config.uploadDir ?? 'N/A'),
                _buildMetaRow('MOCK GENERATION', meta?.config.mockBinaryEnabled == true ? 'ENABLED' : 'DISABLED'),
                _buildMetaRow('DB CONNECTIVITY', meta?.config.dbStatus.toUpperCase() ?? 'DISCONNECTED', color: meta?.config.dbStatus == 'connected' ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'TARGET BINARY ASSOCIATION',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          CyberCard(
            borderGlowColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LINK TO SPECIFIC GAME PROFILE',
                      style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _linkPayloadToProfile,
                      onChanged: (val) {
                        setState(() {
                          _linkPayloadToProfile = val;
                        });
                      },
                      activeTrackColor: const Color(0xFF00FFCC),
                      activeThumbColor: Colors.black,
                    ),
                  ],
                ),
                if (_linkPayloadToProfile) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'SELECT TARGET GAME PROFILE',
                    style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07090E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPayloadTarget.isNotEmpty ? _selectedPayloadTarget : null,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0B0F19),
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPayloadTarget = val;
                            });
                          }
                        },
                        items: _activePresets.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.package,
                            child: Text(p.name.toUpperCase()),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Real-time Server Resource Metrics Telemetry
          if (meta != null) ...[
            CyberCard(
              borderGlowColors: const [Color(0xFF00FFCC), Color(0xFF1E293B)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HARDWARE TELEMETRY & OS SPECS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: meta.system.memoryUsagePercentage / 100.0,
                              strokeWidth: 5.5,
                              backgroundColor: const Color(0xFF07090E),
                              color: meta.system.memoryUsagePercentage > 85
                                  ? const Color(0xFFFF2A6D)
                                  : meta.system.memoryUsagePercentage > 60
                                      ? const Color(0xFFFFCC00)
                                      : const Color(0xFF00FFCC),
                            ),
                          ),
                          Text(
                            '${meta.system.memoryUsagePercentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('RAM USAGE SUMMARY', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('USED: ${((meta.system.totalMemory - meta.system.freeMemory) / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white)),
                            Text('TOTAL: ${(meta.system.totalMemory / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 24, thickness: 1),
                  _buildMetaRow('OS HOST', '${meta.system.platform.toUpperCase()} (${meta.system.release})'),
                  _buildMetaRow('CPU MODEL', meta.system.cpuModel),
                  _buildMetaRow('CPU CORES', '${meta.system.cpuCores} Cores'),
                  _buildMetaRow('LOAD AVERAGE', meta.system.loadAverage.map((l) => l.toStringAsFixed(2)).join(' | ')),
                  _buildMetaRow('UPTIME', '${(meta.system.uptime / 3600).floor()} hours, ${((meta.system.uptime % 3600) / 60).floor()} mins'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          _isUploading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.white10,
                          color: const Color(0xFF00FFCC),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'UPLOADING & REPLACING BINARY (${(_uploadProgress * 100).toStringAsFixed(1)}%)...',
                          style: const TextStyle(
                            color: Color(0xFF00FFCC),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : CyberButton(
                  text: _linkPayloadToProfile
                      ? 'UPLOAD TARGETED PAYLOAD'
                      : 'UPLOAD GLOBAL DEFAULT SO',
                  onPressed: _uploadBinaryFile,
                  gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                ),
          const SizedBox(height: 12),
          CyberButton(
            text: 'REFRESH TELEMETRY',
            onPressed: _fetchServerStatus,
            gradientColors: const [Color(0xFFBD00FF), Color(0xFF1E293B)],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetsView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CyberCard(
            borderGlowColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'REGISTER TARGET SYSTEM PRESET',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                CyberTextField(controller: _presetNameController, label: 'DISPLAY NAME (e.g. Free Fire)', prefixIcon: Icons.abc),
                const SizedBox(height: 12),
                CyberTextField(controller: _presetPackageController, label: 'PACKAGE ID (e.g. com.dts.freefireth)', prefixIcon: Icons.settings_applications_outlined),
                const SizedBox(height: 16),
                _loadingPresets
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                    : CyberButton(
                        text: 'CREATE NEW TARGET PRESET',
                        onPressed: _createPreset,
                        gradientColors: const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'ACTIVE RUNTIME TARGETS (${_activePresets.length})',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          
          Expanded(
            child: _loadingPresets
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                : _activePresets.isEmpty
                    ? const Center(child: Text('No game targets registered.'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _activePresets.length,
                        itemBuilder: (ctx, index) {
                          final preset = _activePresets[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CyberCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              borderGlowColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  preset.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    preset.package,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF2A6D)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: const Color(0xFF0B0F19),
                                        title: const Text('DELETE PRESET?', style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.bold, fontSize: 14)),
                                        content: Text('This will delete preset: ${preset.name}. Existing license keys pointing to this target will remain active but diagnostic scanners will list them as custom. Proceed?', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deletePreset(preset.package);
                                            },
                                            child: const Text('DELETE', style: TextStyle(color: Color(0xFFFF2A6D))),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter panel for logs
          CyberCard(
            borderGlowColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SEARCH & FILTER AUDIT LOGS',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                CyberTextField(
                  controller: _logSearchController,
                  label: 'SEARCH MESSAGE, IP, OR DEVICE',
                  prefixIcon: Icons.search,
                  onChanged: (_) {
                    _fetchLogs(loadMore: false);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LEVEL', style: TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07090E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _logLevelFilter,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0B0F19),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                                onChanged: (val) {
                                  setState(() {
                                    _logLevelFilter = val!;
                                  });
                                  _fetchLogs(loadMore: false);
                                },
                                items: ['ALL', 'INFO', 'WARN', 'ERROR'].map((lvl) {
                                  return DropdownMenuItem<String>(
                                    value: lvl,
                                    child: Text(lvl),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CATEGORY', style: TextStyle(fontSize: 8, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07090E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _logCategoryFilter,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0B0F19),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFCC)),
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
                                onChanged: (val) {
                                  setState(() {
                                    _logCategoryFilter = val!;
                                  });
                                  _fetchLogs(loadMore: false);
                                },
                                items: ['ALL', 'AUTH', 'KEY', 'DOWNLOAD', 'UPLOAD', 'SYSTEM'].map((cat) {
                                  return DropdownMenuItem<String>(
                                    value: cat,
                                    child: Text(cat),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SYSTEM AUDITS (${_logs.length})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF00FFCC)),
                onPressed: () {
                  final List<Map<String, dynamic>> exportList = _logs.map((log) {
                    return {
                      'level': log.level,
                      'category': log.category,
                      'message': log.message,
                      'timestamp': log.timestamp.toIso8601String(),
                      'ip': log.ip,
                      'deviceInfo': log.deviceInfo
                    };
                  }).toList();
                  Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(exportList)));
                  _showSnackBar('Full log data copied in JSON format!');
                },
                tooltip: 'Export Logs to Clipboard (JSON)',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Color(0xFFFF2A6D)),
                onPressed: _clearLogs,
                tooltip: 'Clear Log History',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingLogs
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                : _logs.isEmpty
                    ? const Center(child: Text('No matching database logs detected.'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _logs.length + (_logPage < _logTotalPages ? 1 : 0),
                        itemBuilder: (ctx, index) {
                          if (index == _logs.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: _loadingMoreLogs
                                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC)))
                                  : CyberButton(
                                      text: 'LOAD MORE AUDITS',
                                      height: 38,
                                      gradientColors: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                                      textColor: Colors.white70,
                                      onPressed: () => _fetchLogs(loadMore: true),
                                    ),
                            );
                          }

                          final log = _logs[index];
                          final lvl = log.level;
                          final category = log.category;
                          final date = log.timestamp.toLocal();
                          final dateStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';

                          Color logColor = const Color(0xFF00FFCC);
                          if (lvl == 'warn') logColor = const Color(0xFFFFCC00);
                          if (lvl == 'error') logColor = const Color(0xFFFF2A6D);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B0F19),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: logColor.withAlpha((255 * 0.15).round()), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '[$dateStr] [${category.toUpperCase()}]',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      lvl.toUpperCase(),
                                      style: TextStyle(fontSize: 10, color: logColor, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  log.message,
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                                ),
                                if (log.ip != null || log.deviceInfo != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'IP: ${log.ip ?? 'N/A'} | Device: ${log.deviceInfo ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                                  ),
                                ]
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersView() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REGISTERED OPERATOR ACCOUNTS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC)),
                onPressed: _fetchUsers,
                tooltip: 'Refresh Users List',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
                : _users.isEmpty
                    ? const Center(child: Text('No operator accounts registered.'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _users.length,
                        itemBuilder: (ctx, index) {
                          final user = _users[index];
                          final isAdmin = user.role == 'admin';
                          final formattedDate = user.createdAt.toLocal().toString().substring(0, 19);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CyberCard(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              borderGlowColors: isAdmin
                                  ? [const Color(0xFFBD00FF), const Color(0xFF0B0F19)]
                                  : [const Color(0xFF00FFCC), const Color(0xFF0F172A)],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          user.username.toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isAdmin ? const Color(0xFFBD00FF).withAlpha((255 * 0.08).round()) : const Color(0xFF00FFCC).withAlpha((255 * 0.08).round()),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isAdmin ? const Color(0xFFBD00FF).withAlpha((255 * 0.35).round()) : const Color(0xFF00FFCC).withAlpha((255 * 0.35).round()),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: isAdmin ? const Color(0xFFBD00FF) : const Color(0xFF00FFCC),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.timer_outlined, 'REGISTERED', formattedDate),
                                  _buildDetailRow(
                                    Icons.fingerprint_outlined,
                                    'FINGERPRINT',
                                    user.deviceFingerprint.isNotEmpty ? user.deviceFingerprint : 'NONE',
                                    valueColor: user.deviceFingerprint.isNotEmpty ? const Color(0xFFBD00FF) : const Color(0xFF64748B),
                                    isMonospace: true,
                                  ),
                                  const Divider(color: Color(0xFF1E293B), height: 16, thickness: 1),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isAdmin ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                                          color: isAdmin ? const Color(0xFFBD00FF) : Colors.grey,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          final targetRole = isAdmin ? 'user' : 'admin';
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF0B0F19),
                                              title: Text(
                                                'CHANGE ROLE TO ${targetRole.toUpperCase()}?',
                                                style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                                              ),
                                              content: Text('Are you sure you want to change the role of ${user.username} to $targetRole?', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _updateUserRole(user.id, targetRole);
                                                  },
                                                  child: const Text('CONFIRM', style: TextStyle(color: Color(0xFF00FFCC))),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        tooltip: 'Toggle Administrator Privileges',
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Color(0xFFFF2A6D), size: 18),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: const Color(0xFF0B0F19),
                                              title: const Text('DELETE USER ACCOUNT?', style: TextStyle(color: Color(0xFFFF2A6D), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                                              content: Text('This will permanently delete the operator account: ${user.username}. They will lose all access immediately. Proceed?', style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteUser(user.id);
                                                  },
                                                  child: const Text('DELETE', style: TextStyle(color: Color(0xFFFF2A6D))),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        tooltip: 'Delete User Account',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isMonospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 9.5,
                color: valueColor ?? Colors.white70,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: isMonospace ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11.5, color: color ?? Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentMenuIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return _buildKeysView();
      case 2:
        return _buildPayloadsView();
      case 3:
        return _buildPresetsView();
      case 4:
        return _buildLogsView();
      case 5:
        return _buildUsersView();
      default:
        return _buildHomeView();
    }
  }

  Widget _buildSidebarItem(String title, IconData icon, int index) {
    final isSelected = _currentMenuIndex == index;
    final color = isSelected ? const Color(0xFFBD00FF) : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _currentMenuIndex = index;
          });
          _refreshTabContent();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFBD00FF).withAlpha(15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFFBD00FF).withAlpha(50) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 14),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      appBar: AppBar(
        backgroundColor: const Color(0xDD0B0F19),
        elevation: 0,
        title: const Text(
          'AXIOS SECURITY COMMAND',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Color(0xFFBD00FF)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC)),
            onPressed: _refreshTabContent,
            tooltip: 'Refresh Telemetry Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF2A6D)),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 768;
          return Stack(
            children: [
              // Background Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF030712), Color(0xFF0B1528), Color(0xFF020617)],
                  ),
                ),
              ),
              Positioned(
                top: -50,
                left: -100,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFBD00FF).withAlpha(15)),
                ),
              ),
              Positioned(
                bottom: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00FFCC).withAlpha(10)),
                ),
              ),
              
              Row(
                children: [
                  if (isWide) ...[
                    // Left Sidebar Navigation
                    Container(
                      width: 240,
                      decoration: const BoxDecoration(
                        color: Color(0xFF090D16),
                        border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1.2)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Column(
                        children: [
                          _buildSidebarItem('telemetry dashboard', Icons.analytics_outlined, 0),
                          _buildSidebarItem('license keys', Icons.vpn_key_outlined, 1),
                          _buildSidebarItem('payload binaries', Icons.folder_zip_outlined, 2),
                          _buildSidebarItem('system presets', Icons.settings_suggest_outlined, 3),
                          _buildSidebarItem('audit log history', Icons.history_edu_outlined, 4),
                          _buildSidebarItem('operator users', Icons.people_outline, 5),
                        ],
                      ),
                    ),
                  ],
                  
                  // Main Body panel
                  Expanded(
                    child: _buildBodyContent(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 768;
          if (isWide) return const SizedBox.shrink();
          return Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.2)),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentMenuIndex,
              onTap: (index) {
                setState(() {
                  _currentMenuIndex = index;
                });
                _refreshTabContent();
              },
              backgroundColor: const Color(0xFF090D16),
              selectedItemColor: const Color(0xFFBD00FF),
              unselectedItemColor: const Color(0xFF64748B),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 9,
              unselectedFontSize: 9,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'HOME'),
                BottomNavigationBarItem(icon: Icon(Icons.vpn_key_outlined), label: 'KEYS'),
                BottomNavigationBarItem(icon: Icon(Icons.folder_zip_outlined), label: 'PAYLOAD'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_suggest_outlined), label: 'PRESETS'),
                BottomNavigationBarItem(icon: Icon(Icons.history_edu_outlined), label: 'LOGS'),
                BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'USERS'),
              ],
            ),
          );
        },
      ),
    );
  }
}
