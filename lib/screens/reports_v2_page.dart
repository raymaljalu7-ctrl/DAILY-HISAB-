import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsV2Page extends StatefulWidget {
  const ReportsV2Page({super.key});
  @override
  State<ReportsV2Page> createState() => _ReportsV2PageState();
}

class _ReportsV2PageState extends State<ReportsV2Page> {
  final db = FirebaseFirestore.instance;
  final allTypes = const [
    'Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission',
    'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management',
    'Cash Management', 'Profit/Loss'
  ];
  String report = 'Sales';
  String period = 'Daily';
  String stockScope = 'All';
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();
  bool loading = true;
  bool retailUser = false;
  bool admin = false;
  String? assignedShopId;
  String? assignedShopName;
  String? shopId;
  String? productId;
  String? error;
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> products = [];

  List<String> get types {
    if (retailUser) {
      return const ['Sales', 'Outstanding', 'Commission', 'Stock Management', 'Cash Management'];
    }
    return admin ? allTypes : allTypes.where((x) => x != 'Profit/Loss').toList();
  }

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      db.collection('sharedData').doc('dailyHisab').collection(name);

  double number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  DateTime dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String dateText(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';

  String money(dynamic value) => '₹${number(value).toStringAsFixed(2)}';

  bool inRange(DateTime value) =>
      !value.isBefore(DateTime(from.year, from.month, from.day)) &&
      !value.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please login again.');
      final user = (await db.collection('users').doc(uid).get()).data() ?? {};
      retailUser = user['role'] == 'retail_shop_user';
      admin = user['role'] == 'admin';
      assignedShopId = user['shopId']?.toString();
      assignedShopName = user['shopName']?.toString();

      final productSnap = await collection('products').get();
      QuerySnapshot<Map<String, dynamic>>? shopSnap;
      if (!retailUser) shopSnap = await collection('retailShops').get();

      products = productSnap.docs
          .map((x) => <String, dynamic>{'id': x.id, ...x.data()})
          .where((x) => x['active'] != false)
          .toList();
      shops = shopSnap?.docs
              .map((x) => <String, dynamic>{'id': x.id, ...x.data()})
              .where((x) => x['active'] != false)
              .toList() ??
          [];
      if (!types.contains(report)) report = types.first;
      if (mounted) setState(() => loading = false);
      await _load();
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollection(
    String name, {
    String? shopField,
    String? shop,
  }) async {
    Query<Map<String, dynamic>> query = collection(name);
    if (retailUser && shopField != null && shop != null) {
      query = query.where(shopField, isEqualTo: shop);
    }
    final snap = await query.get();
    return snap.docs
        .map((x) => <String, dynamic>{'id': x.id, ...x.data()})
        .where((x) => inRange(dateValue(x['date'])))
        .toList();
  }

  void changePeriod(String value) {
    final now = DateTime.now();
    DateTime start = now;
    DateTime end = now;
    if (value == 'Monthly') {
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0);
    } else if (value == 'Quarterly') {
      final month = ((now.month - 1) ~/ 3) * 3 + 1;
      start = DateTime(now.year, month, 1);
      end = DateTime(now.year, month + 3, 0);
    } else if (value == '6 Monthly') {
      final month = now.month <= 6 ? 1 : 7;
      start = DateTime(now.year, month, 1);
      end = DateTime(now.year, month + 6, 0);
    } else if (value == 'Yearly') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, 12, 31);
    }
    setState(() {
      period = value;
      from = start;
      to = end;
    });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      if (!types.contains(report)) report = types.first;
      List<Map<String, dynamic>> result = [];

      if (report == 'Sales' || report == 'Outstanding' || report == 'Commission') {
        result = await fetchCollection('sales', shopField: 'shopId', shop: assignedShopId);
        if (!retailUser && shopId != null) {
          result = result.where((x) => x['shopId']?.toString() == shopId).toList();
        }
        if (productId != null) {
          result = result.where((x) {
            final items = x['items'];
            if (items is! List) return false;
            return items.any((item) => item is Map && item['productId']?.toString() == productId);
          }).toList();
        }
        if (report == 'Outstanding') {
          result = result.where((x) => number(x['outstanding']) > 0).toList();
        }
      } else if (report == 'Receipt' || report == 'Payments') {
        result = await fetchCollection('transactions');
        final type = report == 'Receipt' ? 'Receipt' : 'Payment';
        result = result.where((x) => x['type']?.toString() == type).toList();
      } else if (report == 'Production') {
        result = await fetchCollection('production');
      } else if (report == 'Expenses') {
        result = await fetchCollection('productionExpenses');
      } else if (report == 'Salary') {
        result = await fetchCollection('salary');
      } else if (report == 'Capital') {
        result = await fetchCollection('capital');
      } else if (report == 'Stock Management') {
        result = await _stockReport();
      } else if (report == 'Cash Management') {
        result = await _cashReport();
      } else if (report == 'Profit/Loss') {
        result = await _profitReport();
      }

      result.sort((a, b) => dateValue(b['date']).compareTo(dateValue(a['date'])));
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _stockReport() async {
    final transfers = await fetchCollection('stockTransfers', shopField: 'shopId', shop: assignedShopId);
    final received = await fetchCollection('stockOtherReceived', shopField: 'shopId', shop: assignedShopId);
    final sales = await fetchCollection('sales', shopField: 'shopId', shop: assignedShopId);
    final production = retailUser ? <Map<String, dynamic>>[] : await fetchCollection('production');
    final result = <Map<String, dynamic>>[];

    if (stockScope == 'Retail Shops' || stockScope == 'All') {
      final ids = retailUser ? [assignedShopId ?? ''] : shops.map((x) => x['id'].toString()).toList();
      for (final sid in ids) {
        final shop = shops.where((x) => x['id'].toString() == sid).toList();
        final shopName = retailUser
            ? (assignedShopName ?? 'Assigned Shop')
            : (shop.isEmpty ? sid : '${shop.first['name'] ?? sid}');
        for (final product in products) {
          final pid = product['id'].toString();
          final incoming = transfers.where((x) => x['shopId']?.toString() == sid && x['productId']?.toString() == pid).fold<double>(0, (sum, x) => sum + number(x['quantity']));
          final other = received.where((x) => x['shopId']?.toString() == sid && x['productId']?.toString() == pid).fold<double>(0, (sum, x) => sum + number(x['quantity']));
          double sold = 0;
          for (final sale in sales.where((x) => x['shopId']?.toString() == sid)) {
            final items = sale['items'];
            if (items is List) {
              for (final item in items) {
                if (item is Map && item['productId']?.toString() == pid) sold += number(item['quantity']);
              }
            }
          }
          result.add({'particular': '$shopName • ${product['name'] ?? pid}', 'location': shopName, 'productName': product['name'] ?? pid, 'quantity': incoming + other - sold});
        }
      }
    }

    if (!retailUser && (stockScope == 'Production Unit' || stockScope == 'All')) {
      for (final product in products) {
        final pid = product['id'].toString();
        final made = production.where((x) => x['productId']?.toString() == pid).fold<double>(0, (sum, x) => sum + number(x['quantity']));
        final moved = transfers.where((x) => x['productId']?.toString() == pid).fold<double>(0, (sum, x) => sum + number(x['quantity']));
        result.add({'particular': 'Production Unit • ${product['name'] ?? pid}', 'location': 'Production Unit', 'productName': product['name'] ?? pid, 'quantity': made - moved});
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _cashReport() async {
    final result = <Map<String, dynamic>>[];
    final transactions = await fetchCollection('transactions');
    final sales = await fetchCollection('sales', shopField: 'shopId', shop: assignedShopId);
    final salary = retailUser ? <Map<String, dynamic>>[] : await fetchCollection('salary');
    final expenses = retailUser ? <Map<String, dynamic>>[] : await fetchCollection('productionExpenses');
    final capital = retailUser ? <Map<String, dynamic>>[] : await fetchCollection('capital');

    for (final x in transactions) {
      result.add({'date': x['date'], 'particular': '${x['type'] ?? ''} - ${x['partyName'] ?? x['description'] ?? ''}', 'amount': number(x['amount']), 'account': x['paymentAccount'] ?? x['paymentMode'] ?? 'Cash'});
    }
    for (final x in sales) {
      if (number(x['paymentReceived']) > 0) {
        result.add({'date': x['date'], 'particular': 'Sales - ${x['shopName'] ?? assignedShopName ?? ''}', 'amount': number(x['paymentReceived']), 'account': x['paymentAccount'] ?? 'Cash'});
      }
    }
    for (final x in salary) result.add({'date': x['date'], 'particular': 'Salary - ${x['workerName'] ?? ''}', 'amount': number(x['amount']), 'account': x['paymentAccount'] ?? 'Cash'});
    for (final x in expenses) result.add({'date': x['date'], 'particular': 'Expense - ${x['head'] ?? x['name'] ?? ''}', 'amount': number(x['amount']), 'account': x['paymentAccount'] ?? 'Cash'});
    for (final x in capital) result.add({'date': x['date'], 'particular': 'Capital - ${x['type'] ?? ''}', 'amount': number(x['amount']), 'account': x['paymentAccount'] ?? 'Cash'});
    return result;
  }

  Future<List<Map<String, dynamic>>> _profitReport() async {
    final sales = await fetchCollection('sales');
    final expenses = await fetchCollection('productionExpenses');
    final salary = await fetchCollection('salary');
    final gross = sales.fold<double>(0, (sum, x) => sum + number(x['grossAmount']));
    final commission = sales.fold<double>(0, (sum, x) => sum + number(x['commission']));
    final expense = expenses.fold<double>(0, (sum, x) => sum + number(x['amount']));
    final wages = salary.fold<double>(0, (sum, x) => sum + number(x['amount']));
    return [
      {'particular': 'Gross Sales', 'amount': gross},
      {'particular': 'Commission', 'amount': commission},
      {'particular': 'Expenses', 'amount': expense},
      {'particular': 'Salary', 'amount': wages},
      {'particular': 'Profit / Loss', 'amount': gross - commission - expense - wages},
    ];
  }

  String particular(Map<String, dynamic> row) =>
      '${row['particular'] ?? row['shopName'] ?? row['productName'] ?? row['workerName'] ?? row['partyName'] ?? row['type'] ?? row['head'] ?? ''}';

  double amount(Map<String, dynamic> row) =>
      number(row['amount'] ?? row['netAmount'] ?? row['grossAmount'] ?? row['quantity']);

  double get total => rows.fold<double>(0, (sum, row) => sum + amount(row));

  Future<void> exportPdf() async {
    if (rows.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No report data to export.')));
      return;
    }
    await Printing.layoutPdf(onLayout: (format) async {
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Text('DAILY HISAB - $report REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Period: ${dateText(from)} to ${dateText(to)}'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Particular', 'Amount'],
              data: rows.map((x) => [dateText(dateValue(x['date'])), particular(x), amount(x).toStringAsFixed(2)]).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Total: Rs. ${total.toStringAsFixed(2)}')),
          ],
        ),
      );
      return document.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [IconButton(onPressed: loading ? null : exportPdf, icon: const Icon(Icons.picture_as_pdf))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: report,
            decoration: const InputDecoration(labelText: 'Report', border: OutlineInputBorder()),
            items: types.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (value) { if (value != null) { setState(() => report = value); _load(); } },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
            items: const ['Daily', 'Monthly', 'Quarterly', '6 Monthly', 'Yearly'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (value) { if (value != null) changePeriod(value); },
          ),
          if (report == 'Stock Management') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: stockScope,
              decoration: const InputDecoration(labelText: 'Stock Location', border: OutlineInputBorder()),
              items: (retailUser ? const ['Retail Shops'] : const ['Production Unit', 'Retail Shops', 'All']).map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (value) { if (value != null) { setState(() => stockScope = value); _load(); } },
            ),
          ],
          if (report == 'Sales' || report == 'Outstanding' || report == 'Commission') ...[
            if (!retailUser) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: shopId,
                decoration: const InputDecoration(labelText: 'Retail Shop', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All Retail Shops')),
                  ...shops.map((x) => DropdownMenuItem<String?>(value: x['id'].toString(), child: Text('${x['name'] ?? ''}'))),
                ],
                onChanged: (value) { setState(() => shopId = value); _load(); },
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: productId,
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All Products')),
                ...products.map((x) => DropdownMenuItem<String?>(value: x['id'].toString(), child: Text('${x['name'] ?? ''}'))),
              ],
              onChanged: (value) { setState(() => productId = value); _load(); },
            ),
          ],
          const SizedBox(height: 14),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (loading) const LinearProgressIndicator(),
          if (!loading && rows.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Text('No data found for selected period.', textAlign: TextAlign.center)),
          ...rows.map(
            (row) => Card(
              child: ListTile(
                title: Text(particular(row)),
                subtitle: Text(row['date'] == null ? '${row['location'] ?? ''}' : dateText(dateValue(row['date']))),
                trailing: Text(
                  report == 'Stock Management' ? '${amount(row).toStringAsFixed(2)} Box' : money(amount(row)),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('TOTAL: ${money(total)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
