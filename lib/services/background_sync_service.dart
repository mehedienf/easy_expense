import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/note.dart';
import '../models/person.dart';

const String syncTaskName = 'backgroundSync';

class BackgroundSyncService {
  static const String _enabledKey = 'background_sync_enabled';
  static const String _userIdKey = 'background_sync_user_id';
  static const String _pendingPersonsKey = 'background_sync_pending_persons';
  static const String _pendingNotesKey = 'background_sync_pending_notes';
  static const String _lastRunKey = 'background_sync_last_run';
  static const String _lastStatusKey = 'background_sync_last_status';
  static const String _immediateWorkName = 'immediate-sync';
  static const String _debugWorkName = 'debug-sync';

  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  static void _log(String message) {
    developer.log(message, name: 'BG_SYNC');
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> initialize() async {
    if (kIsWeb) return;

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  Future<void> restoreScheduledTasksIfNeeded() async {
    if (kIsWeb) return;

    await Workmanager().cancelByUniqueName('periodic-sync');

    final prefs = await _prefs();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) return;

    await updateCurrentUser();

    final hasPendingPersons = prefs.getBool(_pendingPersonsKey) ?? false;
    final hasPendingNotes = prefs.getBool(_pendingNotesKey) ?? false;
    if (hasPendingPersons || hasPendingNotes) {
      await scheduleImmediateSync();
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<Map<String, dynamic>> getStatusSnapshot() async {
    final prefs = await _prefs();
    return {
      'enabled': prefs.getBool(_enabledKey) ?? false,
      'pendingPersons': prefs.getBool(_pendingPersonsKey) ?? false,
      'pendingNotes': prefs.getBool(_pendingNotesKey) ?? false,
      'lastRun': prefs.getString(_lastRunKey),
      'lastStatus': prefs.getString(_lastStatusKey) ?? 'never',
      'userId': prefs.getString(_userIdKey),
    };
  }

  String formatStatusText(String rawStatus) {
    if (rawStatus == 'never') return 'Never run';
    if (rawStatus.startsWith('ok:synced'))
      return 'Last run synced successfully';
    if (rawStatus.startsWith('ok:nothing-pending')) {
      return 'Last run found nothing pending';
    }
    if (rawStatus.startsWith('ok:no-local-payload')) {
      return 'Pending flag existed, but no local data was found';
    }
    if (rawStatus.startsWith('skipped:no-enabled-user')) {
      return 'Skipped because sync is off or no user was stored';
    }
    if (rawStatus.startsWith('retry:no-auth')) {
      return 'Will retry because user auth was not restored yet';
    }
    if (rawStatus.startsWith('retry:error:')) {
      return 'Last run failed and will retry';
    }
    return rawStatus;
  }

  Future<void> enableBackgroundSync() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be signed in to enable background sync');
    }

    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_userIdKey, user.uid);

    await Workmanager().cancelByUniqueName('periodic-sync');

    final hasPendingPersons = prefs.getBool(_pendingPersonsKey) ?? false;
    final hasPendingNotes = prefs.getBool(_pendingNotesKey) ?? false;
    if (hasPendingPersons || hasPendingNotes) {
      await scheduleImmediateSync();
    }
  }

  Future<void> disableBackgroundSync() async {
    if (kIsWeb) return;

    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_pendingPersonsKey);
    await prefs.remove(_pendingNotesKey);
    await prefs.remove(_userIdKey);

    await cancelAll();
  }

  Future<void> updateCurrentUser() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final prefs = await _prefs();
    await prefs.setString(_userIdKey, user.uid);
  }

  Future<void> markPersonsPending() async {
    if (kIsWeb) return;

    await updateCurrentUser();
    final prefs = await _prefs();
    await prefs.setBool(_pendingPersonsKey, true);

    if (prefs.getBool(_enabledKey) ?? false) {
      await scheduleImmediateSync();
    }
  }

  Future<void> markNotesPending() async {
    if (kIsWeb) return;

    await updateCurrentUser();
    final prefs = await _prefs();
    await prefs.setBool(_pendingNotesKey, true);

    if (prefs.getBool(_enabledKey) ?? false) {
      await scheduleImmediateSync();
    }
  }

  Future<void> clearPersonsPending() async {
    final prefs = await _prefs();
    await prefs.setBool(_pendingPersonsKey, false);
  }

  Future<void> clearNotesPending() async {
    final prefs = await _prefs();
    await prefs.setBool(_pendingNotesKey, false);
  }

  Future<void> scheduleImmediateSync() async {
    if (kIsWeb) return;

    await Workmanager().cancelByUniqueName(_immediateWorkName);
    await Workmanager().registerOneOffTask(
      _immediateWorkName,
      syncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );

    _log('Immediate background sync scheduled');
  }

  Future<void> cancelSync() async {
    if (kIsWeb) return;
    await Workmanager().cancelByUniqueName('periodic-sync');
    await Workmanager().cancelByUniqueName(_immediateWorkName);
    await Workmanager().cancelByUniqueName(_debugWorkName);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await Workmanager().cancelAll();
  }

  Future<void> testSync() async {
    if (kIsWeb) return;

    await Workmanager().cancelByUniqueName(_debugWorkName);
    await Workmanager().registerOneOffTask(
      _debugWorkName,
      syncTaskName,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    _log('Debug one-off sync scheduled');
  }

  Future<bool> runPendingSyncTask() async {
    try {
      _log('Task execution started');

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final prefs = await _prefs();
      final enabled = prefs.getBool(_enabledKey) ?? false;
      final storedUserId = prefs.getString(_userIdKey);

      if (!enabled || storedUserId == null || storedUserId.isEmpty) {
        await _setLastStatus('skipped:no-enabled-user');
        _log('Skipped - disabled or no stored user');
        return true;
      }

      final user = await _waitForAuthenticatedUser(storedUserId);
      if (user == null) {
        await _setLastStatus('retry:no-auth');
        _log('Auth not restored yet, will retry later');
        return false;
      }

      final hasPendingPersons = prefs.getBool(_pendingPersonsKey) ?? false;
      final hasPendingNotes = prefs.getBool(_pendingNotesKey) ?? false;

      if (!hasPendingPersons && !hasPendingNotes) {
        await _setLastStatus('ok:nothing-pending');
        _log('Nothing pending');
        return true;
      }

      final firestore = FirebaseFirestore.instance;
      final userDoc = firestore.collection('users').doc(storedUserId);

      final updateData = <String, dynamic>{};

      if (hasPendingPersons) {
        final personsData = prefs.getString('persons_$storedUserId');
        if (personsData != null) {
          final decoded = jsonDecode(personsData) as List<dynamic>;
          final persons = decoded
              .map((json) => Person.fromJson(Map<String, dynamic>.from(json)))
              .map((person) => person.toJson())
              .toList();
          updateData['persons'] = persons;
          updateData['lastUpdated'] = FieldValue.serverTimestamp();
        }
      }

      if (hasPendingNotes) {
        final notesData = prefs.getString('notes_$storedUserId');
        if (notesData != null) {
          final decoded = jsonDecode(notesData) as List<dynamic>;
          final notes = decoded
              .map((json) => Note.fromJson(Map<String, dynamic>.from(json)))
              .map((note) => note.toJson())
              .toList();
          updateData['notes'] = notes;
          updateData['notesLastUpdated'] = FieldValue.serverTimestamp();
        }
      }

      if (updateData.isEmpty) {
        await clearPersonsPending();
        await clearNotesPending();
        await _setLastStatus('ok:no-local-payload');
        _log('Pending flag existed but no local payload found');
        return true;
      }

      await userDoc.set(updateData, SetOptions(merge: true));

      if (hasPendingPersons) {
        await clearPersonsPending();
      }
      if (hasPendingNotes) {
        await clearNotesPending();
      }

      await _setLastStatus('ok:synced');
      _log('Background sync completed successfully');
      return true;
    } catch (e, stackTrace) {
      _log('Background sync failed: $e');
      _log(stackTrace.toString());
      await _setLastStatus('retry:error:$e');
      return false;
    }
  }

  Future<User?> _waitForAuthenticatedUser(String expectedUserId) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;

    if (currentUser != null && currentUser.uid == expectedUserId) {
      return currentUser;
    }

    try {
      return await auth
          .authStateChanges()
          .firstWhere((user) => user != null && user.uid == expectedUserId)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return auth.currentUser?.uid == expectedUserId ? auth.currentUser : null;
    }
  }

  Future<void> _setLastStatus(String status) async {
    final prefs = await _prefs();
    await prefs.setString(_lastStatusKey, status);
    await prefs.setString(_lastRunKey, DateTime.now().toIso8601String());
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    BackgroundSyncService._log('Worker received task: $task');
    return BackgroundSyncService().runPendingSyncTask();
  });
}
