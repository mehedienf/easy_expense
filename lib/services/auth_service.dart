import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'sync_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '950417547925-7upfggc6abfl59qclq6uers36llv847n.apps.googleusercontent.com' // Web client ID (same for now)
        : null, // Use default for mobile platforms
  );
  final SyncService _syncService = SyncService();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credentials
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow; // Re-throw to see actual error
    }
  }

  // Anonymous sign in (temporary for testing)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // 🔄 Backup local data to Firebase before sign out
      await _syncService.backupAndClear();

      await _googleSignIn.signOut();
      await _auth.signOut();

      print('✅ Signed out successfully');
    } catch (e) {
      print('Error signing out: $e');
      // Still sign out even if backup fails
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (signOutError) {
        print('Error in final signOut: $signOutError');
      }
    }
  }

  // Get user display info
  String get userDisplayName => currentUser?.displayName ?? 'User';
  String get userEmail => currentUser?.email ?? '';
  String? get userPhotoURL => currentUser?.photoURL;
}
