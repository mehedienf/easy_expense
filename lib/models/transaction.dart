enum TransactionType { deposit, expense }

class Transaction {
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String note;

  Transaction({
    required this.amount,
    required this.type,
    required this.date,
    this.note = '',
  });

  // Convert Transaction to JSON
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type.index, // Convert enum to int
      'date': date.millisecondsSinceEpoch,
      'note': note,
    };
  }

  // Create Transaction from JSON
  static Transaction fromJson(Map<String, dynamic> json) {
    return Transaction(
      amount: json['amount'].toDouble(),
      type: TransactionType.values[json['type']],
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      note: json['note'] ?? '',
    );
  }
}
