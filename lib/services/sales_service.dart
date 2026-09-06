import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sales.dart';
import 'firestore_service.dart';

class SalesService {
  SalesService._();
  static final instance = SalesService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _sales => _db.collection('sharedData').doc('dailyHisab').collection('sales');

  double calculateGross(List<SaleItem> items) => items.fold<double>(0.0, (t, i) => t + i.amount);
  double calculateCommission(List<SaleItem> items, double perBox) => items.fold<double>(0.0, (t, i) => t + i.quantity) * perBox;
  double calculateNet(double gross, double commission) => gross - commission;
  double calculateOutstanding(double net, double paid) => (net - paid).clamp(0.0, double.infinity);
  String paymentStatus(double net, double paid) => paid <= 0 ? 'Pending' : (paid >= net ? 'Paid' : 'Partial');

  Future<String> addSale(Sale sale) => FirestoreService.instance.add('sales', sale.toMap());
  Future<void> updateSale(Sale sale) => FirestoreService.instance.update('sales', sale.id, sale.toMap());
  Future<void> deleteSale(String id) => FirestoreService.instance.delete('sales', id);

  Stream<List<Sale>> watchSales() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return Stream.fromFuture(_db.collection('users').doc(uid).get()).asyncExpand((profile) {
      final data = profile.data() ?? <String, dynamic>{};
      final role = data['role']?.toString();
      final shopId = data['shopId']?.toString();
      if (role == 'retail_shop_user' && shopId != null && shopId.isNotEmpty) {
        return watchShopSales(shopId);
      }
      return _sales.snapshots().map((snapshot) {
        final sales = snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();
        sales.sort((a, b) => b.date.compareTo(a.date));
        return sales;
      });
    });
  }

  Stream<List<Sale>> watchShopSales(String shopId) => _sales.where('shopId', isEqualTo: shopId).snapshots().map((snapshot) {
        final sales = snapshot.docs.map((doc) => Sale.fromMap(doc.id, doc.data())).toList();
        sales.sort((a, b) => b.date.compareTo(a.date));
        return sales;
      });
}
