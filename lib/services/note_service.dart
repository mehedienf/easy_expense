import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import 'sync_service.dart';

class NoteService {
  // Singleton pattern
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SyncService _syncService = SyncService();

  String? get userId => _auth.currentUser?.uid;
  bool get isSignedIn => userId != null;

  // Load notes from local storage
  Future<List<Note>> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? 'guest';
    final String? notesData = prefs.getString('notes_$uid');

    if (notesData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(notesData);
        return jsonList.map((json) => Note.fromJson(json)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  // Save notes to local storage
  Future<void> saveToLocal(List<Note> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = userId ?? 'guest';
      final String notesData = jsonEncode(
        notes.map((n) => n.toJson()).toList(),
      );
      await prefs.setString('notes_$uid', notesData);
    } catch (e) {
      rethrow;
    }
  }

  // Load notes from Firebase
  Future<List<Note>> loadFromFirebase() async {
    if (!isSignedIn) {
      return [];
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId!)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      // Update sync time if data came from server
      if (!doc.metadata.isFromCache) {
        _syncService.lastSyncTime = DateTime.now();
      }

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['notes'] != null) {
          final List<dynamic> firebaseData = data['notes'];
          final notes = firebaseData
              .map((json) => Note.fromJson(json))
              .toList();
          return notes;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Save notes to Firebase
  Future<bool> saveToFirebase(List<Note> notes) async {
    if (!isSignedIn) {
      return false;
    }

    try {
      final jsonList = notes.map((note) => note.toJson()).toList();

      await _firestore
          .collection('users')
          .doc(userId!)
          .set({
            'notes': jsonList,
            'notesLastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      _syncService.lastSyncTime = DateTime.now();
      return true;
    } catch (e) {
      // Don't change isOnline status on save failure
      return false;
    }
  }

  // Full sync: Load from Firebase, save to local
  Future<List<Note>> syncFromFirebase() async {
    final notes = await loadFromFirebase();
    if (notes.isNotEmpty) {
      await saveToLocal(notes);
    }
    return notes;
  }

  // Full sync: Save to both local and Firebase
  Future<bool> syncToFirebase(List<Note> notes) async {
    await saveToLocal(notes);
    return await saveToFirebase(notes);
  }

  // Bidirectional sync: Merge local and Firebase data (offline-safe)
  Future<List<Note>> fullSync() async {
    // Load from local first
    final localNotes = await loadFromLocal();

    if (!isSignedIn) {
      return localNotes;
    }

    // If offline (caller should set this via checkConnectivity), return local data
    if (!_syncService.isOnline) {
      return localNotes;
    }

    // We're online — load from Firebase
    final firebaseNotes = await loadFromFirebase();

    // If we reached here, we're online (loadFromFirebase succeeded)
    // Merge strategy: Prefer local data over Firebase for conflicts
    // This prevents data loss when syncing after offline changes
    final mergedNotes = _mergeNoteData(localNotes, firebaseNotes);

    // Save merged data to local
    await saveToLocal(mergedNotes);

    // Only write to Firebase if data actually changed
    if (!_notesEqual(mergedNotes, firebaseNotes)) {
      await saveToFirebase(mergedNotes);
    }

    return mergedNotes;
  }

  // Check if two note lists are equal (by id set)
  bool _notesEqual(List<Note> a, List<Note> b) {
    if (a.length != b.length) return false;
    final idsA = a.map((n) => n.id).toSet();
    final idsB = b.map((n) => n.id).toSet();
    return idsA.length == idsB.length && idsA.containsAll(idsB);
  }

  // Merge local and Firebase data, preferring newer updates
  List<Note> _mergeNoteData(List<Note> localNotes, List<Note> firebaseNotes) {
    // If local is empty, use Firebase data
    if (localNotes.isEmpty) {
      return firebaseNotes;
    }

    // If Firebase is empty, use local data
    if (firebaseNotes.isEmpty) {
      return localNotes;
    }

    // Create a map of notes by ID for quick lookup
    final Map<String, Note> noteMap = {};

    // Add Firebase notes first
    for (var note in firebaseNotes) {
      noteMap[note.id] = note;
    }

    // Add or update with local notes (preferring local for same ID)
    for (var localNote in localNotes) {
      if (noteMap.containsKey(localNote.id)) {
        // If note exists in both, keep the one with latest update
        final existingNote = noteMap[localNote.id]!;
        if (localNote.updatedAt.isAfter(existingNote.updatedAt)) {
          noteMap[localNote.id] = localNote;
        }
      } else {
        // Note only exists in local, add it
        noteMap[localNote.id] = localNote;
      }
    }

    return noteMap.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // Clear local notes
  Future<void> clearLocalNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = userId ?? 'guest';
      await prefs.remove('notes_$uid');
    } catch (_) {
      // Ignore errors during local data cleanup
    }
  }

  // Backup local notes to cloud without clearing local cache
  Future<void> backupLocalNotes() async {
    final notes = await loadFromLocal();
    if (notes.isNotEmpty && isSignedIn) {
      await saveToFirebase(notes);
    }
  }
}
