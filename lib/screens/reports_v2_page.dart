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
      return const ['Sales', 'Receipt', 'Payments', 'Party Ledger', 'Expenses', 'Cash Management', 'Stock Management'];
    }
    if (admin) {
      return const ['Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission', 'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management', 'Cash Management', 'Profit/Loss'];
    }
    return const ['Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission', 'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management', 'Cash Management'];
  }

  CollectionReference<Map<String, dynamic>> col(String name) {
    return db.collection('sharedData').doc('dailyHisab').collection(name);
  }

  double numVal(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  DateTime dateVal(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool inRange(DateTime date) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String money(dynamic value) => '₹${numVal(value).toStringAsFixed(2)}';

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

      final productSnapshot = await col('products').get();
      products = productSnapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((x) => x['active'] != false)
          .toList();

      if (!retailUser) {
        final shopSnapshot = await col('retailShops').get();
        shops = shopSnapshot.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((x) => x['active'] != false)
            .toList();
      }

      if (!types.contains(report)) report = types.first;
      await _load();
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> fetch(String name, {String? shop}) async {
    Query<Map<String, dynamic>> query = col(name);
    if (retailUser && shop != null && shop.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shop);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((x) => inRange(dateVal(x['date'])))
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
    setState(() { period = value; from = start; to = end; });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      List<Map<String, dynamic>> result = [];
      if (report == 'Sales' || report == 'Outstanding' || report == 'Commission') {
        result = await fetch('sales', shop: assignedShopId);
        if (!retailUser && shopId != null && shopId!.isNotEmpty) {
          result = result.where((x) => x['shopId']?.toString() == shopId).toList();
        }
        if (productId != null && productId!.isNotEmpty) {
          result = result.where((x) {
            final items = x['items'];
            return items is List && items.any((item) => item is Map && item['productId']?.toString() == productId);
          }).toList();
        }
        if (report == 'Outstanding') {
          result = result.where((x) => numVal(x['outstanding']) > 0).toList();
        }
      } else if (report == 'Receipt' || report == 'Payments') {
        result = await fetch('transactions', shop: assignedShopId);
        final wanted = report == 'Receipt' ? 'Receipt' : 'Payment';
        result = result.where((x) => x['type']?.toString() == wanted).toList();
      } else if (report == 'Party Ledger') {
        result = await fetch('transactions', shop: assignedShopId);
        result = result.where((x) => (x['partyId']?.toString() ?? '').isNotEmpty).map((x) {
          return {...x, 'signedAmount': x['type'] == 'Receipt' ? numVal(x['amount']) : -numVal(x['amount'])};
        }).toList();
      } else if (report == 'Expenses') {
        result = retailUser ? await fetch('transactions', shop: assignedShopId) : await fetch('productionExpenses');
        if (retailUser) {
          result = result.where((x) => x['type'] == 'Payment' && x['subType'] == 'Expense').toList();
        }
      } else if (report == 'Production') {
        result = await fetch('production');
      } else if (report == 'Salary') {
        result = await fetch('salary');
      } else if (report == 'Capital') {
        result = await fetch('capital');
      } else if (report == 'Stock Management') {
        result = await _stock();
      } else if (report == 'Cash Management') {
        result = await _cash();
      } else if (report == 'Profit/Loss') {
        result = await _profit();
      }
      result.sort((a, b) => dateVal(b['date']).compareTo(dateVal(a['date'])));
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _stock() async {
    final result = <Map<String, dynamic>>[];
    final transfers = await fetch('stockTransfers', shop: assignedShopId);
    final sales = await fetch('sales', shop: assignedShopId);
    final production = retailUser ? <Map<String, dynamic>>[] : await fetch('production');

    if (!retailUser && (stockScope == 'Production Unit' || stockScope == 'All')) {
      for (final product in products) {
        final id = product['id'].toString();
        final made = production.where((x) => x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + numVal(x['quantity']));
        final moved = transfers.where((x) => x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + numVal(x['quantity']));
        result.add({'date': DateTime.now(), 'particular': 'Production Unit • ${product['name'] ?? id}', 'quantity': made - moved});
      }
    }

    if (stockScope == 'Retail Shops' || stockScope == 'All') {
      final ids = retailUser ? [assignedShopId ?? ''] : shops.map((x) => x['id'].toString()).toList();
      for (final sid in ids) {
        for (final product in products) {
          final id = product['id'].toString();
          final incoming = transfers.where((x) => x['shopId']?.toString() == sid && x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + numVal(x['quantity']));
          double sold = 0;
          for (final sale in sales.where((x) => x['shopId']?.toString() == sid)) {
            final items = sale['items'];
            if (items is List) {
              for (final item in items) {
                if (item is Map && item['productId']?.toString() == id) sold += numVal(item['quantity']);
              }
            }
          }
          final shop = retailUser ? (assignedShopName ?? 'Retail Shop') : (shops.firstWhere((x) => x['id'].toString() == sid, orElse: () => {'name': sid})['name'] ?? sid);
          result.add({'date': DateTime.now(), 'particular': '$shop • ${product['name'] ?? id}', 'quantity': incoming - sold});
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _cash() async {
    final result = <Map<String, dynamic>>[];
    final transactions = await fetch('transactions', shop: assignedShopId);
    final sales = await fetch('sales', shop: assignedShopId);
    for (final item in transactions) {
      final amount = numVal(item['amount']);
      final type = item['type']?.toString() ?? '';
      final sign = type == 'Receipt' ? 1 : ((type == 'Payment' || type == 'Commission Payment') ? -1 : 0);
      result.add({'date': item['date'], 'particular': '$type • ${item['partyName'] ?? item['description'] ?? ''}', 'amount': amount, 'signedAmount': amount * sign, 'account': item['account'] ?? item['paymentAccount'] ?? item['paymentMode'] ?? 'Cash'});
    }
    for (final item in sales) {
      final amount = numVal(item['paymentReceived']);
      if (amount > 0) result.add({'date': item['date'], 'particular': 'Sales • ${item['shopName'] ?? assignedShopName ?? ''}', 'amount': amount, 'signedAmount': amount, 'account': item['paymentAccount'] ?? item['paymentMode'] ?? 'Cash'});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _profit() async {
    final sales = await fetch('sales');
    final expenses = await fetch('productionExpenses');
    final salaries = await fetch('salary');
    final gross = sales.fold<double>(0, (sum, x) => sum + numVal(x['grossAmount']));
    final commission = sales.fold<double>(0, (sum, x) => sum + numVal(x['commission']));
    final expense = expenses.fold<double>(0, (sum, x) => sum + numVal(x['amount']));
    final salary = salaries.fold<double>(0, (sum, x) => sum + numVal(x['amount']));
    return [
      {'date': DateTime.now(), 'particular': 'Gross Sales', 'amount': gross},
      {'date': DateTime.now(), 'particular': 'Commission', 'amount': commission},
      {'date': DateTime.now(), 'particular': 'Expenses', 'amount': expense},
      {'date': DateTime.now(), 'particular': 'Salary', 'amount': salary},
      {'date': DateTime.now(), 'particular': 'Profit / Loss', 'amount': gross - commission - expense - salary},
    ];
  }

  String particular(Map<String, dynamic> item) => '${item['particular'] ?? item['partyName'] ?? item['productName'] ?? item['workerName'] ?? item['type'] ?? ''}';

  double amount(Map<String, dynamic> item) => numVal(item['signedAmount'] ?? item['amount'] ?? item['grossAmount'] ?? item['netAmount'] ?? item['quantity']);

  double get total => rows.fold<double>(0, (sum, item) => sum + amount(item));

  Future<void> exportPdf() async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No report data to export.')));
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
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Particular', 'Amount'],
              data: rows.map((x) => [dateText(dateVal(x['date'])), particular(x), amount(x).toStringAsFixed(2)]).toList(),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Total: ${total.toStringAsFixed(2)}'),
          ],
        ),
      );
      return document.save();
    });
  }

  Widget _dropdown(String label, String value, List<String> values, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
      onChanged: onChanged,
    );
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
          _dropdown('Report', report, types, (value) {
            if (value != null) {
              setState(() => report = value);
              _load();
            }
          }),
          const SizedBox(height: 10),
          _dropdown('Period', period, const ['Daily', 'Monthly', 'Quarterly', '6 Monthly', 'Yearly'], (value) {
            if (value != null) changePeriod(value);
          }),
          if (!retailUser && report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: shopId ?? '',
              decoration: const InputDecoration(labelText: 'Retail Shop', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Shops')),
                ...shops.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name']?.toString() ?? x['id'].toString()))),
              ],
              onChanged: (value) {
                setState(() => shopId = (value ?? '').isEmpty ? null : value);
                _load();
              },
            ),
          ],
          if (report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: productId ?? '',
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Products')),
                ...products.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name']?.toString() ?? x['id'].toString()))),
              ],
              onChanged: (value) {
                setState(() => productId = (value ?? '').isEmpty ? null : value);
                _load();
              },
            ),
          ],
          if (report == 'Stock Management' && !retailUser) ...[
            const SizedBox(height: 10),
            _dropdown('Stock Location', stockScope, const ['All', 'Production Unit', 'Retail Shops'], (value) {
              if (value != null) {
                setState(() => stockScope = value);
                _load();
              }
            }),
          ],
          const SizedBox(height: 14),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (rows.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Text('No data for selected period.'))
          else
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('$report Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('Total ${money(total)}'),
                  ),
                  const Divider(height: 1),
                  ...rows.take(100).map((item) => ListTile(
                    dense: true,
                    title: Text(particular(item)),
                    subtitle: Text(dateText(dateVal(item['date']))),
                    trailing: Text(money(amount(item))),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
