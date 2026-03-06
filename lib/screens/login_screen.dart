import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final AppSettings _appSettings = AppSettings();
  bool _isLoading = false;
  String _currentLanguage = 'en';

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    await _appSettings.loadLanguage();
    if (mounted) {
      setState(() {
        _currentLanguage = _appSettings.currentLanguage;
      });
    }
  }

  Future<void> _toggleLanguage() async {
    final newLanguage = _currentLanguage == 'en' ? 'bn' : 'en';
    await _appSettings.setLanguage(newLanguage);
    if (mounted) {
      setState(() {
        _currentLanguage = newLanguage;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && mounted) {
        // Success - navigation will be handled by StreamBuilder in main.dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_appSettings.get('successfullySignedIn')),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_appSettings.get('signInCancelled')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = _appSettings.get('signInFailed');

        // Handle specific errors
        if (e.toString().contains('network_error')) {
          errorMessage = _appSettings.get('networkErrorCheckConnection');
        } else if (e.toString().contains('sign_in_canceled')) {
          errorMessage = _appSettings.get('signInCancelled');
        } else if (e.toString().contains('sign_in_failed')) {
          errorMessage = _appSettings.get('googleSignInFailedTryAgain');
        } else {
          errorMessage = '${_appSettings.get('signInFailed')}: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.signInAnonymously();
      if (result != null && mounted) {
        // Success - navigation will be handled by StreamBuilder in main.dart
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_appSettings.get('signedInAsGuest')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_appSettings.get('anonymousSignInFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: TextButton.icon(
                onPressed: _toggleLanguage,
                icon: const Icon(Icons.language, size: 18),
                label: Text(_currentLanguage == 'en' ? 'বাংলা' : 'English'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  ClipRRect(
                    // borderRadius: BorderRadius.circular(60),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App Title
                  Text(
                    _appSettings.get('DenaPaona'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _appSettings.get('trackExpensesWithEase'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.blue.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Sign in with Google Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Image.asset(
                              'assets/google_logo.png',
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.login, color: Colors.white),
                            ),
                      label: Text(
                        _isLoading
                            ? _appSettings.get('signingIn')
                            : _appSettings.get('signInWithGoogle'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Anonymous Sign In Button (for testing)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _signInAnonymously,
                      icon: const Icon(Icons.person_outline),
                      label: Text(
                        _appSettings.get('continueAsGuest'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  Column(
                    children: [
                      _buildFeatureRow(
                        Icons.cloud_sync,
                        _appSettings.get('automaticCloudBackup'),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureRow(
                        Icons.devices,
                        _appSettings.get('syncAcrossDevices'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.blue.shade600, fontSize: 14)),
      ],
    );
  }
}
