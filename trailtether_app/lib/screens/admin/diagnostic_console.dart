import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/logger_service.dart';
import '../../core/constants.dart';

class DiagnosticConsole extends StatefulWidget {
  const DiagnosticConsole({super.key});

  @override
  State<DiagnosticConsole> createState() => _DiagnosticConsoleState();
}

class _DiagnosticConsoleState extends State<DiagnosticConsole> {
  final List<String> _localLogs = [];
  final List<Map<String, dynamic>> _remoteLogs = [];
  bool _showRemote = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _logSub;

  @override
  void initState() {
    super.initState();
    _localLogs.addAll(LoggerService.memoryLogs);
    LoggerService.addListener(_onLocalLog);
    _setupRemoteLogging();
  }

  void _setupRemoteLogging() {
    _logSub = Supabase.instance.client
        .from('app_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(100)
        .listen((data) {
          if (mounted) {
            setState(() {
              _remoteLogs.clear();
              _remoteLogs.addAll(data);
            });
          }
        });
  }

  void _onLocalLog(String log) {
    if (mounted) {
      setState(() {
        _localLogs.add(log);
        if (_localLogs.length > 500) _localLogs.removeAt(0);
      });
      if (!_showRemote) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    LoggerService.removeListener(_onLocalLog);
    _logSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        title: Text('System Diagnostics', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          Switch(
            value: _showRemote,
            onChanged: (v) => setState(() => _showRemote = v),
            activeColor: kColorOrange,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(child: Text(_showRemote ? 'REMOTE' : 'LOCAL', style: const TextStyle(fontSize: 10))),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => LoggerService.shareLogs(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _localLogs.clear()),
          ),
        ],
      ),
      body: _showRemote ? _buildRemoteList() : _buildLocalList(),
    );
  }

  Widget _buildLocalList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _localLogs.length,
      itemBuilder: (context, index) {
        final log = _localLogs[index];
        final isError = log.contains('[ERROR]');
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            log,
            style: GoogleFonts.firaCode(
              color: isError ? Colors.redAccent : Colors.white70,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteList() {
    if (_remoteLogs.isEmpty) {
      return const Center(child: Text('No remote logs found.', style: TextStyle(color: Colors.white24)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _remoteLogs.length,
      itemBuilder: (context, index) {
        final log = _remoteLogs[index];
        final platform = log['platform'] ?? 'unknown';
        final tag = log['tag'] ?? 'info';
        final msg = log['message'] ?? '';
        final time = DateTime.parse(log['created_at']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: kColorOrange, borderRadius: BorderRadius.circular(2)),
                    child: Text(platform.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(tag, style: const TextStyle(color: kColorOrange, fontSize: 10, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(time.toString().split('.').first, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg, style: GoogleFonts.firaCode(color: Colors.white, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}
