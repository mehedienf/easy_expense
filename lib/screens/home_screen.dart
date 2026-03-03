import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'person_details_screen.dart';

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
  final SyncService _syncService = SyncService();
  bool _isLoading = false;

  bool get _isOnline => _syncService.isOnline;
  DateTime? get _lastSyncTime => _syncService.lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data from local storage and Firebase
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Load local data FIRST — instant, no network needed
    await _loadFromLocal();

    // Show UI immediately with local data
    setState(() {
      _isLoading = false;
    });

    // Sync Firebase in background — doesn't block UI
    _syncWithFirebase();
  }

  // Load data from SharedPreferences (user-specific local storage)
  Future<void> _loadFromLocal() async {
    final loadedPersons = await _syncService.loadFromLocal();
    setState(() {
      persons.clear();
      persons.addAll(loadedPersons);
    });
  }

  // Sync data with Firebase
  Future<void> _syncWithFirebase() async {
    final loadedPersons = await _syncService.syncFromFirebase();
    setState(() {
      persons.clear();
      persons.addAll(loadedPersons);
    });
  }

  // Save data to both local and Firebase
  Future<void> _saveData() async {
    await _syncService.syncToFirebase(persons);
    setState(() {}); // Update UI to reflect sync status
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              'Welcome, ${_auth.currentUser?.displayName ?? 'User'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          // Sync status indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                _isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: _isOnline ? Colors.green : Colors.red,
              ),
              onPressed: () async {
                await _syncWithFirebase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isOnline
                            ? 'Data synced successfully!'
                            : 'Sync failed. Working offline.',
                      ),
                      backgroundColor: _isOnline ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              tooltip: _isOnline
                  ? 'Last sync: ${_lastSyncTime != null ? "${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}" : "Never"}'
                  : 'Tap to retry sync',
            ),

          // User profile menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                _showUserProfile();
              } else if (value == 'signout') {
                await _authService.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text(_auth.currentUser?.email ?? ''),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.orange.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.orange.shade800, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Working offline - Data will sync when online',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _syncWithFirebase();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isOnline
                            ? '✅ Data synced successfully!'
                            : '⚠️ Sync failed. Working offline.',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: _isOnline ? Colors.green : Colors.orange,
                    ),
                  );
                }
              },
              child: persons.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                        ),
                        const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No persons added yet.',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pull down to refresh',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: persons.length,
                      itemBuilder: (context, index) {
                        final person = persons[index];
                        return ListTile(
                          title: Text(person.name),
                          subtitle: Text(
                            'Balance: ${person.balance.toStringAsFixed(2)}',
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PersonDetailsScreen(
                                  person: person,
                                  onTransactionAdded: () {
                                    setState(() {});
                                  },
                                  onDataChanged: _saveData,
                                ),
                              ),
                            );
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Person',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Person'),
                                  content: Text(
                                    'Are you sure you want to delete ${person.name}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                setState(() {
                                  persons.removeAt(index);
                                });
                                await _saveData();
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _showAddPersonDialog(context);
          if (name != null && name.isNotEmpty) {
            setState(() {
              persons.add(Person(name: name));
            });
            await _saveData();
          }
        },
        tooltip: 'Add Person',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _showAddPersonDialog(BuildContext context) async {
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Person'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Person name'),
            onChanged: (value) => name = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(name),
              child: const Text('Add'),
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
        title: const Text('User Profile'),
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
              _auth.currentUser?.displayName ?? 'User',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _auth.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Last Sync: ${_lastSyncTime != null ? "${_lastSyncTime!.day}/${_lastSyncTime!.month} at ${_lastSyncTime!.hour}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}" : "Never"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
