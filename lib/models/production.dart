import 'package:cloud_firestore/cloud_firestore.dart';

class Production {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;

  const Production({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unit = 'Box',
  });

  factory Production.fromMap(String id, Map<String, dynamic> data) {
    return Production(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      productId: data['productId']?.toString() ?? '',
      productName: data['productName']?.toString() ??
          data['product']?.toString() ??
          '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unit: data['unit']?.toString() ?? 'Box',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
    };
  }

  Production copyWith({
    DateTime? date,
    String? productId,
    String? productName,
    double? quantity,
    String? unit,
  }) {
    return Production(
      id: id,
      date: date ?? this.date,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
