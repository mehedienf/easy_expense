import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime? lastSyncTime;
  bool isOnline = false;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  // Check if user is signed in
  bool get isSignedIn => userId != null;

  // Load data from SharedPreferences (user-specific local storage)
  Future<List<Person>> loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId ?? 'guest';
    final String? personsData = prefs.getString('persons_$uid');

    if (personsData != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(personsData);
        return jsonList.map((json) => Person.fromJson(json)).toList();
      } catch (e) {
        print('Error loading from local: $e');
        return [];
      }
    }
    return [];
  }

  // Save data to local storage (user-specific)
  Future<void> saveToLocal(List<Person> persons) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = userId ?? 'guest';
      final String personsData = jsonEncode(
        persons.map((p) => p.toJson()).toList(),
      );
      await prefs.setString('persons_$uid', personsData);
      print('✅ Saved to local storage');
    } catch (e) {
      print('❌ Error saving to local: $e');
      rethrow;
    }
  }

  // Load data from Firebase
  Future<List<Person>> loadFromFirebase() async {
    if (!isSignedIn) {
      print('⚠️ User not signed in, skipping Firebase load');
      return [];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId!).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['persons'] != null) {
          final List<dynamic> firebaseData = data['persons'];
          final persons = firebaseData
              .map((json) => Person.fromJson(json))
              .toList();

          isOnline = true;
          lastSyncTime = DateTime.now();

          print('✅ Loaded ${persons.length} persons from Firebase');
          return persons;
        }
      }

      isOnline = true;
      lastSyncTime = DateTime.now();
      return [];
    } catch (e) {
      print('❌ Firebase load failed: $e');
      isOnline = false;
      return [];
    }
  }

  // Save data to Firebase
  Future<bool> saveToFirebase(List<Person> persons) async {
    if (!isSignedIn) {
      print('⚠️ User not signed in, skipping Firebase save');
      return false;
    }

    try {
      final jsonList = persons.map((person) => person.toJson()).toList();
      await _firestore.collection('users').doc(userId!).set({
        'persons': jsonList,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      isOnline = true;
      lastSyncTime = DateTime.now();

      print('✅ Saved ${persons.length} persons to Firebase');
      return true;
    } catch (e) {
      print('❌ Failed to save to Firebase: $e');
      isOnline = false;
      return false;
    }
  }

  // Full sync: Load from Firebase, save to local
  Future<List<Person>> syncFromFirebase() async {
    final persons = await loadFromFirebase();
    if (persons.isNotEmpty || isOnline) {
      await saveToLocal(persons);
    }
    return persons;
  }

  // Full sync: Save to both local and Firebase
  Future<bool> syncToFirebase(List<Person> persons) async {
    await saveToLocal(persons);
    return await saveToFirebase(persons);
  }

  // Bidirectional sync: Merge local and Firebase data
  Future<List<Person>> fullSync() async {
    // Load from local first
    final localPersons = await loadFromLocal();

    if (!isSignedIn) {
      print('⚠️ Offline mode - using local data');
      return localPersons;
    }

    // Load from Firebase
    final firebasePersons = await loadFromFirebase();

    // If Firebase has data, use it (server is source of truth)
    if (firebasePersons.isNotEmpty) {
      await saveToLocal(firebasePersons);
      return firebasePersons;
    }

    // If Firebase is empty but local has data, upload to Firebase
    if (localPersons.isNotEmpty) {
      await saveToFirebase(localPersons);
      return localPersons;
    }

    return [];
  }

  // Real-time listener for Firebase changes
  Stream<List<Person>> personsStream() {
    if (!isSignedIn) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(userId!)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            if (data != null && data['persons'] != null) {
              final List<dynamic> firebaseData = data['persons'];
              isOnline = true;
              lastSyncTime = DateTime.now();
              return firebaseData.map((json) => Person.fromJson(json)).toList();
            }
          }
          return <Person>[];
        })
        .handleError((error) {
          print('❌ Stream error: $error');
          isOnline = false;
          return <Person>[];
        });
  }

  // Clear local data (for sign out)
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = userId ?? 'guest';
      await prefs.remove('persons_$uid');
      print('✅ Local data cleared');
    } catch (e) {
      print('❌ Error clearing local data: $e');
    }
  }

  // Backup local data before clearing
  Future<void> backupAndClear() async {
    final persons = await loadFromLocal();
    if (persons.isNotEmpty && isSignedIn) {
      await saveToFirebase(persons);
    }
    await clearLocalData();
  }

  // Get sync status text
  String getSyncStatusText() {
    if (!isSignedIn) {
      return 'Offline mode';
    }
    if (isOnline && lastSyncTime != null) {
      final duration = DateTime.now().difference(lastSyncTime!);
      if (duration.inSeconds < 60) {
        return 'Synced just now';
      } else if (duration.inMinutes < 60) {
        return 'Synced ${duration.inMinutes}m ago';
      } else if (duration.inHours < 24) {
        return 'Synced ${duration.inHours}h ago';
      } else {
        return 'Synced ${duration.inDays}d ago';
      }
    }
    return 'Not synced';
  }
}
