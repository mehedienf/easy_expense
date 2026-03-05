import 'package:flutter/material.dart';

import '../services/app_settings.dart';
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
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _appSettings.currentLanguage;
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
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      title: Text(_appSettings.get('english')),
                      value: 'en',
                      // ignore: deprecated_member_use
                      groupValue: _selectedLanguage,
                      // ignore: deprecated_member_use
                      onChanged: (value) async {
                        if (value != null) {
                          await _appSettings.setLanguage(value);
                          setState(() {
                            _selectedLanguage = value;
                          });
                          if (!mounted) return;

                          // ignore: use_build_context_synchronously
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
                    // ignore: deprecated_member_use
                    RadioListTile<String>(
                      title: Text(_appSettings.get('bengali')),
                      value: 'bn',
                      // ignore: deprecated_member_use
                      groupValue: _selectedLanguage,
                      // ignore: deprecated_member_use
                      onChanged: (value) async {
                        if (value != null) {
                          await _appSettings.setLanguage(value);
                          setState(() {
                            _selectedLanguage = value;
                          });
                          if (!mounted) return;

                          // ignore: use_build_context_synchronously
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
