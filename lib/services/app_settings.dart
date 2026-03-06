import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static const String _englishCode = 'en';
  static const String _bengaliCode = 'bn';

  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey) ?? 'en';
    if (_currentLanguage != savedLanguage) {
      _currentLanguage = savedLanguage;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    if (language != _englishCode && language != _bengaliCode) {
      return;
    }
    if (_currentLanguage == language) {
      return;
    }
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    notifyListeners();
  }

  // Translation strings
  Map<String, Map<String, String>> get translations => {
    'en': {
      'appName': 'App Name',
      'DenaPaona': 'DenaPaona',
      'home': 'Home',
      'notes': 'Notes',
      'settings': 'Settings',
      'language': 'Language',
      'english': 'English',
      'bengali': 'Bengali',
      'about': 'About',
      'version': 'Version',
      'logout': 'Logout',
      'profile': 'Profile',
      'balance': 'Balance',
      'youWillGet': 'You\'ll Get',
      'youWillGive': 'You\'ll Give',
      'netBalance': 'Net Balance',
      'give': 'Give',
      'take': 'Take',
      'addPerson': 'Add Person',
      'deletePerson': 'Delete Person',
      'deleteNote': 'Delete Note',
      'editNote': 'Edit Note',
      'noNotes': 'No notes yet',
      'startTyping': 'Start typing...',
      'title': 'Title',
      'untitled': 'Untitled',
      'noContent': 'No content',
      'areYouSure': 'Are you sure?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'save': 'Save',
      'add': 'Add',
      'financialSummary': 'Total Summary',
      'noPersonsAdded': 'No persons added yet.',
      'pullDownToRefresh': 'Pull down to refresh',
      'workingOfflineSyncWhenOnline':
          'Working offline - Data will sync when online',
      'dataSyncedSuccessfully': 'Data synced successfully!',
      'connectionLostWorkingOffline': 'Connection lost! Working offline.',
      'workingOfflineUsingLocalData': 'Working offline - Using local data',
      'welcome': 'Welcome',
      'user': 'User',
      'lastSync': 'Last Sync',
      'never': 'Never',
      'tapToRetrySync': 'Tap to retry sync',
      'userProfile': 'User Profile',
      'close': 'Close',
      'notesSyncedSuccessfully': 'Notes synced successfully!',
      'tapToCreateNote': 'Tap + to create a note',
      'deleteNoteConfirm': 'Are you sure you want to delete this note?',
      'noteDeleted': 'Note deleted',
      'iGave': 'I Gave',
      'iTook': 'I Took',
      'transactionHistory': 'Transaction History',
      'noTransactionsYet': 'No transactions yet.',
      'deleteTransaction': 'Delete Transaction',
      'deleteTransactionConfirm':
          'Are you sure you want to delete this transaction?',
      'amount': 'Amount',
      'enterAmount': 'Enter amount',
      'enterValidAmount': 'Enter valid amount',
      'noteOptional': 'Note (optional)',
      'errorLoadingData': 'Error loading data',
      'errorSaving': 'Error saving',
      'personName': 'Person name',
      'deletePersonConfirm': 'Are you sure you want to delete',
      'trackExpensesWithEase': 'Track your credit and debts with ease',
      'signingIn': 'Signing in...',
      'signInWithGoogle': 'Sign in with Google',
      'continueAsGuest': 'Continue as Guest',
      'automaticCloudBackup': 'Automatic cloud backup',
      'syncAcrossDevices': 'Sync across devices',
      'successfullySignedIn': 'Successfully signed in!',
      'signInCancelled': 'Sign in was cancelled',
      'signInFailed': 'Sign in failed',
      'networkErrorCheckConnection':
          'Network error. Please check your internet connection.',
      'googleSignInFailedTryAgain': 'Google Sign In failed. Please try again.',
      'signedInAsGuest': 'Signed in as guest!',
      'anonymousSignInFailed': 'Anonymous sign in failed',
      'logoutBackupSuccess': 'Backup completed before logout',
      'logoutBackupFailed':
          'Could not fully backup data before logout. Local data is kept.',
        'appDeveloperInfo': 'About App',
        'developerName': 'Developer',
        'companyName': 'Company',
      'Gave': 'Gave',
      'Took': 'Took',
    },
    'bn': {
      'appName': 'অ্যাপের নাম',
      'DenaPaona': 'দেনাপাওনা',
      'home': 'হোম',
      'notes': 'নোট',
      'settings': 'সেটিংস',
      'language': 'ভাষা',
      'english': 'English',
      'bengali': 'বাংলা',
      'about': 'সম্পর্কে',
      'version': 'সংস্করণ',
      'logout': 'লগ আউট',
      'profile': 'প্রোফাইল',
      'balance': 'ব্যালেন্স',
      'youWillGet': 'আপনি পাবেন',
      'youWillGive': 'আপনি দেবেন',
      'netBalance': 'নেট ব্যালেন্স',
      'give': 'দেয়',
      'take': 'নেয়',
      'addPerson': 'ব্যক্তি যোগ করুন',
      'deletePerson': 'ব্যক্তি মুছুন',
      'deleteNote': 'নোট মুছুন',
      'editNote': 'নোট সম্পাদনা করুন',
      'noNotes': 'এখনো কোন নোট নেই',
      'startTyping': 'লেখা শুরু করুন...',
      'title': 'শিরোনাম',
      'untitled': 'শিরোনামহীন',
      'noContent': 'কোন কন্টেন্ট নেই',
      'areYouSure': 'আপনি কি নিশ্চিত?',
      'cancel': 'বাতিল',
      'delete': 'মুছুন',
      'save': 'সংরক্ষণ',
      'add': 'যোগ করুন',
      'financialSummary': 'মোট হিসাব সংক্ষেপ',
      'noPersonsAdded': 'এখনো কোন ব্যক্তি যোগ করা হয়নি।',
      'pullDownToRefresh': 'রিফ্রেশ করতে নিচে টানুন',
      'workingOfflineSyncWhenOnline':
          'অফলাইনে চলছে - অনলাইনে এলে ডাটা সিঙ্ক হবে',
      'dataSyncedSuccessfully': 'ডাটা সফলভাবে সিঙ্ক হয়েছে!',
      'connectionLostWorkingOffline': 'সংযোগ বিচ্ছিন্ন! অফলাইনে চলছে।',
      'workingOfflineUsingLocalData':
          'অফলাইনে চলছে - লোকাল ডাটা ব্যবহার করা হচ্ছে',
      'welcome': 'স্বাগতম',
      'user': 'ব্যবহারকারী',
      'lastSync': 'সর্বশেষ সিঙ্ক',
      'never': 'কখনও না',
      'tapToRetrySync': 'পুনরায় সিঙ্ক করতে ট্যাপ করুন',
      'userProfile': 'ব্যবহারকারীর প্রোফাইল',
      'close': 'বন্ধ করুন',
      'notesSyncedSuccessfully': 'নোট সফলভাবে সিঙ্ক হয়েছে!',
      'tapToCreateNote': 'নোট তৈরি করতে + চাপুন',
      'deleteNoteConfirm': 'আপনি কি এই নোটটি মুছতে চান?',
      'noteDeleted': 'নোট মুছে ফেলা হয়েছে',
      'iGave': 'আমি দিয়েছি',
      'iTook': 'আমি নিয়েছি',
      'transactionHistory': 'লেনদেনের ইতিহাস',
      'noTransactionsYet': 'এখনও কোনো লেনদেন নেই।',
      'deleteTransaction': 'লেনদেন মুছুন',
      'deleteTransactionConfirm': 'আপনি কি এই লেনদেনটি মুছতে চান?',
      'amount': 'পরিমাণ',
      'enterAmount': 'পরিমাণ লিখুন',
      'enterValidAmount': 'সঠিক পরিমাণ লিখুন',
      'noteOptional': 'নোট (ঐচ্ছিক)',
      'errorLoadingData': 'ডাটা লোড করতে সমস্যা হয়েছে',
      'errorSaving': 'সংরক্ষণে সমস্যা হয়েছে',
      'personName': 'ব্যক্তির নাম',
      'deletePersonConfirm': 'আপনি কি মুছতে চান',
      'trackExpensesWithEase': 'সহজে আপনার দেনা পাওনা ট্র্যাক করুন',
      'signingIn': 'সাইন ইন হচ্ছে...',
      'signInWithGoogle': 'গুগল দিয়ে সাইন ইন করুন',
      'continueAsGuest': 'গেস্ট হিসেবে চালিয়ে যান',
      'automaticCloudBackup': 'স্বয়ংক্রিয় ক্লাউড ব্যাকআপ',
      'syncAcrossDevices': 'সব ডিভাইসে সিঙ্ক',
      'successfullySignedIn': 'সফলভাবে সাইন ইন হয়েছে!',
      'signInCancelled': 'সাইন ইন বাতিল হয়েছে',
      'signInFailed': 'সাইন ইন ব্যর্থ হয়েছে',
      'networkErrorCheckConnection':
          'নেটওয়ার্ক সমস্যা। ইন্টারনেট সংযোগ পরীক্ষা করুন।',
      'googleSignInFailedTryAgain':
          'গুগল সাইন ইন ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
      'signedInAsGuest': 'গেস্ট হিসেবে সাইন ইন হয়েছে!',
      'anonymousSignInFailed': 'গেস্ট সাইন ইন ব্যর্থ হয়েছে',
      'logoutBackupSuccess': 'লগআউটের আগে ব্যাকআপ সম্পন্ন হয়েছে',
      'logoutBackupFailed':
          'লগআউটের আগে সম্পূর্ণ ব্যাকআপ করা যায়নি। লোকাল ডাটা রাখা হয়েছে।',
        'appDeveloperInfo': 'অ্যাপ সম্পর্কে',
        'developerName': 'ডেভেলপার',
        'companyName': 'কোম্পানি',
      'Gave': 'দিয়েছি',
      'Took': 'নিয়েছি',
    },
  };

  String get(String key) {
    final currentMap = translations[_currentLanguage] ?? {};
    final englishMap = translations['en'] ?? {};

    if (currentMap.containsKey(key)) {
      return currentMap[key]!;
    }
    if (englishMap.containsKey(key)) {
      return englishMap[key]!;
    }

    final normalizedRequested = _normalizeKey(key);

    for (final entry in currentMap.entries) {
      if (_normalizeKey(entry.key) == normalizedRequested) {
        return entry.value;
      }
    }

    for (final entry in englishMap.entries) {
      if (_normalizeKey(entry.key) == normalizedRequested) {
        return entry.value;
      }
    }

    return key;
  }

  String _normalizeKey(String key) {
    return key.replaceAll(RegExp(r'\s+|_'), '').toLowerCase();
  }
}
