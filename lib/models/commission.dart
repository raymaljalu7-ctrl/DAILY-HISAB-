import 'package:cloud_firestore/cloud_firestore.dart';

class Commission {
  final String id;
  final DateTime date;
  final String shopId;
  final String shopName;
  final double amount;
  final String account;
  final String description;

  const Commission({
    required this.id,
    required this.date,
    required this.shopId,
    required this.shopName,
    required this.amount,
    this.account = 'Cash',
    this.description = '',
  });

  factory Commission.fromMap(String id, Map<String, dynamic> data) {
    return Commission(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shopId: data['shopId']?.toString() ?? '',
      shopName: data['shopName']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      account: data['account']?.toString() ?? 'Cash',
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'shopId': shopId,
      'shopName': shopName,
      'amount': amount,
      'account': account,
      'description': description,
    };
  }

  Commission copyWith({
    DateTime? date,
    String? shopId,
    String? shopName,
    double? amount,
    String? account,
    String? description,
  }) {
    return Commission(
      id: id,
      date: date ?? this.date,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      description: description ?? this.description,
    );
  }
}
