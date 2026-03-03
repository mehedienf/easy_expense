import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
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
    // For mobile platforms, use config from platform-specific files
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyExpense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If user is signed in, show main app
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen(title: 'EasyExpense');
          }

          // If user is not signed in, show login screen
          return const LoginScreen();
        },
      ),
    );
  }
}
