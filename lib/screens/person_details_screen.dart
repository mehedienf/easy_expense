import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/transaction.dart';

class PersonDetailsScreen extends StatefulWidget {
  final Person person;
  final VoidCallback onTransactionAdded;
  final Future<void> Function() onDataChanged;

  const PersonDetailsScreen({
    super.key,
    required this.person,
    required this.onTransactionAdded,
    required this.onDataChanged,
  });

  @override
  State<PersonDetailsScreen> createState() => _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends State<PersonDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.person.name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Balance: ${widget.person.balance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Deposit'),
                  onPressed: () async {
                    await _showTransactionDialog(
                      context,
                      TransactionType.deposit,
                    );
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('Expense'),
                  onPressed: () async {
                    await _showTransactionDialog(
                      context,
                      TransactionType.expense,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Transaction History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: widget.person.transactions.isEmpty
                ? const Center(child: Text('No transactions yet.'))
                : ListView.builder(
                    itemCount: widget.person.transactions.length,
                    itemBuilder: (context, index) {
                      final t = widget.person.transactions[index];
                      return ListTile(
                        leading: Icon(
                          t.type == TransactionType.deposit
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: t.type == TransactionType.deposit
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(
                          '${t.type == TransactionType.deposit ? 'Deposit' : 'Expense'}: ${t.amount.toStringAsFixed(2)}',
                        ),
                        subtitle: Text(
                          '${t.note.isNotEmpty ? '${t.note}\n' : ''}${t.date.toLocal().toString().split(' ')[0]}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete Transaction',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Transaction'),
                                content: const Text(
                                  'Are you sure you want to delete this transaction?',
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
                                widget.person.transactions.removeAt(index);
                              });
                              widget.onTransactionAdded();
                              await widget.onDataChanged();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionDialog(
    BuildContext context,
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
            type == TransactionType.deposit ? 'Add Deposit' : 'Add Expense',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter amount';
                    final v = double.tryParse(value);
                    if (v == null || v <= 0) return 'Enter valid amount';
                    return null;
                  },
                  onSaved: (value) => amount = double.tryParse(value ?? ''),
                ),
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
                      widget.person.addTransaction(
                        Transaction(
                          amount: amount!,
                          type: type,
                          date: DateTime.now(),
                          note: note,
                        ),
                      );
                    });
                    widget.onTransactionAdded();
                    widget.onDataChanged();
                    Navigator.of(context).pop();
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
}
