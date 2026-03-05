import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class CustomBottomNavbar extends StatelessWidget
    implements PreferredSizeWidget {
  final int currentIndex;
  final Function(int) onTap;
  final AppSettings _appSettings = AppSettings();

  @override
  Size get preferredSize => const Size.fromHeight(50);

  CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home_outlined),
          label: _appSettings.get('home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.note_outlined),
          label: _appSettings.get('notes'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings_outlined),
          label: _appSettings.get('settings'),
        ),
      ],
    );
  }
}
