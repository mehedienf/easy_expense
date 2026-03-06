import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_settings.dart';
import 'services/background_sync_service.dart';

late Future<void> _firebaseInit;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Firebase init in background — don't block app startup
  _firebaseInit = _initializeFirebase();

  runApp(const MyApp());
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBeIjcFnE8vrpU5UfvDQt7FizT28nhIbuY",
        authDomain: "easyexpens.firebaseapp.com",
        databaseURL: "https://easyexpens-default-rtdb.firebaseio.com",
        projectId: "easyexpens",
        storageBucket: "easyexpens.firebasestorage.app",
        messagingSenderId: "950417547925",
        appId: "1:950417547925:web:1e4642c0c7d25a1b1a719c",
        measurementId: "G-JRF327LTN7",
      ),
    );
  } else {
    await Firebase.initializeApp();

    // Initialize background sync for Android
    if (!kIsWeb) {
      try {
        final bgSyncService = BackgroundSyncService();
        await bgSyncService.initialize();
        await bgSyncService.restoreScheduledTasksIfNeeded();
      } catch (e) {
        // Silently fail if background sync fails to initialize
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appSettings = AppSettings();
    unawaited(appSettings.loadLanguage());

    return AnimatedBuilder(
      animation: appSettings,
      builder: (context, _) => MaterialApp(
        title: appSettings.get('DenaPaona'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          textTheme: GoogleFonts.tiroBanglaTextTheme(),
        ),
        debugShowCheckedModeBanner: false,
        home: FutureBuilder<void>(
          future: _firebaseInit,
          builder: (context, firebaseSnapshot) {
            // Firebase initializing — show splash screen instantly
            if (firebaseSnapshot.connectionState != ConnectionState.done) {
              return const _SplashScreen();
            }

            // Firebase ready — listen to auth state
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _SplashScreen();
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return HomeScreen(title: appSettings.get('home'));
                }
                return const LoginScreen();
              },
            );
          },
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final appSettings = AppSettings();

    return Scaffold(
      appBar: AppBar(title: Text(appSettings.get('DenaPaona'))),
      backgroundColor: const Color.fromARGB(225, 207, 215, 221),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              // borderRadius: BorderRadius.circular(40),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appSettings.get('DenaPaona'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.blue.shade600),
          ],
        ),
      ),
    );
  }
}
