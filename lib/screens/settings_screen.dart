import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/background_sync_service.dart';
import '../services/sync_service.dart';
import '../widgets/custom_appBar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _appSettings = AppSettings();
  final SyncService _syncService = SyncService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _appSettings.get('settings'),
        isLoading: false,
        isOnline: _syncService.isOnline,
        lastSyncTime: _syncService.lastSyncTime,
        onSyncPressed: () async {
          await _syncService.checkConnectivity();
          setState(() {});
        },
        onSignOut: () async {
          // Sign out is handled separately
        },
      ),
      body: const SettingsScreenBody(),
    );
  }
}

class SettingsScreenBody extends StatefulWidget {
  const SettingsScreenBody({super.key});

  @override
  State<SettingsScreenBody> createState() => _SettingsScreenBodyState();
}

class _SettingsScreenBodyState extends State<SettingsScreenBody> {
  final AppSettings _appSettings = AppSettings();
  final BackgroundSyncService _bgSyncService = BackgroundSyncService();
  late String _selectedLanguage;
  bool _backgroundSyncEnabled = true;
  bool _hasPendingBackup = false;
  bool _isLoadingSync = false;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _appSettings.currentLanguage;
    _checkBackgroundSyncStatus();
  }

  Future<void> _checkBackgroundSyncStatus() async {
    final enabled = await _bgSyncService.isEnabled();
    final snapshot = await _bgSyncService.getStatusSnapshot();
    final hasPendingPersons = snapshot['pendingPersons'] as bool? ?? false;
    final hasPendingNotes = snapshot['pendingNotes'] as bool? ?? false;
    if (!mounted) return;
    setState(() {
      _backgroundSyncEnabled = enabled;
      _hasPendingBackup = hasPendingPersons || hasPendingNotes;
    });
  }

  Future<void> _toggleBackgroundSync(bool value) async {
    setState(() {
      _isLoadingSync = true;
    });

    if (value) {
      try {
        await _bgSyncService.enableBackgroundSync();
        setState(() {
          _backgroundSyncEnabled = true;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_appSettings.get('backgroundSyncEnabled')),
            backgroundColor: Colors.green,
          ),
        );
        await _checkBackgroundSyncStatus();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Background sync চালু করতে আগে sign in করুন।'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      await _bgSyncService.disableBackgroundSync();
      setState(() {
        _backgroundSyncEnabled = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_appSettings.get('backgroundSyncDisabled')),
          backgroundColor: Colors.grey,
        ),
      );
      await _checkBackgroundSyncStatus();
    }

    setState(() {
      _isLoadingSync = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Language Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _appSettings.get('language'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(_appSettings.get('english')),
                      value: 'en',
                      groupValue: _selectedLanguage,
                      onChanged: (value) async {
                        if (value != null) {
                          await _appSettings.setLanguage(value);
                          setState(() {
                            _selectedLanguage = value;
                          });
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_appSettings.get('language')),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                    Divider(height: 0, color: Colors.grey.shade300),
                    RadioListTile<String>(
                      title: Text(_appSettings.get('bengali')),
                      value: 'bn',
                      groupValue: _selectedLanguage,
                      onChanged: (value) async {
                        if (value != null) {
                          await _appSettings.setLanguage(value);
                          setState(() {
                            _selectedLanguage = value;
                          });
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_appSettings.get('language')),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(),

        if (!kIsWeb) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: const Text('Enable Background Sync'),
                subtitle: Text(
                  _hasPendingBackup ? 'Backup pending' : 'No pending backup',
                ),
                value: _backgroundSyncEnabled,
                onChanged: _isLoadingSync ? null : _toggleBackgroundSync,
              ),
            ),
          ),
          const Divider(),
        ],

        // About Section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _appSettings.get('about'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(_appSettings.get('version')),
                trailing: const Text('1.0.0'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
