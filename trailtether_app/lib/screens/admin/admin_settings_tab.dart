import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../services/logger_service.dart';
import '../../services/offline_map_service.dart';

class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  final _supabase = Supabase.instance.client;
  bool _maintenanceMode = false;
  bool _registrationOpen = true;
  double _gpsThreshold = 25.0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final res = await _supabase
          .from(kColIncidents)
          .select()
          .eq('id', '00000000-0000-0000-0000-000000000000')
          .maybeSingle();
      if (res != null && res['metadata'] != null) {
        final meta = res['metadata'] as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _maintenanceMode = meta['maintenance_mode'] ?? false;
            _registrationOpen = meta['registration_open'] ?? true;
            _gpsThreshold = (meta['gps_threshold'] ?? 25.0).toDouble();
          });
        }
      }
    } catch (e, stack) {
      LoggerService.error(
          'ADMIN_SETTINGS', 'Failed to load config: $e', stack);
    }
  }

  Future<void> _saveConfig() async {
    try {
      await _supabase.from(kColIncidents).upsert({
        'id': '00000000-0000-0000-0000-000000000000',
        'type': 'system_config',
        'title': 'GLOBAL CONFIG',
        'metadata': {
          'maintenance_mode': _maintenanceMode,
          'registration_open': _registrationOpen,
          'gps_threshold': _gpsThreshold,
        },
        'status': 'closed',
        'lat': 0,
        'lon': 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('System configuration updated globally')));
      }
    } catch (e, stack) {
      LoggerService.error(
          'ADMIN_SETTINGS', 'Failed to save config: $e', stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Configuration',
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Global flags and environment parameters for the Trailtether ecosystem.',
            style: GoogleFonts.outfit(
              color: kColorCream.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildSection('Operational Status', [
                  _buildToggle(
                      'Maintenance Mode',
                      'Offline the mobile app for updates.',
                      _maintenanceMode,
                      (v) => setState(() {
                            _maintenanceMode = v;
                            _saveConfig();
                          })),
                  _buildToggle(
                      'New Registrations',
                      'Allow new users to create accounts.',
                      _registrationOpen,
                      (v) => setState(() {
                            _registrationOpen = v;
                            _saveConfig();
                          })),
                ]),
                const SizedBox(height: 32),
                _buildSection('Telemetry & GPS', [
                  _buildSlider(
                      'Accuracy Threshold',
                      'Minimum GPS accuracy (meters).',
                      _gpsThreshold,
                      (v) => setState(() {
                            _gpsThreshold = v;
                            _saveConfig();
                          })),
                ]),
                const SizedBox(height: 32),
                _buildSection('Danger Zone', [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _purgeCache,
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      label: const Text('Purge Global Map Cache'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: kColorOrange,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kColorGlass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kColorBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggle(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: kColorOrange,
      ),
    );
  }

  Widget _buildSlider(String title, String subtitle, double value,
      ValueChanged<double> onChanged) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
      trailing: SizedBox(
        width: 200,
        child: Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: 5,
                max: 100,
                divisions: 19,
                activeColor: kColorOrange,
                onChanged: onChanged,
              ),
            ),
            Text('${value.toInt()}m',
                style: const TextStyle(
                    color: kColorOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _purgeCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title: const Text('Purge System Cache?',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
            'This will clear all offline map tiles and cached routes. Field devices will be forced to re-download data on their next sync.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirm Purge'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await OfflineMapService.clearCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Global cache purged successfully')));
        }
      } catch (e, stack) {
        LoggerService.error(
            'ADMIN_SETTINGS', 'Failed to purge cache: $e', stack);
      }
    }
  }
}
