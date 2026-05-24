import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../widgets/common/cyber_card.dart';
import '../../widgets/common/cyber_button.dart';

class SystemHudSheet extends StatefulWidget {
  const SystemHudSheet({super.key});

  @override
  State<SystemHudSheet> createState() => _SystemHudSheetState();
}

class _SystemHudSheetState extends State<SystemHudSheet> {
  final Map<String, String> _specs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeviceSpecs();
  }

  Future<void> _loadDeviceSpecs() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        setState(() {
          _specs['DEVICE BRAND'] = android.brand.toUpperCase();
          _specs['MODEL ID'] = android.model.toUpperCase();
          _specs['HARDWARE BOARD'] = android.board.toUpperCase();
          _specs['SUPPORTED ARCHS'] = android.supportedAbis.join(', ').toUpperCase();
          _specs['OS VERSION'] = 'ANDROID ${android.version.release} (API ${android.version.sdkInt})';
          _specs['BUILD TAG'] = android.display;
          _specs['BOOTLOADER'] = android.bootloader.toUpperCase();
          _specs['HOST INTERFACE'] = android.host.toUpperCase();
          _specs['DEVICE TYPE'] = android.isPhysicalDevice ? 'PHYSICAL ENVIRONMENT' : 'EMULATED ENVIRONMENT';
        });
      } else {
        setState(() {
          _specs['SYSTEM PLATFORM'] = Platform.operatingSystem.toUpperCase();
          _specs['VERSION RELEASE'] = Platform.operatingSystemVersion;
          _specs['LOCAL HOSTNAME'] = Platform.localHostname;
          _specs['CPU CORES'] = '${Platform.numberOfProcessors} AVAILABLE CORES';
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF06090F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Slide indicator
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.developer_board, color: Color(0xFF00FFCC), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'SYSTEM HARDWARE HUD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                PulseTag(status: _specs['DEVICE TYPE'] ?? 'ONLINE'),
              ],
            ),
            const SizedBox(height: 20),
            _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                    ),
                  )
                : Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: CyberCard(
                        borderGlowColors: const [Color(0xFFBD00FF), Color(0xFF00FFCC)],
                        showCornerBrackets: true,
                        child: Column(
                          children: _specs.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 6,
                                    child: Text(
                                      entry.value,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 20),
            CyberButton(
              text: 'CLOSE HARDWARE HUD',
              onPressed: () => Navigator.pop(context),
              gradientColors: const [Color(0xFFFF2A6D), Color(0xFF7B00C7)],
              textColor: Colors.white,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}

class PulseTag extends StatefulWidget {
  final String status;
  const PulseTag({super.key, required this.status});

  @override
  State<PulseTag> createState() => _PulseTagState();
}

class _PulseTagState extends State<PulseTag> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.status.contains('PHYSICAL') ? const Color(0xFF00FFCC) : const Color(0xFFBD00FF);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (ctx, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.05 * _pulse.value).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha((255 * 0.3 * _pulse.value).round()), width: 0.8),
          ),
          child: Text(
            widget.status,
            style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }
}
