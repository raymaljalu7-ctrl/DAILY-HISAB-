import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardSummary {
  final double sales;
  final double paymentsReceived;
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

  CollectionReference<Map<String, dynamic>> _collection(
    String name,
  ) {
    return _db
        .collection('sharedData')
        .doc('dailyHisab')
        .collection(name);
  }

  DateTime _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _inRange(
    DateTime date,
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(
      from.year,
      from.month,
      from.day,
    );

    final end = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
      999,
    );

    return !date.isBefore(start) && !date.isAfter(end);
  }

  Future<DashboardSummary> calculate({
    required DateTime from,
    required DateTime to,
  }) async {
    final salesSnapshot = await _collection('sales').get();
    final transactionSnapshot =
        await _collection('transactions').get();
    final expenseSnapshot =
        await _collection('productionExpenses').get();
    final salarySnapshot =
        await _collection('salary').get();
    final capitalSnapshot =
        await _collection('capital').get();
    final productionSnapshot =
        await _collection('production').get();

    double sales = 0;
    double paymentsReceived = 0;
    double outstanding = 0;
    double commission = 0;
    double expenses = 0;
    double salary = 0;
    double capitalReceived = 0;
    double capitalReturned = 0;
    double productionBoxes = 0;

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      sales +=
          (data['grossAmount'] as num?)?.toDouble() ?? 0;

      paymentsReceived +=
          (data['paymentReceived'] as num?)?.toDouble() ?? 0;

      outstanding +=
          (data['outstanding'] as num?)?.toDouble() ?? 0;

      commission +=
          (data['commission'] as num?)?.toDouble() ?? 0;
    }

    for (final doc in transactionSnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      final type = data['type']?.toString() ?? '';
      final amount =
          (data['amount'] as num?)?.toDouble() ?? 0;

      if (type == 'Receipt') {
        paymentsReceived += amount;
      }
    }

    for (final doc in expenseSnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      expenses +=
          (data['amount'] as num?)?.toDouble() ?? 0;
    }

    for (final doc in salarySnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      salary +=
          (data['amount'] as num?)?.toDouble() ?? 0;
    }

    for (final doc in capitalSnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      final type = data['type']?.toString() ?? '';
      final amount =
          (data['amount'] as num?)?.toDouble() ?? 0;

      if (type == 'Capital Received') {
        capitalReceived += amount;
      } else if (type == 'Capital Returned') {
        capitalReturned += amount;
      }
    }

    for (final doc in productionSnapshot.docs) {
      final data = doc.data();
      final date = _date(data['date']);

      if (!_inRange(date, from, to)) {
        continue;
      }

      productionBoxes +=
          (data['quantity'] as num?)?.toDouble() ?? 0;
    }

    final profitLoss =
        sales - commission - expenses - salary;

    return DashboardSummary(
      sales: sales,
      paymentsReceived: paymentsReceived,
      outstanding: outstanding,
      commission: commission,
      expenses: expenses,
      salary: salary,
      capitalReceived: capitalReceived,
      capitalReturned: capitalReturned,
      productionBoxes: productionBoxes,
      profitLoss: profitLoss,
    );
  }
}
