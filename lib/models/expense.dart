import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final DateTime date;
  final String head;
  final String description;
  final double amount;
  final String account;

  const Expense({
    required this.id,
    required this.date,
    required this.head,
    this.description = '',
    this.amount = 0,
    this.account = 'Cash',
  });

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      head: data['head']?.toString() ??
          data['name']?.toString() ??
          'Other',
      description: data['description']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      account: data['account']?.toString() ?? 'Cash',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'head': head,
      'description': description,
      'amount': amount,
      'account': account,
    };
  }

  Expense copyWith({
    DateTime? date,
    String? head,
    String? description,
    double? amount,
    String? account,
  }) {
    return Expense(
      id: id,
      date: date ?? this.date,
      head: head ?? this.head,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      account: account ?? this.account,
    );
  }
}
