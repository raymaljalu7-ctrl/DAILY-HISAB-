import 'package:cloud_firestore/cloud_firestore.dart';

class CashManagementService {
  CashManagementService._();
  static final instance = CashManagementService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _transactions => _db.collection('sharedData').doc('dailyHisab').collection('transactions');
  CollectionReference<Map<String, dynamic>> get _sales => _db.collection('sharedData').doc('dailyHisab').collection('sales');
  CollectionReference<Map<String, dynamic>> get _capital => _db.collection('sharedData').doc('dailyHisab').collection('capital');

  Future<Map<String, double>> balances() async {
    double cash = 0, bank = 0;
    void apply(String account, double value) { if (account == 'Bank') bank += value; else cash += value; }
    final tx = await _transactions.get();
    for (final d in tx.docs) {
      final x = d.data(); final amount = (x['amount'] as num?)?.toDouble() ?? 0; final type = x['type']?.toString() ?? '';
      final sign = type == 'Receipt' ? 1 : (type == 'Payment' || type == 'Commission Payment') ? -1 : 0;
      apply(x['account']?.toString() ?? 'Cash', amount * sign);
    }
    final sales = await _sales.get();
    for (final d in sales.docs) {
      final x = d.data(); final amount = (x['paymentReceived'] as num?)?.toDouble() ?? 0;
      if (amount > 0) apply(x['paymentAccount']?.toString() ?? 'Cash', amount);
    }
    final capital = await _capital.get();
    for (final d in capital.docs) {
      final x = d.data(); final amount = (x['amount'] as num?)?.toDouble() ?? 0; final type = x['type']?.toString() ?? '';
      apply(x['account']?.toString() ?? 'Cash', type == 'Capital Received' ? amount : -amount);
    }
    return {'Cash': cash, 'Bank': bank};
  }
}
