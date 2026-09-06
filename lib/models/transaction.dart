import 'package:cloud_firestore/cloud_firestore.dart';

class HisabTransaction {
  final String id;
  final DateTime date;
  final String type;
  final double amount;
  final String account;
  final String partyId;
  final String partyName;
  final String description;

  const HisabTransaction({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    this.account = 'Cash',
    this.partyId = '',
    this.partyName = '',
    this.description = '',
  });

  factory HisabTransaction.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return HisabTransaction(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type']?.toString() ?? 'Others',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      account: data['account']?.toString() ?? 'Cash',
      partyId: data['partyId']?.toString() ?? '',
      partyName: data['partyName']?.toString() ??
          data['party']?.toString() ??
          '',
      description: data['description']?.toString() ??
          data['note']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'type': type,
      'amount': amount,
      'account': account,
      'partyId': partyId,
      'partyName': partyName,
      'description': description,
    };
  }

  HisabTransaction copyWith({
    DateTime? date,
    String? type,
    double? amount,
    String? account,
    String? partyId,
    String? partyName,
    String? description,
  }) {
    return HisabTransaction(
      id: id,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      description: description ?? this.description,
    );
  }
}
