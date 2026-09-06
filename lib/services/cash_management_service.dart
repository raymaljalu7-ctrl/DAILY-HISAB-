import 'package:cloud_firestore/cloud_firestore.dart';

class CashManagementService {
  CashManagementService._();
  static final instance = CashManagementService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _c(String name) =>
      _db.collection('sharedData').doc('dailyHisab').collection(name);

  Future<Map<String, double>> balances() async {
    double cash = 0, bank = 0;
    void apply(String account, double value) {
      if (account == 'Bank') bank += value; else cash += value;
    }

    for (final d in (await _c('transactions').get()).docs) {
      final x = d.data();
      final amount = (x['amount'] as num?)?.toDouble() ?? 0;
      final type = x['type']?.toString() ?? '';
      final sign = type == 'Receipt' ? 1 :
          (type == 'Payment' || type == 'Commission Payment') ? -1 : 0;
      apply(x['account']?.toString() ?? 'Cash', amount * sign);
    }

    for (final d in (await _c('sales').get()).docs) {
      final x = d.data();
      final amount = (x['paymentReceived'] as num?)?.toDouble() ?? 0;
      if (amount > 0) apply(x['paymentAccount']?.toString() ?? 'Cash', amount);
    }

    for (final d in (await _c('productionExpenses').get()).docs) {
      final x = d.data();
      final amount = (x['amount'] as num?)?.toDouble() ?? 0;
      if (amount > 0) apply(x['account']?.toString() ?? 'Cash', -amount);
    }

    for (final d in (await _c('salary').get()).docs) {
      final x = d.data();
      final amount = (x['amount'] as num?)?.toDouble() ?? 0;
      if (amount > 0) apply(x['account']?.toString() ?? 'Cash', -amount);
    }

    for (final d in (await _c('capital').get()).docs) {
      final x = d.data();
      final amount = (x['amount'] as num?)?.toDouble() ?? 0;
      final type = x['type']?.toString() ?? '';
      apply(x['account']?.toString() ?? 'Cash',
          type == 'Capital Received' ? amount : -amount);
    }

    return {'Cash': cash, 'Bank': bank};
  }
}
