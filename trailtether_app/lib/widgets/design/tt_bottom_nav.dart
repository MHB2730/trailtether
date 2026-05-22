import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';

/// Trailtether 2.0 bottom navigation. Six tabs (Home / Map / Tools / Community
/// / Teams / Profile) with an ember "pip" above the active item and a faint
/// home-gesture bar at the bottom — matches the design's `tt-bottomnav`.
class TTBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const TTBottomNav({super.key, required this.currentIndex, required this.onTap});

  static const _items = <_NavItem>[
    _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    _NavItem('Map', Icons.map_outlined, Icons.map_rounded),
    _NavItem('Tools', Icons.explore_outlined, Icons.explore),
    _NavItem('Community', Icons.chat_bubble_outline, Icons.chat_bubble),
    _NavItem('Teams', Icons.group_outlined, Icons.group),
    _NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xD9080A0E), // ~85% bg
        border: Border(top: BorderSide(color: TT.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (i) {
              final active = i == currentIndex;
              final item = _items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedDefaultTextStyle(
                    duration: TT.dFast,
                    style: TT.body(
                      size: 9.5,
                      w: FontWeight.w700,
                      color: active ? TT.ember : TT.text3,
                    ).copyWith(letterSpacing: 0.12 * 9.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Active pip
                        AnimatedContainer(
                          duration: TT.dMed,
                          width: active ? 28 : 0,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: active ? TT.ember : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: active
                                ? const [BoxShadow(color: Color(0xB3FF6A2C), blurRadius: 12)]
                                : null,
                          ),
                        ),
                        Icon(
                          active ? item.activeIcon : item.icon,
                          size: 20,
                          color: active ? TT.ember : TT.text3,
                        ),
                        const SizedBox(height: 4),
                        Text(item.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
