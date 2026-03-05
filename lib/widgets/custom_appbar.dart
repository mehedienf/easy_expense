import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isLoading;
  final bool isOnline;
  final DateTime? lastSyncTime;
  final VoidCallback onSyncPressed;
  final VoidCallback onSignOut;
  final VoidCallback? onProfilePressed;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.isLoading,
    required this.isOnline,
    this.lastSyncTime,
    required this.onSyncPressed,
    required this.onSignOut,
    this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final appSettings = AppSettings();

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(
            '${appSettings.get('welcome')}, ${user?.displayName ?? appSettings.get('user')}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      actions: [
        // Sync status indicator
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: isOnline ? Colors.green : Colors.red,
            ),
            onPressed: onSyncPressed,
            tooltip: isOnline
                ? '${appSettings.get('lastSync')}: ${lastSyncTime != null ? "${lastSyncTime!.hour}:${lastSyncTime!.minute.toString().padLeft(2, '0')}" : appSettings.get('never')}'
                : appSettings.get('tapToRetrySync'),
          ),

        // User profile menu
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL == null
                ? Text(
                    (user?.displayName?.isNotEmpty == true)
                        ? user!.displayName!.substring(0, 1).toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          onSelected: (value) async {
            if (value == 'profile') {
              if (onProfilePressed != null) {
                onProfilePressed!();
              } else {
                _showDefaultUserProfile(context, user, lastSyncTime);
              }
            } else if (value == 'signout') {
              onSignOut();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  const Icon(Icons.person),
                  const SizedBox(width: 8),
                  Text(user?.email ?? ''),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'signout',
              child: Row(
                children: [
                  const Icon(Icons.logout, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    appSettings.get('logout'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Default user profile dialog
  static void _showDefaultUserProfile(
    BuildContext context,
    User? user,
    DateTime? lastSyncTime,
  ) {
    final appSettings = AppSettings();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appSettings.get('userProfile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Text(
                      (user?.displayName?.isNotEmpty == true)
                          ? user!.displayName!.substring(0, 1).toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              user?.displayName ?? appSettings.get('user'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              '${appSettings.get('lastSync')}: ${lastSyncTime != null ? "${lastSyncTime.day}/${lastSyncTime.month} ${lastSyncTime.hour}:${lastSyncTime.minute.toString().padLeft(2, '0')}" : appSettings.get('never')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appSettings.get('close')),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
