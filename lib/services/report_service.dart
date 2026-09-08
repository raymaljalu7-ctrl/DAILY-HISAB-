import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  ReportService._();
  static final instance = ReportService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String name) => _db.collection('sharedData').doc('dailyHisab').collection(name);

  Future<String?> _assignedRetailShopId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data() ?? <String, dynamic>{};
    if (data['role']?.toString() != 'retail_shop_user') return null;
    final shopId = data['shopId']?.toString();
    return shopId == null || shopId.isEmpty ? null : shopId;
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _inRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  Future<List<Map<String, dynamic>>> sales({required DateTime from, required DateTime to, String? shopId, String? productId}) async {
    final assignedShopId = await _assignedRetailShopId();
    final effectiveShopId = assignedShopId ?? shopId;
    final snapshot = await _collection('sales').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      if (effectiveShopId != null && effectiveShopId.isNotEmpty && data['shopId']?.toString() != effectiveShopId) continue;
      if (productId != null && productId.isNotEmpty) {
        final rawItems = data['items'] as List<dynamic>? ?? [];
        if (!rawItems.any((item) => item is Map && item['productId']?.toString() == productId)) continue;
      }
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> transactions({required DateTime from, required DateTime to, String? type, String? shopId, String? account}) async {
    final assignedShopId = await _assignedRetailShopId();
    if (assignedShopId != null) return <Map<String, dynamic>>[];
    final effectiveShopId = shopId;
    final snapshot = await _collection('transactions').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      final rowType = data['type']?.toString() ?? '';
      if (type != null && type.isNotEmpty) {
        final matchesRequested = type == 'Receipt' ? (rowType == 'Receipt' || rowType == 'Payment') : rowType == type;
        if (!matchesRequested) continue;
      }
      if (account != null && account.isNotEmpty && data['account']?.toString() != account) continue;
      if (effectiveShopId != null && effectiveShopId.isNotEmpty && data['shopId']?.toString() != effectiveShopId) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> production({required DateTime from, required DateTime to, String? productId}) async {
    if (await _assignedRetailShopId() != null) return <Map<String, dynamic>>[];
    final snapshot = await _collection('production').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      if (productId != null && productId.isNotEmpty && data['productId']?.toString() != productId) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> expenses({required DateTime from, required DateTime to, String? head}) async {
    if (await _assignedRetailShopId() != null) return <Map<String, dynamic>>[];
    final snapshot = await _collection('productionExpenses').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      if (head != null && head.isNotEmpty && (data['head'] ?? data['name']).toString() != head) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> salary({required DateTime from, required DateTime to, String? workerId}) async {
    if (await _assignedRetailShopId() != null) return <Map<String, dynamic>>[];
    final snapshot = await _collection('salary').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      if (workerId != null && workerId.isNotEmpty && data['workerId']?.toString() != workerId) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> capital({required DateTime from, required DateTime to}) async {
    if (await _assignedRetailShopId() != null) return <Map<String, dynamic>>[];
    final snapshot = await _collection('capital').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }

  Future<List<Map<String, dynamic>>> commissions({required DateTime from, required DateTime to, String? shopId}) async {
    final assignedShopId = await _assignedRetailShopId();
    if (assignedShopId != null) return <Map<String, dynamic>>[];
    final effectiveShopId = shopId;
    final snapshot = await _collection('commissions').get();
    final rows = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      if (effectiveShopId != null && effectiveShopId.isNotEmpty && data['shopId']?.toString() != effectiveShopId) continue;
      rows.add({'id': doc.id, ...data});
    }
    rows.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
    return rows;
  }
}
