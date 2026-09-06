import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sales.dart';

class SalesService {
  SalesService._();

  static final SalesService instance = SalesService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sharedData').doc('dailyHisab').collection('sales');

  Map<String, dynamic> _withUser(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;

    return {
      ...data,
      'createdBy': user?.uid,
      'createdByEmail': user?.email,
      'deletionRequested': false,
      'updatedBy': user?.uid,
      'updatedByEmail': user?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  double calculateGross(List<SaleItem> items) {
    return items.fold<double>(
      0,
      (total, item) => total + item.amount,
    );
  }

  double calculateCommission(
    List<SaleItem> items,
    double commissionPerBox,
  ) {
    final boxes = items.fold<double>(
      0,
      (total, item) => total + item.quantity,
    );

    return boxes * commissionPerBox;
  }

  double calculateNet(
    double grossAmount,
    double commission,
  ) {
    return grossAmount - commission;
  }

  double calculateOutstanding(
    double netAmount,
    double paymentReceived,
  ) {
    final outstanding = netAmount - paymentReceived;
    return outstanding < 0 ? 0 : outstanding;
  }

  String paymentStatus(
    double netAmount,
    double paymentReceived,
  ) {
    if (paymentReceived <= 0) {
      return 'Pending';
    }

    if (paymentReceived >= netAmount) {
      return 'Paid';
    }

    return 'Partial';
  }

  Future<String> addSale(Sale sale) async {
    final doc = await _sales.add(
      _withUser(sale.toMap()),
    );

    return doc.id;
  }

  Future<void> updateSale(Sale sale) async {
    await _sales.doc(sale.id).update(
      _withUser(sale.toMap()),
    );
  }

  Future<void> deleteSale(String id) async {
    await _sales.doc(id).delete();
  }

  Stream<List<Sale>> watchSales() {
    return _sales.snapshots().map((snapshot) {
      final sales = snapshot.docs.map((doc) {
        return Sale.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();

      sales.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      return sales;
    });
  }

  Stream<List<Sale>> watchShopSales(String shopId) {
    return _sales
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      final sales = snapshot.docs.map((doc) {
        return Sale.fromMap(
          doc.id,
          doc.data(),
        );
      }).toList();

      sales.sort(
        (a, b) => b.date.compareTo(a.date),
      );

      return sales;
    });
  }
}
