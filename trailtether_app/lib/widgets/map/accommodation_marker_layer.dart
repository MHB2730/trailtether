import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/accommodation.dart';
import '../../providers/static_data_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../screens/accommodation_detail_sheet.dart';

class AccommodationMarkerLayer extends StatelessWidget {
  const AccommodationMarkerLayer({super.key});

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
            onTap: () => AccommodationDetailSheet.show(context, acc),
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

  @override
  Widget build(BuildContext context) {
    final icon = switch (acc.type) {
      'hotel' => Icons.hotel,
      'resort' => Icons.beach_access,
      'lodge' => Icons.home,
      'backpacker' => Icons.backpack,
      'self_catering' => Icons.flatware,
      'guesthouse' => Icons.bed,
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
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
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
            color: Colors.blueAccent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ],
    );
  }
}
