import 'package:cloud_firestore/cloud_firestore.dart';

class Capital {
  final String id;
  final DateTime date;
  final String type;
  final double amount;
  final String account;
  final String description;

  const Capital({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    this.account = 'Cash',
    this.description = '',
  });

  factory Capital.fromMap(String id, Map<String, dynamic> data) {
    return Capital(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type']?.toString() ?? 'Capital Received',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      account: data['account']?.toString() ?? 'Cash',
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'type': type,
      'amount': amount,
      'account': account,
      'description': description,
    };
  }

  Capital copyWith({
    DateTime? date,
    String? type,
    double? amount,
    String? account,
    String? description,
  }) {
    return Capital(
      id: id,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      description: description ?? this.description,
    );
  }
}
