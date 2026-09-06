import 'package:cloud_firestore/cloud_firestore.dart';

class Salary {
  final String id;
  final DateTime date;
  final String workerId;
  final String workerName;
  final String type;
  final double amount;
  final String description;

  const Salary({
    required this.id,
    required this.date,
    required this.workerId,
    required this.workerName,
    required this.type,
    required this.amount,
    this.description = '',
  });

  factory Salary.fromMap(String id, Map<String, dynamic> data) {
    return Salary(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      workerId: data['workerId']?.toString() ?? '',
      workerName: data['workerName']?.toString() ?? '',
      type: data['type']?.toString() ?? 'Salary Payment',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'workerId': workerId,
      'workerName': workerName,
      'type': type,
      'amount': amount,
      'description': description,
    };
  }

  Salary copyWith({
    DateTime? date,
    String? workerId,
    String? workerName,
    String? type,
    double? amount,
    String? description,
  }) {
    return Salary(
      id: id,
      date: date ?? this.date,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
    );
  }
}
