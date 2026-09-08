import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetailCashService {
  RetailCashService._();
  static final instance = RetailCashService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _db.collection('sharedData').doc('dailyHisab').collection(name);

  Future<Map<String, double>> balances() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'Cash': 0, 'Bank': 0};
    final profile = (await _db.collection('users').doc(uid).get()).data() ?? {};
    final shopId = profile['shopId']?.toString() ?? '';
    if (shopId.isEmpty) return {'Cash': 0, 'Bank': 0};

    double cash = 0;
    double bank = 0;
    void apply(String account, double value) {
      if (account == 'Bank') {
        bank += value;
      } else {
        cash += value;
      }
    }

    final transactions = await _collection('transactions')
        .where('shopId', isEqualTo: shopId)
        .get();
    for (final d in transactions.docs) {
      final x = d.data();
      final amount = (x['amount'] as num?)?.toDouble() ?? 0;
      final type = x['type']?.toString() ?? '';
      final sign = type == 'Receipt'
          ? 1
          : (type == 'Payment' || type == 'Commission Payment')
              ? -1
              : 0;
      apply(x['account']?.toString() ?? 'Cash', amount * sign);
    }

    final sales = await _collection('sales')
        .where('shopId', isEqualTo: shopId)
        .get();
    for (final d in sales.docs) {
      final x = d.data();
      final amount = (x['paymentReceived'] as num?)?.toDouble() ?? 0;
      if (amount > 0) {
        apply(x['paymentAccount']?.toString() ?? 'Cash', amount);
      }
    }

    return {'Cash': cash, 'Bank': bank};
  }
}
