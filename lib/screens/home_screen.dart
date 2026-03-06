import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/transaction.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/custom_appBar.dart';
import '../widgets/custom_bottom_navbar.dart';
import 'notes_screen.dart';
import 'person_details_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Person> persons = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final AppSettings _appSettings = AppSettings();
  final SyncService _syncService = SyncService();
  bool _isLoading = false;
  int _activeBackupJobs = 0;
  int _currentTabIndex = 0;
  bool _showOfflineBanner = false;
  Timer? _offlineBannerTimer;

  bool get _isOnline => _syncService.isOnline;
  DateTime? get _lastSyncTime => _syncService.lastSyncTime;
  bool get _isAppBarLoading => _isLoading || _activeBackupJobs > 0;

  void _setBackupLoading(bool isStarting) {
    if (!mounted) return;
    setState(() {
      if (isStarting) {
        _activeBackupJobs += 1;
      } else {
        _activeBackupJobs = (_activeBackupJobs - 1).clamp(0, 1 << 30);
      }
    });
  }

  // Calculate total credit (people who owe us money - positive balance)
  double get _totalCredit {
    return persons.fold(0.0, (sum, person) {
      return sum + (person.balance > 0 ? person.balance : 0);
    });
  }

  // Calculate total debit (people we owe money - negative balance)
  double get _totalDebit {
    return persons.fold(0.0, (sum, person) {
      return sum + (person.balance < 0 ? person.balance.abs() : 0);
    });
  }

  // Calculate net balance
  double get _netBalance {
    return _totalCredit - _totalDebit;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _syncWithFirebase();
    // Auto-reconnect logic: Check every 5 seconds
    Future.delayed(const Duration(seconds: 5), _checkAndRetrySync);
    // Check initial offline status after build
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isOnline && mounted) {
        _showOfflineBannerTemporary();
      }
    });
  }

  @override
  void dispose() {
    _offlineBannerTimer?.cancel();
    super.dispose();
  }

  void _showOfflineBannerTemporary() {
    _offlineBannerTimer?.cancel();
    setState(() {
      _showOfflineBanner = true;
    });
    _offlineBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showOfflineBanner = false;
        });
      }
    });
  }

  // Retry sync logic when network is detected
  Future<void> _checkAndRetrySync() async {
    if (!mounted) return;

    final wasOnline = _isOnline;
    await _syncService.checkConnectivity();
    final isNowOnline = _isOnline;

    // Update UI if status changed
    if (wasOnline != isNowOnline) {
      if (!isNowOnline) {
        _showOfflineBannerTemporary();
      }
      if (mounted) setState(() {});

      // If we just came online, sync data (isOnline already set by checkConnectivity above)
      if (isNowOnline && !wasOnline) {
        if (!_isLoading) {
          setState(() => _isLoading = true);
          try {
            final syncedData = await _syncService.fullSync();
            if (mounted) {
              setState(() {
                persons.clear();
                persons.addAll(syncedData);
                _isLoading = false;
              });
            }
          } catch (e) {
            if (mounted) setState(() => _isLoading = false);
          }
        }
      }
    }

    // Use adaptive interval: check frequently when offline, less when online
    final checkInterval = isNowOnline
        ? const Duration(seconds: 30)
        : const Duration(seconds: 3);

    if (mounted) Future.delayed(checkInterval, _checkAndRetrySync);
  }

  // Load data from local storage
  Future<void> _loadData() async {
    try {
      final result = await _syncService.loadFromLocal();
      if (mounted) {
        setState(() {
          persons.clear();
          persons.addAll(result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_appSettings.get('errorLoadingData')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Save data to local storage and sync to Firebase
  Future<void> _saveData() async {
    try {
      await _syncService.saveToLocal(persons);

      final personsSnapshot = persons
          .map((person) => Person.fromJson(person.toJson()))
          .toList();
      _setBackupLoading(true);
      unawaited(
        _syncService
            .saveToFirebase(personsSnapshot)
            .whenComplete(() => _setBackupLoading(false)),
      );
      unawaited(_syncService.checkConnectivity());

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_appSettings.get('errorSaving')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Sync with Firebase
  Future<void> _syncWithFirebase() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Check connectivity first, then sync
      await _syncService.checkConnectivity();
      
      // Show offline banner if not online
      if (!_isOnline) {
        _showOfflineBannerTemporary();
      }
      
      final syncedData = await _syncService.fullSync();
      if (mounted) {
        setState(() {
          persons.clear();
          persons.addAll(syncedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignOutWithStatus() async {
    final backupSuccess = await _authService.backupBeforeSignOut();
    if (!mounted) return;

    final message = backupSuccess
        ? _appSettings.get('logoutBackupSuccess')
        : _appSettings.get('logoutBackupFailed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
        backgroundColor: backupSuccess ? Colors.green : Colors.orange,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 700));
    await _authService.completeSignOut();
  }

  void _showAppDeveloperInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_appSettings.get('appDeveloperInfo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_appSettings.get('appName')}: ${_appSettings.get('DenaPaona')}',
            ),
            const SizedBox(height: 8),
            Text('${_appSettings.get('developerName')}: OlivoSoft'),
            Text('${_appSettings.get('version')}: 1.0.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_appSettings.get('close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                // color: Theme.of(context).colorScheme.inversePrimary,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _appSettings.get('DenaPaona'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(65, 0, 0, 0),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(_appSettings.get('home')),
                selected: _currentTabIndex == 0,
                onTap: () {
                  setState(() => _currentTabIndex = 0);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: Text(_appSettings.get('notes')),
                selected: _currentTabIndex == 1,
                onTap: () {
                  setState(() => _currentTabIndex = 1);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(_appSettings.get('settings')),
                selected: _currentTabIndex == 2,
                onTap: () {
                  setState(() => _currentTabIndex = 2);
                  Navigator.of(context).pop();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  _appSettings.get('logout'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _handleSignOutWithStatus();
                },
              ),
              const Spacer(),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(_appSettings.get('appDeveloperInfo')),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAppDeveloperInfo();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: CustomAppBar(
        title: _appSettings.get('home'),
        isLoading: _isAppBarLoading,
        isOnline: _isOnline,
        // showDrawerButton: true,
        lastSyncTime: _lastSyncTime,
        onSyncPressed: _syncWithFirebase,
        onSignOut: () async {
          await _handleSignOutWithStatus();
        },
        onProfilePressed: _showUserProfile,
      ),

      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: _currentTabIndex == 0
            ? Column(
                children: [
                  // Offline indicator
                  if (!_isOnline && _showOfflineBanner)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.orange.shade100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.orange.shade800,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _appSettings.get('workingOfflineSyncWhenOnline'),
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Main content with RefreshIndicator
                  Expanded(
                    child: RefreshIndicator(
                      edgeOffset: 0,
                      displacement: 40.0,
                      onRefresh: () async {
                        final wasOnline = _isOnline;
                        // _syncWithFirebase checks connectivity then syncs
                        await _syncWithFirebase();
                        if (!mounted) return;

                        final isNowOnline = _isOnline;
                        String message;
                        Color bgColor;

                        if (isNowOnline) {
                          message = _appSettings.get('dataSyncedSuccessfully');
                          bgColor = Colors.green;
                        } else if (wasOnline && !isNowOnline) {
                          message = _appSettings.get(
                            'connectionLostWorkingOffline',
                          );
                          bgColor = Colors.orange;
                        } else {
                          message = _appSettings.get(
                            'workingOfflineUsingLocalData',
                          );
                          bgColor = Colors.orange;
                        }

                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            duration: const Duration(seconds: 2),
                            backgroundColor: bgColor,
                          ),
                        );
                      },
                      child: CustomScrollView(
                        slivers: [
                          // Summary Card as sliver
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.all(16.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 94, 148, 255),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Header
                                  Text(
                                    _appSettings.get('financialSummary'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),

                                  // Divider
                                  const Divider(
                                    color: Colors.white30,
                                    thickness: 1,
                                    indent: 0,
                                    endIndent: 0,
                                  ),

                                  // Summary Stats
                                  // Total Credit
                                  _buildSummaryItem(
                                    icon: Icons.arrow_downward,
                                    label:
                                        '${_appSettings.get('youWillGet')}: ',
                                    amount: _totalCredit,
                                    color: Colors.greenAccent,
                                  ),
                                  const SizedBox(height: 8),
                                  // Total Debit
                                  _buildSummaryItem(
                                    icon: Icons.arrow_upward,
                                    label:
                                        '${_appSettings.get('youWillGive')}: ',
                                    amount: _totalDebit,
                                    color: const Color.fromARGB(
                                      255,
                                      234,
                                      143,
                                      38,
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  const Divider(
                                    color: Colors.white30,
                                    thickness: 1,
                                  ),
                                  const SizedBox(height: 4),

                                  // Net Balance
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${_appSettings.get('netBalance')}: ',
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            225,
                                            255,
                                            255,
                                            255,
                                          ),
                                          fontSize: 18,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '৳${_netBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: _netBalance >= 0
                                              ? Colors.greenAccent
                                              : const Color.fromARGB(
                                                  255,
                                                  234,
                                                  143,
                                                  38,
                                                ),
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Persons list
                          persons.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people_outline,
                                          size: 80,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          _appSettings.get('noPersonsAdded'),
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          _appSettings.get('pullDownToRefresh'),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SliverReorderableList(
                                  itemCount: persons.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      if (newIndex > oldIndex) {
                                        newIndex -= 1;
                                      }
                                      final movedPerson = persons.removeAt(
                                        oldIndex,
                                      );
                                      persons.insert(newIndex, movedPerson);
                                    });
                                    _saveData();
                                  },
                                  itemBuilder: (context, index) {
                                    final person = persons[index];
                                    return ReorderableDelayedDragStartListener(
                                      key: ObjectKey(person),
                                      index: index,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          padding: const EdgeInsets.all(0),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color.fromARGB(
                                              255,
                                              242,
                                              243,
                                              251,
                                            ),
                                            // border: Border.all(
                                            //   color: Colors.grey.shade300,
                                            //   width: 1,
                                            // ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color.fromARGB(
                                                  255,
                                                  118,
                                                  117,
                                                  117,
                                                ).withValues(alpha: 0.5),
                                                blurRadius: 1,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),

                                          // ListTile with person details
                                          child: ListTile(
                                            title: Text(
                                              person.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text:
                                                        '${_appSettings.get('balance')}: ',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: person.balance
                                                        .toStringAsFixed(2),
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade800,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            onTap: () async {
                                              final shouldDelete =
                                                  await Navigator.of(
                                                    context,
                                                  ).push<bool>(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PersonDetailsScreen(
                                                            person: person,
                                                            onTransactionAdded:
                                                                () {
                                                                  setState(
                                                                    () {},
                                                                  );
                                                                },
                                                            onDataChanged:
                                                                _saveData,
                                                          ),
                                                    ),
                                                  );

                                              // If person was deleted from details screen
                                              if (shouldDelete == true) {
                                                setState(() {
                                                  persons.removeAt(index);
                                                });
                                                await _saveData();
                                                if (!mounted) return;

                                                ScaffoldMessenger.of(
                                                  // ignore: use_build_context_synchronously
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '${person.name} deleted',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },

                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // I Gave button
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onPressed: () async {
                                                    await _showQuickTransactionDialog(
                                                      context,
                                                      person,
                                                      TransactionType.deposit,
                                                    );
                                                  },
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.arrow_upward,
                                                        color: Colors.green,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _appSettings.get(
                                                          'Gave',
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // I Took button
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onPressed: () async {
                                                    await _showQuickTransactionDialog(
                                                      context,
                                                      person,
                                                      TransactionType.expense,
                                                    );
                                                  },
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.arrow_downward,
                                                        color: Colors.red,
                                                        size: 14,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _appSettings.get(
                                                          'Took',
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _currentTabIndex == 1
            ? NotesScreenBody(
                key: const ValueKey('notes_tab'),
                onBackupStateChanged: _setBackupLoading,
              )
            : const SettingsScreenBody(key: ValueKey('settings_tab')),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 148, 203, 255),
              elevation: 2,
              onPressed: () async {
                final name = await _showAddPersonDialog(context);
                if (name != null && name.isNotEmpty) {
                  setState(() {
                    persons.add(Person(name: name));
                  });
                  await _saveData();
                }
              },
              tooltip: _appSettings.get('addPerson'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // Build summary item widget
  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Row(
      children: [
        // Label on left
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(225, 255, 255, 255),
            fontSize: 16,
          ),
        ),

        const Spacer(),

        // Amount and Icon on right
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 24),
      ],
    );
  }

  // Show add person dialog
  Future<String?> _showAddPersonDialog(BuildContext context) {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_appSettings.get('addPerson')),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: _appSettings.get('personName'),
            ),
            onChanged: (value) => name = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_appSettings.get('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(name),
              child: Text(_appSettings.get('add')),
            ),
          ],
        );
      },
    );
  }

  // Quick transaction dialog for home screen
  Future<void> _showQuickTransactionDialog(
    BuildContext context,
    Person person,
    TransactionType type,
  ) async {
    double? amount;
    String note = '';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            type == TransactionType.deposit
                ? '${_appSettings.get('iGave')} ${person.name}'
                : '${_appSettings.get('iTook')} ${person.name}',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _appSettings.get('amount'),
                    prefixText: '৳',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _appSettings.get('enterAmount');
                    }
                    final v = double.tryParse(value);
                    if (v == null || v <= 0) {
                      return _appSettings.get('enterValidAmount');
                    }
                    return null;
                  },
                  onSaved: (value) => amount = double.tryParse(value ?? ''),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: _appSettings.get('noteOptional'),
                  ),
                  onChanged: (value) => note = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_appSettings.get('cancel')),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  if (amount != null) {
                    setState(() {
                      person.addTransaction(
                        Transaction(
                          amount: amount!,
                          type: type,
                          date: DateTime.now(),
                          note: note,
                        ),
                      );
                    });
                    _saveData();
                    Navigator.of(context).pop();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          type == TransactionType.deposit
                              ? '${_appSettings.get('iGave')} ৳${amount!.toStringAsFixed(2)} ${person.name}'
                              : '${_appSettings.get('iTook')} ৳${amount!.toStringAsFixed(2)} ${person.name}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: Text(_appSettings.get('add')),
            ),
          ],
        );
      },
    );
  }

  // Show user profile dialog
  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_appSettings.get('userProfile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _auth.currentUser?.photoURL != null
                  ? NetworkImage(_auth.currentUser!.photoURL!)
                  : null,
              child: _auth.currentUser?.photoURL == null
                  ? Text(
                      (_auth.currentUser?.displayName?.isNotEmpty == true)
                          ? _auth.currentUser!.displayName!
                                .substring(0, 1)
                                .toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _auth.currentUser?.displayName ?? _appSettings.get('user'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _auth.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              '${_appSettings.get('lastSync')}: ${_lastSyncTime != null ? "${_lastSyncTime!.day}/${_lastSyncTime!.month} ${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}" : _appSettings.get('never')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_appSettings.get('close')),
          ),
        ],
      ),
    );
  }
}
