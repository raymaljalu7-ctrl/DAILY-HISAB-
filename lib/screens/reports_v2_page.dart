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
      return const [
        'Sales', 'Receipt', 'Payments', 'Party Ledger', 'Expenses',
        'Cash Management', 'Stock Management'
      ];
    }
    if (admin) {
      return const [
        'Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission',
        'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management',
        'Cash Management', 'Profit/Loss'
      ];
    }
    return const [
      'Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission',
      'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management',
      'Cash Management'
    ];
  }

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return db.collection('sharedData').doc('dailyHisab').collection(name);
  }

  double number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  DateTime dateValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool inRange(DateTime value) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return !value.isBefore(start) && !value.isAfter(end);
  }

  String dateText(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}';
  }

  String money(dynamic value) => '₹${number(value).toStringAsFixed(2)}';

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

      final productSnapshot = await collection('products').get();
      products = productSnapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((x) => x['active'] != false)
          .toList();

      if (!retailUser) {
        final shopSnapshot = await collection('retailShops').get();
        shops = shopSnapshot.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((x) => x['active'] != false)
            .toList();
      }

      if (!types.contains(report)) report = types.first;
      if (mounted) setState(() => loading = false);
      await _load();
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollection(
    String name, {
    String? shop,
  }) async {
    Query<Map<String, dynamic>> query = collection(name);
    if (retailUser && shop != null && shop.isNotEmpty) {
      query = query.where('shopId', isEqualTo: shop);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => {'id': d.id, ...d.data()})
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
      List<Map<String, dynamic>> result = [];

      if (report == 'Sales' || report == 'Outstanding' || report == 'Commission') {
        result = await fetchCollection('sales', shop: assignedShopId);
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
        result = await fetchCollection('transactions', shop: assignedShopId);
        final wanted = report == 'Receipt' ? 'Receipt' : 'Payment';
        result = result.where((x) => x['type']?.toString() == wanted).toList();
      } else if (report == 'Party Ledger') {
        result = await fetchCollection('transactions', shop: assignedShopId);
        result = result
            .where((x) => (x['partyId']?.toString() ?? '').isNotEmpty)
            .map((x) => {
                  ...x,
                  'signedAmount': x['type'] == 'Receipt'
                      ? number(x['amount'])
                      : -number(x['amount']),
                })
            .toList();
      } else if (report == 'Expenses') {
        result = await fetchCollection(
          retailUser ? 'transactions' : 'productionExpenses',
          shop: assignedShopId,
        );
        if (retailUser) {
          result = result
              .where((x) => x['type'] == 'Payment' && x['subType'] == 'Expense')
              .toList();
        }
      } else if (report == 'Production') {
        result = await fetchCollection('production');
      } else if (report == 'Salary') {
        result = await fetchCollection('salary');
      } else if (report == 'Capital') {
        result = await fetchCollection('capital');
      } else if (report == 'Cash Management') {
        result = await _cash();
      } else if (report == 'Stock Management') {
        result = await _stock();
      } else if (report == 'Profit/Loss') {
        result = await _profit();
      }

      result.sort((a, b) => dateValue(b['date']).compareTo(dateValue(a['date'])));
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _cash() async {
    final result = <Map<String, dynamic>>[];
    final transactions = await fetchCollection('transactions', shop: assignedShopId);
    final sales = await fetchCollection('sales', shop: assignedShopId);

    for (final item in transactions) {
      final amount = number(item['amount']);
      final type = item['type']?.toString() ?? '';
      final sign = type == 'Receipt' ? 1 : (type == 'Payment' || type == 'Commission Payment' ? -1 : 0);
      result.add({
        'date': item['date'],
        'particular': '$type • ${item['partyName'] ?? item['description'] ?? ''}',
        'amount': amount,
        'signedAmount': amount * sign,
        'account': item['account'] ?? item['paymentAccount'] ?? item['paymentMode'] ?? 'Cash',
      });
    }

    for (final item in sales) {
      final amount = number(item['paymentReceived']);
      if (amount > 0) {
        result.add({
          'date': item['date'],
          'particular': 'Sales • ${item['shopName'] ?? assignedShopName ?? ''}',
          'amount': amount,
          'signedAmount': amount,
          'account': item['account'] ?? item['paymentAccount'] ?? item['paymentMode'] ?? 'Cash',
        });
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _stock() async {
    final result = <Map<String, dynamic>>[];
    final transfers = await fetchCollection('stockTransfers', shop: assignedShopId);
    final sales = await fetchCollection('sales', shop: assignedShopId);

    for (final product in products) {
      final productKey = product['id'].toString();
      final incoming = transfers
          .where((x) => x['productId']?.toString() == productKey)
          .fold<double>(0, (sum, x) => sum + number(x['quantity']));
      double sold = 0;
      for (final sale in sales) {
        final items = sale['items'];
        if (items is List) {
          for (final item in items) {
            if (item is Map && item['productId']?.toString() == productKey) {
              sold += number(item['quantity']);
            }
          }
        }
      }
      result.add({
        'date': DateTime.now(),
        'particular': '${retailUser ? (assignedShopName ?? 'Shop') : 'Stock'} • ${product['name'] ?? productKey}',
        'quantity': incoming - sold,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _profit() async {
    final sales = await fetchCollection('sales');
    final expenses = await fetchCollection('productionExpenses');
    final salary = await fetchCollection('salary');
    final gross = sales.fold<double>(0, (sum, x) => sum + number(x['grossAmount']));
    final commission = sales.fold<double>(0, (sum, x) => sum + number(x['commission']));
    final expense = expenses.fold<double>(0, (sum, x) => sum + number(x['amount']));
    final salaries = salary.fold<double>(0, (sum, x) => sum + number(x['amount']));
    return [
      {'particular': 'Gross Sales', 'amount': gross, 'date': DateTime.now()},
      {'particular': 'Commission', 'amount': commission, 'date': DateTime.now()},
      {'particular': 'Expenses', 'amount': expense, 'date': DateTime.now()},
      {'particular': 'Salary', 'amount': salaries, 'date': DateTime.now()},
      {'particular': 'Profit / Loss', 'amount': gross - commission - expense - salaries, 'date': DateTime.now()},
    ];
  }

  String particular(Map<String, dynamic> item) {
    return '${item['particular'] ?? item['partyName'] ?? item['productName'] ?? item['type'] ?? ''}';
  }

  double amount(Map<String, dynamic> item) {
    return number(item['signedAmount'] ?? item['amount'] ?? item['grossAmount'] ?? item['netAmount'] ?? item['quantity']);
  }

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
              data: rows.map((item) => [
                dateText(dateValue(item['date'])),
                particular(item),
                amount(item).toStringAsFixed(2),
              ]).toList(),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Total: ${total.toStringAsFixed(2)}'),
          ],
        ),
      );
      return document.save();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportItems = types.map((x) => DropdownMenuItem<String>(value: x, child: Text(x))).toList();
    final periodItems = const ['Daily', 'Monthly', 'Quarterly', '6 Monthly', 'Yearly']
        .map((x) => DropdownMenuItem<String>(value: x, child: Text(x)))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            onPressed: loading ? null : exportPdf,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: report,
            decoration: const InputDecoration(labelText: 'Report', border: OutlineInputBorder()),
            items: reportItems,
            onChanged: (value) {
              if (value == null) return;
              setState(() => report = value);
              _load();
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
            items: periodItems,
            onChanged: (value) {
              if (value != null) changePeriod(value);
            },
          ),
          if (!retailUser && report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: shopId,
              decoration: const InputDecoration(labelText: 'Retail Shop', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Shops')),
                ...shops.map((shop) => DropdownMenuItem<String>(
                      value: shop['id'].toString(),
                      child: Text(shop['name']?.toString() ?? shop['id'].toString()),
                    )),
              ],
              onChanged: (value) {
                setState(() => shopId = value);
                _load();
              },
            ),
          ],
          if (report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: productId,
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Products')),
                ...products.map((product) => DropdownMenuItem<String>(
                      value: product['id'].toString(),
                      child: Text(product['name']?.toString() ?? product['id'].toString()),
                    )),
              ],
              onChanged: (value) {
                setState(() => productId = value);
                _load();
              },
            ),
          ],
          const SizedBox(height: 14),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No data for selected period.'),
            )
          else
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text('$report Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text('Total ${money(total)}'),
                  ),
                  const Divider(height: 1),
                  ...rows.take(100).map(
                    (item) => ListTile(
                      dense: true,
                      title: Text(particular(item)),
                      subtitle: Text(dateText(dateValue(item['date']))),
                      trailing: Text(money(amount(item))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
