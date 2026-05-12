import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/static_data_provider.dart';
import '../providers/app_state_provider.dart';
import '../screens/accommodation_detail_sheet.dart';

class LocationsTool extends StatefulWidget {
  const LocationsTool({super.key});

  @override
  State<LocationsTool> createState() => _LocationsToolState();
}

class _LocationsToolState extends State<LocationsTool> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<StaticDataProvider>();
    final appState = context.watch<AppStateProvider>();
    final allAcc = data.accommodations;

    final filtered = _filter == 'All'
        ? allAcc
        : allAcc.where((a) => a.type == _filter.toLowerCase()).toList();

    return Column(
      children: [
        // ── Map Toggle ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kColorPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kColorOrange.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: kColorOrange.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kColorOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.map_outlined,
                      color: kColorOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Show on Map',
                          style: GoogleFonts.outfit(
                              color: kColorCream,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text('Display all lodging markers on the map',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.4),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: appState.showAccommodation,
                  activeColor: kColorOrange,
                  onChanged: (val) => appState.setShowAccommodation(val),
                ),
              ],
            ),
          ),
        ),

        // ── Filter Chips ─────────────────────────────────────────
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              'All',
              'Hotel',
              'Resort',
              'Lodge',
              'Backpacker',
              'Self_Catering',
              'Guesthouse'
            ]
                .map((t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(t.replaceAll('_', ' ')),
                        selected: _filter == t,
                        onSelected: (val) => setState(() => _filter = t),
                        backgroundColor: kColorPanel,
                        selectedColor: kColorOrange.withOpacity(0.2),
                        checkmarkColor: kColorOrange,
                        labelStyle: GoogleFonts.outfit(
                          color: _filter == t
                              ? kColorOrange
                              : kColorCream.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: _filter == t
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color:
                                  _filter == t ? kColorOrange : kColorBorder),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        // ── List ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final acc = filtered[index];
              return _AccommodationListTile(acc: acc);
            },
          ),
        ),
      ],
    );
  }
}

class _AccommodationListTile extends StatelessWidget {
  final dynamic acc;
  const _AccommodationListTile({required this.acc});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (acc.type) {
      'hotel' => '🏨',
      'resort' => '🏖️',
      'lodge' => '🏡',
      'backpacker' => '🎒',
      'self_catering' => '🍳',
      'guesthouse' => '🛌',
      _ => '🏠',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kColorPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kColorBorder),
      ),
      child: ListTile(
        onTap: () => AccommodationDetailSheet.show(context, acc),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kColorCream.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child:
              Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
        ),
        title: Text(
          acc.name,
          style: GoogleFonts.outfit(
            color: kColorCream,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${acc.region} Drakensberg',
          style: GoogleFonts.outfit(
            color: kColorCream.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right,
            color: kColorCream.withOpacity(0.2), size: 18),
      ),
    );
  }
}
