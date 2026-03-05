import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';

class SyncService {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

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
    } catch (e) {
      rethrow;
    }
  }

  // Load data from Firebase
  Future<List<Person>> loadFromFirebase() async {
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
        lastSyncTime = DateTime.now();
      }

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['persons'] != null) {
          final List<dynamic> firebaseData = data['persons'];
          final persons = firebaseData
              .map((json) => Person.fromJson(json))
              .toList();
          return persons;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Save data to Firebase
  Future<bool> saveToFirebase(List<Person> persons) async {
    if (!isSignedIn) {
      return false;
    }

    try {
      final jsonList = persons.map((person) => person.toJson()).toList();
      await _firestore
          .collection('users')
          .doc(userId!)
          .set({
            'persons': jsonList,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      lastSyncTime = DateTime.now();
      return true;
    } catch (e) {
      // Don't change isOnline status on save failure
      // Online status is determined by checkConnectivity()
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
      isOnline = false;
      return localPersons;
    }

    // If offline (caller should set this via checkConnectivity), return local data
    if (!isOnline) {
      return localPersons;
    }

    // We're online — load from Firebase
    final firebasePersons = await loadFromFirebase();

    // Merge strategy: Prefer local data over Firebase for conflicts
    final mergedPersons = _mergePersonData(localPersons, firebasePersons);

    // Save merged data to local
    await saveToLocal(mergedPersons);

    // Only write to Firebase if data actually changed
    if (!_listsEqual(mergedPersons, firebasePersons)) {
      await saveToFirebase(mergedPersons);
    }

    return mergedPersons;
  }

  // Check if two person lists are equal (by name)
  bool _listsEqual(List<Person> a, List<Person> b) {
    if (a.length != b.length) return false;
    final namesA = a.map((p) => p.name).toSet();
    final namesB = b.map((p) => p.name).toSet();
    return namesA.length == namesB.length && namesA.containsAll(namesB);
  }

  // Merge local and Firebase data, preferring local for conflicts
  List<Person> _mergePersonData(
    List<Person> localPersons,
    List<Person> firebasePersons,
  ) {
    // If local is empty, use Firebase data
    if (localPersons.isEmpty) {
      return firebasePersons;
    }

    // If Firebase is empty, use local data
    if (firebasePersons.isEmpty) {
      return localPersons;
    }

    // Create a map of local persons by name for quick lookup
    final Map<String, Person> personMap = {};
    for (var person in localPersons) {
      personMap[person.name] = person;
    }

    // Add Firebase persons that don't exist in local
    for (var firebasePerson in firebasePersons) {
      if (!personMap.containsKey(firebasePerson.name)) {
        personMap[firebasePerson.name] = firebasePerson;
      }
      // If person exists in both, keep local version (has latest offline changes)
    }

    return personMap.values.toList();
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
    } catch (_) {
      // Ignore errors during local data cleanup
    }
  }

  // Backup local data to cloud without clearing local cache
  Future<void> backupLocalData() async {
    final persons = await loadFromLocal();
    if (persons.isNotEmpty && isSignedIn) {
      await saveToFirebase(persons);
    }
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

  // Check connectivity - web-compatible version
  Future<bool> checkConnectivity() async {
    if (!isSignedIn) {
      isOnline = false;
      return false;
    }

    try {
      if (kIsWeb) {
        // For web: Try a quick Firestore read to check connectivity
        final doc = await _firestore
            .collection('users')
            .doc(userId!)
            .get(const GetOptions(source: Source.server))
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                throw Exception('Connection timeout');
              },
            );

        // If we got server data (not from cache), we're online
        if (!doc.metadata.isFromCache) {
          isOnline = true;
          lastSyncTime = DateTime.now();
          return true;
        }
        isOnline = false;
        return false;
      } else {
        // For mobile/desktop: Use a lightweight Firestore query
        // We just check if we can reach Firestore servers
        await _firestore
            .collection('users')
            .doc(userId!)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 2));

        isOnline = true;
        lastSyncTime = DateTime.now();
        return true;
      }
    } catch (e) {
      isOnline = false;
      return false;
    }
  }
}
