import 'package:flutter/material.dart';

import '../models/person.dart';
import '../models/transaction.dart';
import '../services/app_settings.dart';

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
  final AppSettings _appSettings = AppSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: _appSettings.get('deletePerson'),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(_appSettings.get('deletePerson')),
                  content: Text(
                    '${_appSettings.get('deletePersonConfirm')} ${widget.person.name}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(_appSettings.get('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(
                        _appSettings.get('delete'),
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // Return true to indicate person should be deleted
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${_appSettings.get('balance')}: ${widget.person.balance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  // icon: const Icon(Icons.add),
                  label: Text(_appSettings.get('iGave')),
                  onPressed: () async {
                    await _showTransactionDialog(
                      context,
                      TransactionType.deposit,
                    );
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  // icon: const Icon(Icons.remove),
                  label: Text(_appSettings.get('iTook')),
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
            child: SizedBox(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _appSettings.get('transactionHistory'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: widget.person.transactions.isEmpty
                ? Center(child: Text(_appSettings.get('noTransactionsYet')))
                : ListView.builder(
                    itemCount: widget.person.transactions.length,
                    itemBuilder: (context, index) {
                      final t = widget.person.transactions[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: Icon(
                            t.type == TransactionType.deposit
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: t.type == TransactionType.deposit
                                ? Colors.green
                                : Colors.red,
                          ),
                          title: Text(
                            '${t.type == TransactionType.deposit ? _appSettings.get('iGave') : _appSettings.get('iTook')}: ${t.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            '${t.note.isNotEmpty ? '${t.note}\n' : ''}${t.date.toLocal().toString().split(' ')[0]}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: _appSettings.get('deleteTransaction'),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    _appSettings.get('deleteTransaction'),
                                  ),
                                  content: Text(
                                    _appSettings.get(
                                      'deleteTransactionConfirm',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: Text(_appSettings.get('cancel')),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: Text(
                                        _appSettings.get('delete'),
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
            type == TransactionType.deposit
                ? _appSettings.get('iGave')
                : _appSettings.get('iTook'),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _appSettings.get('amount'),
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
              child: Text(_appSettings.get('add')),
            ),
          ],
        );
      },
    );
  }
}
