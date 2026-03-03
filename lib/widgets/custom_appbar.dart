import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(
            'Welcome, ${user?.displayName ?? 'User'}',
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
                ? 'Last sync: ${lastSyncTime != null ? "${lastSyncTime!.hour}:${lastSyncTime!.minute.toString().padLeft(2, '0')}" : "Never"}'
                : 'Tap to retry sync',
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
            const PopupMenuItem(
              value: 'signout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: Colors.red)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Profile'),
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
              user?.displayName ?? 'User',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Last Sync: ${lastSyncTime != null ? "${lastSyncTime.day}/${lastSyncTime.month} at ${lastSyncTime.hour}:${lastSyncTime.minute.toString().padLeft(2, '0')}" : "Never"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
