import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import '../models/incident.dart';
import '../services/incident_service.dart';
import '../services/location_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _holdController;
  Position? _currentPos;
  bool _triggered = false;
  IncidentType _sosType = IncidentType.medicalEmergency;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_triggered) {
          _triggerSos();
        }
      });

    _updateLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdController.dispose();
    super.dispose();
  }

  Future<void> _updateLocation() async {
    try {
      final pos = await LocationService.currentPosition();
      if (mounted) setState(() => _currentPos = pos);
    } catch (e, stack) {
      LoggerService.error('SOS', 'Failed to fetch current location: $e', stack);
    }
  }

  Future<void> _triggerSos() async {
    if (_triggered) return;

    if (_currentPos == null) {
      await _updateLocation();
    }

    if (_currentPos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot send SOS without GPS location. Please ensure GPS is enabled.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _triggered = true);
    await HapticFeedback.vibrate();

    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null || uid.isEmpty) {
        throw Exception('You must be signed in to send SOS.');
      }

      final deviceId = await TrailUtils.getDeviceId();
      final now = DateTime.now();
      
      String specificDesc = 'SOS emergency broadcast. Immediate assistance required.';
      if (_sosType == IncidentType.lostOrDisoriented) {
        specificDesc = 'SOS: User is LOST or DISORIENTED. Assistance required for navigation/rescue.';
      } else if (_sosType == IncidentType.stuckOrTrapped) {
        specificDesc = 'SOS: User is STUCK or TRAPPED (Cliff/Valley). Technical rescue may be required.';
      }

      final incident = Incident(
        id: '',
        lat: _currentPos!.latitude,
        lon: _currentPos!.longitude,
        type: _sosType,
        severity: IncidentSeverity.critical,
        description: specificDesc,
        incidentDate: now,
        reportedAt: now,
        deviceId: deviceId,
        createdBy: uid,
        isEmergency: true,
      );

      // Bound the upload — if it can't reach the server in 15s, fail loudly
      // so the user knows to use another channel (phone, satellite, etc.).
      await IncidentService.addIncident(incident).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
            'Could not reach Trailtether servers within 15 seconds.'),
      );

      LoggerService.log(
          'SOS', 'Broadcast accepted by server. uid=$uid lat=${incident.lat} '
              'lon=${incident.lon}');

      // Local notification is best-effort — don't fail the SOS if it errors.
      try {
        await NotificationService.instance.showNotification(
          id: 999,
          title: 'SOS BROADCAST ACTIVE',
          body:
              'Emergency incident shared with nearby Trailtether users. Contact emergency services directly if needed.',
          isEmergency: true,
        );
      } catch (e, stack) {
        LoggerService.error(
            'SOS', 'Local SOS notification failed (non-fatal): $e', stack);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'SOS broadcast sent. Now contact emergency services directly.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 10),
          ),
        );
      }
    } catch (e, stack) {
      LoggerService.error('SOS', 'Failed to broadcast SOS: $e', stack);
      if (mounted) {
        setState(() => _triggered = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOS NOT SENT — $e\nUse phone/satellite to contact emergency services.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red.shade900,
            duration: const Duration(seconds: 12),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _triggerSos,
            ),
          ),
        );
      }
    }
  }

  void _onHoldStart() async {
    if (_triggered) return;
    await HapticFeedback.heavyImpact();
    await _holdController.forward();
  }

  void _onHoldEnd() {
    if (_triggered) return;
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ringSize =
        (MediaQuery.sizeOf(context).width - 80).clamp(180.0, 220.0).toDouble();
    final buttonSize = ringSize - 40;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'EMERGENCY SOS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity:
                        _pulseController.drive(Tween(begin: 0.4, end: 1.0)),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.2),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emergency_share,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'YOUR CURRENT LOCATION',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_currentPos != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${_currentPos!.latitude.toStringAsFixed(6)}, ${_currentPos!.longitude.toStringAsFixed(6)}',
                        maxLines: 1,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(
                      height: 30,
                      width: 30,
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 2,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (!_triggered) ...[
                    Text(
                      'SELECT EMERGENCY TYPE',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SosTypeChip(
                          type: IncidentType.medicalEmergency,
                          selected: _sosType == IncidentType.medicalEmergency,
                          onTap: () => setState(
                              () => _sosType = IncidentType.medicalEmergency),
                        ),
                        const SizedBox(width: 8),
                        _SosTypeChip(
                          type: IncidentType.lostOrDisoriented,
                          selected: _sosType == IncidentType.lostOrDisoriented,
                          onTap: () => setState(
                              () => _sosType = IncidentType.lostOrDisoriented),
                        ),
                        const SizedBox(width: 8),
                        _SosTypeChip(
                          type: IncidentType.stuckOrTrapped,
                          selected: _sosType == IncidentType.stuckOrTrapped,
                          onTap: () => setState(
                              () => _sosType = IncidentType.stuckOrTrapped),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _sosType.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _sosType.color, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_sosType.emoji,
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            _sosType.label.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTapDown: (_) => _onHoldStart(),
                    onTapUp: (_) => _onHoldEnd(),
                    onTapCancel: _onHoldEnd,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _holdController,
                          builder: (context, child) => SizedBox(
                            width: ringSize,
                            height: ringSize,
                            child: CircularProgressIndicator(
                              value: _triggered ? 1.0 : _holdController.value,
                              strokeWidth: 10,
                              backgroundColor: Colors.white10,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        Container(
                          width: buttonSize,
                          height: buttonSize,
                          decoration: BoxDecoration(
                            color: _triggered
                                ? Colors.red.withOpacity(0.3)
                                : Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (!_triggered)
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 30,
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _triggered
                                  ? 'SENT'
                                  : (_holdController.isAnimating
                                      ? 'HOLDING...'
                                      : 'HOLD 5s\nFOR SOS'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Hold the button for 5 seconds. This creates a critical Trailtether incident and local alert. Contact emergency services directly if needed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosTypeChip extends StatelessWidget {
  final IncidentType type;
  final bool selected;
  final VoidCallback onTap;

  const _SosTypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? type.color.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? type.color : Colors.white.withOpacity(0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(type.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              type.label.split(' / ').first,
              style: GoogleFonts.outfit(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
