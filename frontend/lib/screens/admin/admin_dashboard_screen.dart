import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/config_service.dart';
import '../../services/download_service.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/cyber_button.dart';
import '../../widgets/cyber_text_field.dart';
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
  List<dynamic> _keys = [];
  bool _loadingKeys = false;
  final _keyPrefixController = TextEditingController();
  final _keyCountController = TextEditingController(text: '1');
  final _keyUsesController = TextEditingController(text: '1');
  final _keyExpiryController = TextEditingController();
  final _keyAssignedToController = TextEditingController();

  // Logs State
  List<dynamic> _logs = [];
  bool _loadingLogs = false;

  // Server Payload State
  Map<String, dynamic>? _serverStatus;
  bool _loadingStatus = false;
  bool _isUploading = false;

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
    if (_tabController.index == 0) {
      _fetchKeys();
    } else if (_tabController.index == 1) {
      _fetchServerStatus();
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
    super.dispose();
  }

  Future<void> _logout() async {
    await ConfigService().clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
    );
  }

  // --- API CALLS ---

  Future<void> _fetchKeys() async {
    setState(() => _loadingKeys = true);
    try {
      final config = ConfigService();
      final response = await _dio.get(
        '${config.backendUrl}/api/keys',
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );
      if (response.statusCode == 200 && response.data['keys'] != null) {
        setState(() {
          _keys = response.data['keys'];
        });
      }
    } catch (e) {
      _showSnackBar('Failed to fetch access keys.', isError: true);
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
        },
        options: Options(headers: {'Authorization': 'Bearer ${config.token}'}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Keys generated successfully.');
        _keyPrefixController.clear();
        _keyExpiryController.clear();
        _keyAssignedToController.clear();
        _keyCountController.text = '1';
        _keyUsesController.text = '1';
        _fetchKeys();
      }
    } catch (e) {
      _showSnackBar('Failed to generate keys.', isError: true);
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
      _showSnackBar('Failed to toggle key status.', isError: true);
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
      _showSnackBar('Failed to delete key.', isError: true);
    }
  }

  Future<void> _fetchServerStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final status = await _downloadService.checkStatus(ConfigService().backendUrl);
      if (status != null) {
        setState(() {
          _serverStatus = status;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to reach backend status.', isError: true);
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
        setState(() {
          _logs = response.data['logs'];
        });
      }
    } catch (e) {
      _showSnackBar('Failed to fetch system logs.', isError: true);
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
      _showSnackBar('Failed to clear logs.', isError: true);
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

  // --- SUB-PANEL RENDERS ---

  Widget _buildKeysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Generator Form
          CyberCard(
            borderGlowColors: const [Color(0x3300FFCC), Color(0x33BD00FF)],
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
                      child: CyberTextField(controller: _keyPrefixController, label: 'PREFIX (e.g. PREMIUM)', prefixIcon: Icons.label_outline),
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
          const Text(
            'ACTIVE LICENSES',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          _loadingKeys
              ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFF00FFCC))))
              : _keys.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No keys generated.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _keys.length,
                      itemBuilder: (ctx, index) {
                        final k = _keys[index];
                        final active = k['isActive'] as bool;
                        return Card(
                          color: const Color(0xFF0B0F19),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              k['key'],
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00FFCC)),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Usages: ${k['usesCount']}/${k['maxUses']} | Game: Last Island',
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Owner: ${k['assignedTo'] != null && k['assignedTo'].toString().isNotEmpty ? k['assignedTo'] : 'Unassigned (binds on first use)'}',
                                  style: TextStyle(
                                    color: k['assignedTo'] != null && k['assignedTo'].toString().isNotEmpty
                                        ? const Color(0xFF00FFCC)
                                        : const Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Expires: ${k['expiresAt'] != null ? DateTime.parse(k['expiresAt']).toLocal().toString().substring(0, 19) : 'Never'}',
                                  style: TextStyle(
                                    color: k['expiresAt'] != null && DateTime.parse(k['expiresAt']).isBefore(DateTime.now())
                                        ? const Color(0xFFFF2A6D)
                                        : const Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                                if (k['deviceFingerprint'] != null && k['deviceFingerprint'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fingerprint: ${k['deviceFingerprint']}',
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
                                IconButton(
                                  icon: const Icon(Icons.copy_all_outlined, color: Color(0xFF00FFCC), size: 20),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: k['key']));
                                    _showSnackBar('Key copied to clipboard!');
                                  },
                                  tooltip: 'Copy Key',
                                ),
                                Switch(
                                  value: active,
                                  onChanged: (_) => _toggleKey(k['_id']),
                                  activeTrackColor: const Color(0xFF00FFCC),
                                  activeThumbColor: Colors.black,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFFF2A6D)),
                                  onPressed: () => _deleteKey(k['_id']),
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

  Widget _buildPayloadTab() {
    if (_loadingStatus) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)));
    }

    final meta = _serverStatus;
    final exists = meta?['binaryExists'] == true;
    final sizeMb = ((meta?['binarySize'] ?? 0) / (1024 * 1024)).toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CyberCard(
            borderGlowColors: const [Color(0x33BD00FF), Color(0x3300FFCC)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SERVER CORE BINARY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                _buildMetaRow('STATUS', meta?['status']?.toUpperCase() ?? 'OFFLINE', color: meta?['status'] == 'online' ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
                _buildMetaRow('FILE STATE', exists ? 'AVAILABLE' : 'MISSING', color: exists ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
                _buildMetaRow('BINARY SIZE', '$sizeMb MB'),
                _buildMetaRow('STORAGE DIR', meta?['config']?['uploadDir'] ?? 'N/A'),
                _buildMetaRow('MOCK GENERATION', meta?['config']?['mockBinaryEnabled'] == true ? 'ENABLED' : 'DISABLED'),
                _buildMetaRow('DB CONNECTIVITY', meta?['config']?['dbStatus']?.toUpperCase() ?? 'DISCONNECTED', color: meta?['config']?['dbStatus'] == 'connected' ? const Color(0xFF00FFCC) : const Color(0xFFFF2A6D)),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
            text: 'REFRESH METADATA',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SYSTEM ACTIVITY & AUDITS',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF64748B)),
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
                    ? const Center(child: Text('No database logs detected.'))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (ctx, index) {
                          final log = _logs[index];
                          final lvl = log['level'] as String;
                          final category = log['category'] as String;
                          final date = DateTime.parse(log['timestamp']).toLocal();
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
                                  log['message'],
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white, fontFamily: 'monospace'),
                                ),
                                if (log['ip'] != null || log['deviceInfo'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'IP: ${log['ip'] ?? 'N/A'} | Device: ${log['deviceInfo'] ?? 'N/A'}',
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
          Text(value, style: TextStyle(fontSize: 11.5, color: color ?? Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        elevation: 1,
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKeysTab(),
          _buildPayloadTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }
}
