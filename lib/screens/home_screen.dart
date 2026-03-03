import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../widgets/custom_appBar.dart';
import '../widgets/custom_bottom_navbar.dart';
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
    return persons.fold(0.0, (sum, person) => sum + person.balance);
  }

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
      appBar: CustomAppBar(
        title: widget.title,
        isLoading: _isLoading,
        isOnline: _isOnline,
        lastSyncTime: _lastSyncTime,
        onSyncPressed: () async {
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
        onSignOut: () async {
          await _authService.signOut();
        },
        onProfilePressed: _showUserProfile,
      ),

      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: 0,
        onTap: (index) async {
          // Handle bottom navigation item tap
          switch (index) {
            case 0:
              // Already on Home screen
              break;
            case 1:
              // Add new person
              final name = await _showAddPersonDialog(context);
              if (name != null && name.isNotEmpty) {
                setState(() {
                  persons.add(Person(name: name));
                });
                await _saveData();
              }
              break;
            case 2:
              // Settings screen logic (not implemented yet)
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings coming soon!')),
                );
              }
              break;
          }
        },
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

          // Summary Card
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                const Text(
                  'Financial Summary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Summary Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Total Credit
                    _buildSummaryItem(
                      icon: Icons.arrow_downward,
                      label: 'You\'ll Get',
                      amount: _totalCredit,
                      color: Colors.greenAccent,
                    ),

                    // Divider
                    Container(height: 50, width: 1, color: Colors.white30),

                    // Total Debit
                    _buildSummaryItem(
                      icon: Icons.arrow_upward,
                      label: 'You\'ll Give',
                      amount: _totalDebit,
                      color: const Color.fromARGB(255, 234, 143, 38),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white30, thickness: 1),
                const SizedBox(height: 8),

                // Net Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Net Balance: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '৳${_netBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: _netBalance >= 0
                            ? Colors.greenAccent
                            : const Color.fromARGB(255, 234, 143, 38),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                            ? 'Data synced successfully!'
                            : 'Sync failed! Working offline.',
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
                          title: Text(
                            person.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Balance: ',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: '${person.balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
                          onLongPress: () async {
                            // Delete person on long press
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: [
                              // I Gave button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
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
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 2,
                                  children: const [
                                    Icon(
                                      Icons.arrow_upward,
                                      color: Colors.green,
                                      size: 14,
                                    ),
                                    Text(
                                      'Give',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              // I Took button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
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
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 2,
                                  children: const [
                                    Icon(
                                      Icons.arrow_downward,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    Text(
                                      'Take',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                ? 'I Gave to ${person.name}'
                : 'I Took from ${person.name}',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '৳',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final v = double.tryParse(value);
                    if (v == null || v <= 0) return 'Enter valid amount';
                    return null;
                  },
                  onSaved: (value) => amount = double.tryParse(value ?? ''),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                  onChanged: (value) => note = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
                              ? 'Gave ৳${amount!.toStringAsFixed(2)} to ${person.name}'
                              : 'Took ৳${amount!.toStringAsFixed(2)} from ${person.name}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // Build summary item widget
  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '৳${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
