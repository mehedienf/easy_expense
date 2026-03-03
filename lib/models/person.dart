import 'transaction.dart';

class Person {
  final String name;
  final List<Transaction> transactions;

  Person({required this.name}) : transactions = [];

  double get balance {
    double bal = 0;
    for (var t in transactions) {
      bal += t.type == TransactionType.deposit ? t.amount : -t.amount;
    }
    return bal;
  }

  void addTransaction(Transaction t) {
    transactions.add(t);
  }

  // JSON serialization methods
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }

  factory Person.fromJson(Map<String, dynamic> json) {
    final person = Person(name: json['name']);
    if (json['transactions'] != null) {
      person.transactions.addAll(
        (json['transactions'] as List)
            .map((t) => Transaction.fromJson(t))
            .toList(),
      );
    }
    return person;
  }
}
