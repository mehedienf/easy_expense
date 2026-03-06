import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class CustomBottomNavbar extends StatelessWidget
    implements PreferredSizeWidget {
  final int currentIndex;
  final Function(int) onTap;
  final AppSettings _appSettings = AppSettings();

  @override
  Size get preferredSize => const Size.fromHeight(80);

  CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        iconSize: 28,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: _appSettings.get('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.note),
            label: _appSettings.get('notes'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: _appSettings.get('settings'),
          ),
        ],
      ),
    );
  }
}
