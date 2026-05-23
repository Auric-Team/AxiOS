import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/config_service.dart';
import '../../services/download_service.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/cyber_button.dart';
import '../../widgets/cyber_text_field.dart';
import '../../config.dart';
import '../../models/access_key.dart';
import '../../models/audit_log.dart';
import '../../models/system_status.dart';
import '../auth_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DownloadService _downloadService = DownloadService();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 15),
      receiveTimeout: const Duration(minutes: 15),
    ),
  );
  double _uploadProgress = 0.0;

  // License Keys State
  List<AccessKey> _keys = [];
  bool _loadingKeys = false;
  final _keyPrefixController = TextEditingController();
  final _keyCountController = TextEditingController(text: '1');
  final _keyUsesController = TextEditingController(text: '1');
  final _keyExpiryController = TextEditingController();
  final _keyAssignedToController = TextEditingController();

  // Custom Target Game State
  String _selectedTargetPreset = 'com.herogame.gplay.lastdayrulessurvival';
  bool _isCustomTarget = false;
  final _customTargetController = TextEditingController();

  // Keys Filter/Search State
  final _keySearchController = TextEditingController();
  String _keyStatusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE, ASSIGNED, UNASSIGNED

  // Logs State
  List<AuditLog> _logs = [];
  bool _loadingLogs = false;

  // Logs Filter/Search State
  final _logSearchController = TextEditingController();
  String _logLevelFilter = 'ALL'; // ALL, INFO, WARN, ERROR
  String _logCategoryFilter = 'ALL'; // ALL, AUTH, KEY, SYSTEM

  // Server Payload & Diagnostic State
  SystemStatus? _serverStatus;
  bool _loadingStatus = false;
  bool _isUploading = false;
  int? _serverLatencyMs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _refreshTabContent();
    });
    _refreshTabContent();
  }

  void _refreshTabContent() {
    _measureLatency();
    _fetchServerStatus();
    if (_tabController.index == 0) {
      _fetchKeys();
    } else if (_tabController.index == 1) {
      // Server status is fetched globally
    } else if (_tabController.index == 2) {
      _fetchLogs();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyPrefixController.dispose();
    _keyCountController.dispose();
    _keyUsesController.dispose();
    _keyExpiryController.dispose();
    _keyAssignedToController.dispose();
    _customTargetController.dispose();
    _keySearchController.dispose();
    _logSearchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ConfigService().clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
    );
  }

  void _handleException(dynamic e, String defaultMessage) {
    if (!mounted) return;
    if (e is DioException) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _showSnackBar('Session expired or unauthorized. Logging out...', isError: true);
        _logout();
        return;
      }
      final errorMsg = e.response?.data != null && e.response?.data['error'] != null
          ? e.response?.data['error'].toString()
          : defaultMessage;
      _showSnackBar(errorMsg!, isError: true);
    } else {
      _showSnackBar(defaultMessage, isError: true);
    }
  }

  // --- API CALLS ---

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

  Future<void> _fetchKeys() async {
    setState(() => _loadingKeys = true);
    try {
      final config = ConfigService();
      final response = await _dio.get(
        '${config.backendUrl}/api/keys',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      if (response.statusCode == 200 && response.data['keys'] != null) {
        final list = response.data['keys'] as List;
        setState(() {
          _keys = list.map((k) => AccessKey.fromJson(k)).toList();
        });
      }
    } catch (e) {
      _handleException(e, 'Failed to fetch access keys.');
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
      final response = await _dio.post(
        '${config.backendUrl}/api/keys/generate',
        data: {
          'prefix': prefix.isEmpty ? null : prefix,
          'count': count,
          'maxUses': uses,
          'expiresInHours': expiryHours,
          'assignedTo': assignedTo.isEmpty ? null : assignedTo,
          'targetGame': target,
        },
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Keys generated successfully.');
        _keyPrefixController.clear();
        _keyExpiryController.clear();
        _keyAssignedToController.clear();
        _customTargetController.clear();
        _keyCountController.text = '1';
        _keyUsesController.text = '1';
        _fetchKeys();
      }
    } catch (e) {
      _handleException(e, 'Failed to generate keys.');
    }
  }

  Future<void> _toggleKey(String keyId) async {
    try {
      final config = ConfigService();
      await _dio.patch(
        '${config.backendUrl}/api/keys/$keyId/status',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      _fetchKeys();
    } catch (e) {
      _handleException(e, 'Failed to toggle key status.');
    }
  }

  Future<void> _deleteKey(String keyId) async {
    try {
      final config = ConfigService();
      await _dio.delete(
        '${config.backendUrl}/api/keys/$keyId',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      _showSnackBar('Key deleted.');
      _fetchKeys();
    } catch (e) {
      _handleException(e, 'Failed to delete key.');
    }
  }

  Future<void> _resetFingerprint(String keyId) async {
    try {
      final config = ConfigService();
      await _dio.patch(
        '${config.backendUrl}/api/keys/$keyId/reset-fingerprint',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      _showSnackBar('Device fingerprint reset successfully.');
      _fetchKeys();
    } catch (e) {
      _handleException(e, 'Failed to reset device fingerprint.');
    }
  }

  Future<void> _deactivateAll() async {
    try {
      final config = ConfigService();
      final response = await _dio.patch(
        '${config.backendUrl}/api/keys/deactivate-all',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      if (response.statusCode == 200) {
        _showSnackBar(response.data['message'] ?? 'All keys deactivated.');
        _fetchKeys();
      }
    } catch (e) {
      _handleException(e, 'Failed to deactivate all keys.');
    }
  }

  Future<void> _pruneKeys() async {
    try {
      final config = ConfigService();
      final response = await _dio.delete(
        '${config.backendUrl}/api/keys/prune-inactive',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      if (response.statusCode == 200) {
        _showSnackBar(response.data['message'] ?? 'Inactive/expired keys pruned.');
        _fetchKeys();
      }
    } catch (e) {
      _handleException(e, 'Failed to prune keys.');
    }
  }

  Future<void> _fetchServerStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final status = await _downloadService.checkStatus(ConfigService().backendUrl);
      if (status != null) {
        setState(() {
          _serverStatus = SystemStatus.fromJson(status);
        });
      }
    } catch (e) {
      // Fail silently
    } finally {
      setState(() => _loadingStatus = false);
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
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'libil2cpp.so'),
      });

      final response = await _dio.post(
        '${config.backendUrl}/api/upload',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${config.token}'},
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('libil2cpp.so uploaded and replaced successfully!');
        _fetchServerStatus();
      } else {
        _showSnackBar('Upload failed. Server returned status code ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Exception during file upload: $e', isError: true);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _fetchLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final config = ConfigService();
      final response = await _dio.get(
        '${config.backendUrl}/api/logs',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      if (response.statusCode == 200 && response.data['logs'] != null) {
        final list = response.data['logs'] as List;
        setState(() {
          _logs = list.map((l) => AuditLog.fromJson(l)).toList();
        });
      }
    } catch (e) {
      _handleException(e, 'Failed to fetch system logs.');
    } finally {
      setState(() => _loadingLogs = false);
    }
  }

  Future<void> _clearLogs() async {
    try {
      final config = ConfigService();
      await _dio.delete(
        '${config.backendUrl}/api/logs',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      _showSnackBar('Logs cleared.');
      _fetchLogs();
    } catch (e) {
      _handleException(e, 'Failed to clear logs.');
    }
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

  // --- LOCAL FILTER SELECTORS ---

  List<AccessKey> get _filteredKeys {
    final query = _keySearchController.text.trim().toLowerCase();
    return _keys.where((k) {
      // 1. Status Filter
      if (_keyStatusFilter == 'ACTIVE' && k.isActive != true) return false;
      if (_keyStatusFilter == 'INACTIVE' && k.isActive == true) return false;
      final assigned = k.assignedTo.isNotEmpty;
      if (_keyStatusFilter == 'ASSIGNED' && !assigned) return false;
      if (_keyStatusFilter == 'UNASSIGNED' && assigned) return false;

      // 2. Search query (matches key, assignedTo, or targetGame)
      if (query.isNotEmpty) {
        final keyMatch = k.key.toLowerCase().contains(query);
        final ownerMatch = k.assignedTo.toLowerCase().contains(query);
        final targetMatch = k.targetGame.toLowerCase().contains(query);
        return keyMatch || ownerMatch || targetMatch;
      }
      return true;
    }).toList();
  }

  List<AuditLog> get _filteredLogs {
    final query = _logSearchController.text.trim().toLowerCase();
    return _logs.where((log) {
      // 1. Level filter
      final lvl = log.level.toLowerCase();
      if (_logLevelFilter != 'ALL' && lvl != _logLevelFilter.toLowerCase()) return false;

      // 2. Category filter
      final category = log.category.toLowerCase();
      if (_logCategoryFilter != 'ALL' && category != _logCategoryFilter.toLowerCase()) return false;

      // 3. Search query
      if (query.isNotEmpty) {
        final msgMatch = log.message.toLowerCase().contains(query);
        final ipMatch = log.ip?.toLowerCase().contains(query) ?? false;
        final deviceMatch = log.deviceInfo?.toLowerCase().contains(query) ?? false;
        return msgMatch || ipMatch || deviceMatch;
      }
      return true;
    }).toList();
  }

  String _getGameDisplayName(String package) {
    for (var preset in AppConfig.presets) {
      if (preset.package == package) {
        return preset.name;
      }
    }
    if (package.length > 28) {
      return '...${package.substring(package.length - 25)}';
    }
    return package;
  }

  // --- SUB-PANEL RENDERS ---

  Widget _buildStatsOverview() {
    final meta = _serverStatus;
    final exists = meta?.binaryExists == true;
    final sizeMb = exists ? (meta!.binarySize / (1024 * 1024)).toStringAsFixed(2) : '0.00';
    final dbConnected = meta?.config.dbStatus == 'connected';

    final totalKeysCount = _keys.length;
    final activeKeysCount = _keys.where((k) => k.isActive).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
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
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: isWide ? 2.5 : 1.8,
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
      ),
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

  Widget _buildKeysTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
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
                
                // Target Game Package Selector Dropdown
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
                      value: _isCustomTarget ? 'CUSTOM' : _selectedTargetPreset,
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
                        ...AppConfig.presets.map((preset) {
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

          Text(
            'ACTIVE LICENSES (${_filteredKeys.length})',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            borderGlowColors: active
                                ? [const Color(0xFF00FFCC), const Color(0xFF0B0F19)]
                                : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                            child: ListTile(
                              title: Text(
                                k.key,
                                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00FFCC)),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Usages: ${k.usesCount}/${k.maxUses} | Game: ${_getGameDisplayName(gamePkg)}',
                                    style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Owner: ${k.assignedTo.isNotEmpty ? k.assignedTo : 'Unassigned (binds on first use)'}',
                                    style: TextStyle(
                                      color: k.assignedTo.isNotEmpty
                                          ? const Color(0xFF00FFCC)
                                          : const Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Expires: ${k.expiresAt != null ? k.expiresAt!.toLocal().toString().substring(0, 19) : 'Never'}',
                                    style: TextStyle(
                                      color: k.isExpired
                                          ? const Color(0xFFFF2A6D)
                                          : const Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (k.deviceFingerprint.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Fingerprint: ${k.deviceFingerprint}',
                                      style: const TextStyle(
                                        color: Color(0xFFBD00FF),
                                        fontSize: 9.5,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (k.deviceFingerprint.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.phonelink_erase, color: Color(0xFFBD00FF), size: 20),
                                      onPressed: () => _resetFingerprint(k.id),
                                      tooltip: 'Reset Binding Fingerprint',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF00FFCC), size: 20),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: k.key));
                                      _showSnackBar('Key copied to clipboard!');
                                    },
                                    tooltip: 'Copy Key',
                                  ),
                                  Switch(
                                    value: active,
                                    onChanged: (_) => _toggleKey(k.id),
                                    activeTrackColor: const Color(0xFF00FFCC),
                                    activeThumbColor: Colors.black,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF2A6D)),
                                    onPressed: () => _deleteKey(k.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildPayloadTab() {
    if (_loadingStatus) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)));
    }

    final meta = _serverStatus;
    final exists = meta?.binaryExists == true;
    final sizeMb = meta != null ? (meta.binarySize / (1024 * 1024)).toStringAsFixed(2) : '0.00';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Server Core Binary Card
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
                  
                  // Memory (RAM) Custom Progress indicator
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
                  text: 'UPLOAD NEW LIBIL2CPP.SO',
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

  Widget _buildLogsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
                    setState(() {});
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
                                },
                                items: ['ALL', 'AUTH', 'KEY', 'SYSTEM'].map((cat) {
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
              Text(
                'SYSTEM ACTIVITY & AUDITS (${_filteredLogs.length})',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
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
                : _filteredLogs.isEmpty
                    ? const Center(child: Text('No matching database logs detected.'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (ctx, index) {
                          final log = _filteredLogs[index];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      appBar: AppBar(
        backgroundColor: const Color(0xDD0B0F19),
        elevation: 0,
        title: const Text(
          'ADMIN PANEL CONTROL',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: Color(0xFFBD00FF)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00FFCC)),
            onPressed: _refreshTabContent,
            tooltip: 'Refresh Current Tab',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF2A6D)),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFBD00FF),
          labelColor: const Color(0xFFBD00FF),
          unselectedLabelColor: const Color(0xFF64748B),
          tabs: const [
            Tab(text: 'KEYS', icon: Icon(Icons.key)),
            Tab(text: 'BINARY', icon: Icon(Icons.folder)),
            Tab(text: 'LOGS', icon: Icon(Icons.receipt_long)),
          ],
        ),
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
            top: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBD00FF).withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FFCC).withAlpha(15),
              ),
            ),
          ),

          // Main body content
          Column(
            children: [
              _buildStatsOverview(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKeysTab(),
                    _buildPayloadTab(),
                    _buildLogsTab(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
