import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../models/accommodation.dart';
import '../../providers/static_data_provider.dart';
import '../../providers/app_state_provider.dart';
import '../accommodation_detail_sheet.dart';

class AccommodationMarkerLayer extends StatelessWidget {
  /// Optional override — when not supplied, tapping a pin opens the standard
  /// AccommodationDetailSheet. Surfaces that want their own behaviour (e.g.
  /// the new tt_map_screen, which routes everything through a single shared
  /// "open this thing" handler) can intercept here.
  final void Function(Accommodation)? onTap;
  const AccommodationMarkerLayer({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final showAcc = context.watch<AppStateProvider>().showAccommodation;
    if (!showAcc) return const SizedBox.shrink();

    final data = context.watch<StaticDataProvider>();
    final accommodations = data.accommodations;

    return MarkerLayer(
      rotate: true,
      markers: accommodations.map((acc) {
        return Marker(
          point: LatLng(acc.lat, acc.lon),
          width: 80,
          height: 60,
          child: GestureDetector(
            onTap: () => (onTap != null)
                ? onTap!(acc)
                : AccommodationDetailSheet.show(context, acc),
            child: _AccommodationPin(acc: acc),
          ),
        );
      }).toList(),
    );
  }
}

class _AccommodationPin extends StatelessWidget {
  final Accommodation acc;
  const _AccommodationPin({required this.acc});

  // TT colour palette — accommodation pins share the app's amber accent so
  // they stand apart from cave pins (brown/teal) and trail polylines (ember)
  // while still feeling part of the same design system.
  static const _pinColor = TT.amber;
  static const _pinInk = Color(0xFF1A0E04);

  @override
  Widget build(BuildContext context) {
    final icon = switch (acc.type) {
      'hotel' => Icons.hotel,
      'resort' => Icons.beach_access,
      'lodge' => Icons.home,
      'backpacker' => Icons.backpack,
      'self_catering' => Icons.flatware,
      'guesthouse' => Icons.bed,
      'camping' => Icons.cabin_outlined,
      _ => Icons.house,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _pinColor.withOpacity(0.6), width: 0.8),
          ),
          child: Text(
            acc.name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: _pinInk, size: 14),
        ),
      ],
    );
  }
}
