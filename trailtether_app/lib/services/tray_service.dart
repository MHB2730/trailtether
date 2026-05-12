import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  static final TrayService instance = TrayService._();
  TrayService._();

  Future<void> init() async {
    if (!Platform.isWindows) return;

    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icon/app_icon.ico'
          : 'assets/icon/app_icon.png',
    );

    final menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Trailtether',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Exit',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }
}
