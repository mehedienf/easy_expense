import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'note_service.dart';
import 'sync_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final SyncService _syncService = SyncService();
  final NoteService _noteService = NoteService();

  bool _googleInitialized = false;

  Future<void> _initGoogleSignIn() async {
    if (_googleInitialized) return;
    await _googleSignIn.initialize(
      clientId: kIsWeb
          ? '950417547925-7upfggc6abfl59qclq6uers36llv847n.apps.googleusercontent.com'
          : null,
    );
    _googleInitialized = true;
  }

  // Current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _initGoogleSignIn();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Anonymous sign in (temporary for testing)
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      return null;
    }
  }

  // Sign out
  Future<bool> backupBeforeSignOut() async {
    var personsBackupOk = true;
    var notesBackupOk = true;

    try {
      await _syncService.backupLocalData();
    } catch (_) {
      personsBackupOk = false;
    }

    try {
      await _noteService.backupLocalNotes();
    } catch (_) {
      notesBackupOk = false;
    }

    return personsBackupOk && notesBackupOk;
  }

  Future<void> completeSignOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (_) {
      // If primary sign out fails, try secondary sign out
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {
        // Ignore errors during fallback sign out
      }
    }
  }

  Future<void> signOut() async {
    await backupBeforeSignOut();
    await completeSignOut();
  }

  // Get user display info
  String get userDisplayName => currentUser?.displayName ?? 'User';
  String get userEmail => currentUser?.email ?? '';
  String? get userPhotoURL => currentUser?.photoURL;
}
