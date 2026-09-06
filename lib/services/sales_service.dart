import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales.dart';
import 'firestore_service.dart';

class SalesService {
  SalesService._();
  static final instance = SalesService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _sales => _db.collection('sharedData').doc('dailyHisab').collection('sales');
  double calculateGross(List<SaleItem> items) => items.fold(0, (t, i) => t + i.amount);
  double calculateCommission(List<SaleItem> items, double perBox) => items.fold(0, (t, i) => t + i.quantity) * perBox;
  double calculateNet(double gross, double commission) => gross - commission;
  double calculateOutstanding(double net, double paid) => (net - paid).clamp(0, double.infinity);
  String paymentStatus(double net, double paid) => paid <= 0 ? 'Pending' : (paid >= net ? 'Paid' : 'Partial');
  Future<String> addSale(Sale sale) => FirestoreService.instance.add('sales', sale.toMap());
  Future<void> updateSale(Sale sale) => FirestoreService.instance.update('sales', sale.id, sale.toMap());
  Future<void> deleteSale(String id) => FirestoreService.instance.delete('sales', id);
  Stream<List<Sale>> watchSales() => _sales.snapshots().map((s) { final x = s.docs.map((d) => Sale.fromMap(d.id, d.data())).toList(); x.sort((a,b)=>b.date.compareTo(a.date)); return x; });
  Stream<List<Sale>> watchShopSales(String shopId) => _sales.where('shopId', isEqualTo: shopId).snapshots().map((s) { final x=s.docs.map((d)=>Sale.fromMap(d.id,d.data())).toList(); x.sort((a,b)=>b.date.compareTo(a.date)); return x; });
}
