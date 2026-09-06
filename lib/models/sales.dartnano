import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double amount;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory SaleItem.fromMap(Map<String, dynamic> data) {
    return SaleItem(
      productId: data['productId']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'amount': amount,
    };
  }
}

class Sale {
  final String id;
  final DateTime date;
  final String shopId;
  final String shopName;
  final List<SaleItem> items;
  final double grossAmount;
  final double commission;
  final double netAmount;
  final double paymentReceived;
  final double outstanding;
  final String paymentStatus;

  const Sale({
    required this.id,
    required this.date,
    required this.shopId,
    required this.shopName,
    required this.items,
    required this.grossAmount,
    required this.commission,
    required this.netAmount,
    this.paymentReceived = 0,
    this.outstanding = 0,
    this.paymentStatus = 'Pending',
  });

  factory Sale.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'] as List<dynamic>? ?? [];

    return Sale(
      id: id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shopId: data['shopId']?.toString() ?? '',
      shopName: data['shopName']?.toString() ?? '',
      items: rawItems
          .whereType<Map>()
          .map((item) => SaleItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      grossAmount: (data['grossAmount'] as num?)?.toDouble() ?? 0,
      commission: (data['commission'] as num?)?.toDouble() ?? 0,
      netAmount: (data['netAmount'] as num?)?.toDouble() ?? 0,
      paymentReceived: (data['paymentReceived'] as num?)?.toDouble() ?? 0,
      outstanding: (data['outstanding'] as num?)?.toDouble() ?? 0,
      paymentStatus: data['paymentStatus']?.toString() ?? 'Pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'shopId': shopId,
      'shopName': shopName,
      'items': items.map((item) => item.toMap()).toList(),
      'grossAmount': grossAmount,
      'commission': commission,
      'netAmount': netAmount,
      'paymentReceived': paymentReceived,
      'outstanding': outstanding,
      'paymentStatus': paymentStatus,
    };
  }

  Sale copyWith({
    DateTime? date,
    String? shopId,
    String? shopName,
    List<SaleItem>? items,
    double? grossAmount,
    double? commission,
    double? netAmount,
    double? paymentReceived,
    double? outstanding,
    String? paymentStatus,
  }) {
    return Sale(
      id: id,
      date: date ?? this.date,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      items: items ?? this.items,
      grossAmount: grossAmount ?? this.grossAmount,
      commission: commission ?? this.commission,
      netAmount: netAmount ?? this.netAmount,
      paymentReceived: paymentReceived ?? this.paymentReceived,
      outstanding: outstanding ?? this.outstanding,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
