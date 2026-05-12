import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/logger_service.dart';

class AdminLogsTab extends StatefulWidget {
  const AdminLogsTab({super.key});

  @override
  State<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends State<AdminLogsTab> {
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  List<String> _logs = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _logs = LoggerService.memoryLogs.reversed.toList();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> get _filteredLogs {
    if (_filter.isEmpty) return _logs;
    final lower = _filter.toLowerCase();
    return _logs.where((l) => l.toLowerCase().contains(lower)).toList();
  }

  Color _logColor(String line) {
    if (line.contains('[ERROR]')) return Colors.redAccent;
    if (line.contains('EMERGENCY')) return Colors.red;
    if (line.contains('WARNING') || line.contains('WARN')) return Colors.amber;
    if (line.contains('NOTIFICATIONS')) return Colors.cyanAccent;
    if (line.contains('STATIC_DATA') || line.contains('GPX')) {
      return Colors.greenAccent;
    }
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Logs',
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 32,
                        fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${filtered.length} entries — auto-refreshes every 2s',
                    style: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.5), fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      onChanged: (v) => setState(() => _filter = v),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Filter logs...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.2)),
                        prefixIcon: const Icon(Icons.search,
                            color: kColorOrange, size: 18),
                        filled: true,
                        fillColor: kColorGlass,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _filteredLogs.join('\n')));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Logs copied to clipboard')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kColorOrange.withOpacity(0.1),
                      foregroundColor: kColorOrange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side:
                              BorderSide(color: kColorOrange.withOpacity(0.3))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await LoggerService.clearLogs();
                      _refresh();
                    },
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: Colors.redAccent.withOpacity(0.3))),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF050505),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kColorBorder),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No log entries.',
                          style:
                              TextStyle(color: kColorCream.withOpacity(0.2))))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final line = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            line,
                            style: GoogleFonts.firaCode(
                              color: _logColor(line),
                              fontSize: 11,
                              height: 1.6,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
