import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardSummary {
  final double sales;
  final double paymentsReceived;
  final double paymentsMade;
  final double cashPaymentsMade;
  final double bankPaymentsMade;
  final double outstanding;
  final double commission;
  final double expenses;
  final double salary;
  final double capitalReceived;
  final double capitalReturned;
  final double productionBoxes;
  final double profitLoss;

  const DashboardSummary({
    this.sales = 0,
    this.paymentsReceived = 0,
    this.paymentsMade = 0,
    this.cashPaymentsMade = 0,
    this.bankPaymentsMade = 0,
    this.outstanding = 0,
    this.commission = 0,
    this.expenses = 0,
    this.salary = 0,
    this.capitalReceived = 0,
    this.capitalReturned = 0,
    this.productionBoxes = 0,
    this.profitLoss = 0,
  });
}

class DashboardService {
  DashboardService._();
  static final DashboardService instance = DashboardService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _db.collection('sharedData').doc('dailyHisab').collection(name);

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;

  bool _inRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _account(Map<String, dynamic> data) {
    final value = data['account'] ?? data['paymentAccount'] ?? data['paymentMode'] ?? data['mode'];
    return value?.toString().trim().toLowerCase() == 'bank' ? 'Bank' : 'Cash';
  }

  String _type(Map<String, dynamic> data) => (data['type'] ?? data['transactionType'] ?? '').toString().trim().toLowerCase();

  Future<DashboardSummary> calculate({required DateTime from, required DateTime to}) async {
    final salesSnapshot = await _collection('sales').get();
    final transactionSnapshot = await _collection('transactions').get();
    final expenseSnapshot = await _collection('productionExpenses').get();
    final salarySnapshot = await _collection('salary').get();
    final capitalSnapshot = await _collection('capital').get();
    final productionSnapshot = await _collection('production').get();

    double sales = 0;
    double paymentsReceived = 0;
    double paymentsMade = 0;
    double cashPaymentsMade = 0;
    double bankPaymentsMade = 0;
    double outstanding = 0;
    double commission = 0;
    double expenses = 0;
    double salary = 0;
    double capitalReceived = 0;
    double capitalReturned = 0;
    double productionBoxes = 0;

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      sales += _number(data['grossAmount']);
      paymentsReceived += _number(data['paymentReceived']);
      outstanding += _number(data['outstanding']);
      commission += _number(data['commission']);
    }

    for (final doc in transactionSnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      final type = _type(data);
      final amount = _number(data['amount']);
      final account = _account(data);

      if (type == 'receipt' || type == 'payment received' || type == 'money received') {
        paymentsReceived += amount;
      } else if (type == 'payment' || type == 'commission payment' || type == 'expense payment' || type == 'money paid') {
        paymentsMade += amount;
        if (account == 'Bank') {
          bankPaymentsMade += amount;
        } else {
          cashPaymentsMade += amount;
        }
      }
    }

    for (final doc in expenseSnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      expenses += _number(data['amount']);
    }
    for (final doc in salarySnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      salary += _number(data['amount']);
    }
    for (final doc in capitalSnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      final type = _type(data);
      final amount = _number(data['amount']);
      if (type == 'capital received') capitalReceived += amount;
      if (type == 'capital returned') capitalReturned += amount;
    }
    for (final doc in productionSnapshot.docs) {
      final data = doc.data();
      if (!_inRange(_date(data['date']), from, to)) continue;
      productionBoxes += _number(data['quantity']);
    }

    return DashboardSummary(
      sales: sales,
      paymentsReceived: paymentsReceived,
      paymentsMade: paymentsMade,
      cashPaymentsMade: cashPaymentsMade,
      bankPaymentsMade: bankPaymentsMade,
      outstanding: outstanding,
      commission: commission,
      expenses: expenses,
      salary: salary,
      capitalReceived: capitalReceived,
      capitalReturned: capitalReturned,
      productionBoxes: productionBoxes,
      profitLoss: sales - commission - expenses - salary,
    );
  }
}
