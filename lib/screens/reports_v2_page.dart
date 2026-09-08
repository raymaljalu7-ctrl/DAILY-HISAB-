import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsV2Page extends StatefulWidget {
  const ReportsV2Page({super.key});
  @override State<ReportsV2Page> createState() => _ReportsV2PageState();
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
  String? assignedShopId;
  String? assignedShopName;
  String? shopId;
  String? productId;
  String? partyId;
  String? error;
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> shops = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> parties = [];

  List<String> get types => retailUser
      ? const ['Sales', 'Receipt', 'Payments', 'Party Ledger', 'Expenses', 'Cash Management', 'Stock Management']
      : const ['Sales', 'Receipt', 'Payments', 'Outstanding', 'Commission', 'Production', 'Expenses', 'Salary', 'Capital', 'Stock Management', 'Cash Management', 'Profit/Loss'];

  CollectionReference<Map<String, dynamic>> _col(String name) => db.collection('sharedData').doc('dailyHisab').collection(name);
  double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _inRange(DateTime date) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _dateText(DateTime date) => '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  String _money(dynamic value) => '₹${_num(value).toStringAsFixed(2)}';

  @override
  void initState() { super.initState(); _initialize(); }

  Future<void> _initialize() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please login again.');
      final user = (await db.collection('users').doc(uid).get()).data() ?? {};
      retailUser = user['role'] == 'retail_shop_user';
      assignedShopId = user['shopId']?.toString();
      assignedShopName = user['shopName']?.toString();

      final productSnapshot = await _col('products').get();
      products = productSnapshot.docs.map((d) => {'id': d.id, ...d.data()}).where((x) => x['active'] != false).toList();
      final partySnapshot = await _col('parties').get();
      parties = partySnapshot.docs.map((d) => {'id': d.id, ...d.data()}).where((x) => x['active'] != false).toList()
        ..sort((a, b) => '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase()));
      if (!retailUser) {
        final shopSnapshot = await _col('retailShops').get();
        shops = shopSnapshot.docs.map((d) => {'id': d.id, ...d.data()}).where((x) => x['active'] != false).toList();
      }
      if (!types.contains(report)) report = types.first;
      await _load();
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(String name, {String? shop}) async {
    Query<Map<String, dynamic>> query = _col(name);
    if (retailUser && shop != null && shop.isNotEmpty) query = query.where('shopId', isEqualTo: shop);
    final snapshot = await query.get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).where((x) => _inRange(_date(x['date']))).toList();
  }

  void _changePeriod(String value) {
    final now = DateTime.now();
    DateTime start = now;
    DateTime end = now;
    if (value == 'Monthly') { start = DateTime(now.year, now.month, 1); end = DateTime(now.year, now.month + 1, 0); }
    else if (value == 'Quarterly') { final month = ((now.month - 1) ~/ 3) * 3 + 1; start = DateTime(now.year, month, 1); end = DateTime(now.year, month + 3, 0); }
    else if (value == '6 Monthly') { final month = now.month <= 6 ? 1 : 7; start = DateTime(now.year, month, 1); end = DateTime(now.year, month + 6, 0); }
    else if (value == 'Yearly') { start = DateTime(now.year, 1, 1); end = DateTime(now.year, 12, 31); }
    setState(() { period = value; from = start; to = end; });
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      List<Map<String, dynamic>> result = [];
      if (report == 'Sales' || report == 'Outstanding' || report == 'Commission') {
        result = await _fetch('sales', shop: assignedShopId);
        if (!retailUser && shopId != null && shopId!.isNotEmpty) result = result.where((x) => x['shopId']?.toString() == shopId).toList();
        if (productId != null && productId!.isNotEmpty) {
          result = result.where((x) {
            final items = x['items'];
            return items is List && items.any((item) => item is Map && item['productId']?.toString() == productId);
          }).toList();
        }
        if (report == 'Outstanding') result = result.where((x) => _num(x['outstanding']) > 0).toList();
      } else if (report == 'Receipt' || report == 'Payments' || report == 'Party Ledger') {
        result = await _fetch('transactions', shop: assignedShopId);
        if (report == 'Receipt') result = result.where((x) => x['type'] == 'Receipt').toList();
        if (report == 'Payments') result = result.where((x) => x['type'] == 'Payment').toList();
        if (partyId != null) result = result.where((x) => (x['partyId']?.toString() ?? '') == partyId).toList();
        else if (partyId == null && _partyFilterNone) result = result.where((x) => (x['partyId']?.toString() ?? '').isEmpty).toList();
        if (report == 'Party Ledger') {
          result = result.where((x) => (x['partyId']?.toString() ?? '').isNotEmpty).map((x) => {
            ...x,
            'signedAmount': x['type'] == 'Receipt' ? _num(x['amount']) : -_num(x['amount']),
          }).toList();
        }
      } else if (report == 'Expenses') {
        result = retailUser ? await _fetch('transactions', shop: assignedShopId) : await _fetch('productionExpenses');
        if (retailUser) result = result.where((x) => x['type'] == 'Payment' && x['subType'] == 'Expense').toList();
      } else if (report == 'Production') {
        result = await _fetch('production');
      } else if (report == 'Salary') {
        result = await _fetch('salary');
      } else if (report == 'Capital') {
        result = await _fetch('capital');
      } else if (report == 'Cash Management') {
        result = await _cash();
      } else if (report == 'Stock Management') {
        result = await _stock();
      } else if (report == 'Profit/Loss') {
        result = await _profit();
      }
      result.sort((a, b) => _date(b['date']).compareTo(_date(a['date'])));
      if (mounted) setState(() { rows = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = '$e'; loading = false; });
    }
  }

  bool _partyFilterNone = false;

  Future<List<Map<String, dynamic>>> _cash() async {
    final result = <Map<String, dynamic>>[];
    final transactions = await _fetch('transactions', shop: assignedShopId);
    final sales = await _fetch('sales', shop: assignedShopId);
    for (final row in transactions) {
      final value = _num(row['amount']);
      final type = row['type']?.toString() ?? '';
      final sign = type == 'Receipt' ? 1 : type == 'Payment' ? -1 : 0;
      result.add({'date': row['date'], 'particular': '$type • ${row['partyName'] ?? row['description'] ?? ''}', 'amount': value, 'signedAmount': value * sign});
    }
    for (final row in sales) {
      final value = _num(row['paymentReceived']);
      if (value > 0) result.add({'date': row['date'], 'particular': 'Sales • ${row['shopName'] ?? assignedShopName ?? ''}', 'amount': value, 'signedAmount': value});
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _stock() async {
    final result = <Map<String, dynamic>>[];
    final transfers = await _fetch('stockTransfers', shop: assignedShopId);
    final sales = await _fetch('sales', shop: assignedShopId);
    if (!retailUser && (stockScope == 'All' || stockScope == 'Production Unit')) {
      final production = await _fetch('production');
      for (final product in products) {
        final id = product['id'].toString();
        final made = production.where((x) => x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + _num(x['quantity']));
        final moved = transfers.where((x) => x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + _num(x['quantity']));
        result.add({'date': DateTime.now(), 'particular': 'Production Unit • ${product['name'] ?? id}', 'quantity': made - moved});
      }
    }
    if (stockScope == 'All' || stockScope == 'Retail Shops') {
      final ids = retailUser ? [assignedShopId ?? ''] : shops.map((x) => x['id'].toString()).toList();
      for (final sid in ids) {
        for (final product in products) {
          final id = product['id'].toString();
          final incoming = transfers.where((x) => x['shopId']?.toString() == sid && x['productId']?.toString() == id).fold<double>(0, (sum, x) => sum + _num(x['quantity']));
          double sold = 0;
          for (final sale in sales.where((x) => x['shopId']?.toString() == sid)) {
            final items = sale['items'];
            if (items is List) for (final item in items) if (item is Map && item['productId']?.toString() == id) sold += _num(item['quantity']);
          }
          final shopName = retailUser ? (assignedShopName ?? 'Retail Shop') : (shops.firstWhere((x) => x['id'].toString() == sid, orElse: () => {'name': sid})['name'] ?? sid);
          result.add({'date': DateTime.now(), 'particular': '$shopName • ${product['name'] ?? id}', 'quantity': incoming - sold});
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _profit() async {
    final sales = await _fetch('sales');
    final expenses = await _fetch('productionExpenses');
    final salaries = await _fetch('salary');
    final gross = sales.fold<double>(0, (sum, x) => sum + _num(x['grossAmount']));
    final commission = sales.fold<double>(0, (sum, x) => sum + _num(x['commission']));
    final expense = expenses.fold<double>(0, (sum, x) => sum + _num(x['amount']));
    final salary = salaries.fold<double>(0, (sum, x) => sum + _num(x['amount']));
    return [
      {'date': DateTime.now(), 'particular': 'Gross Sales', 'amount': gross},
      {'date': DateTime.now(), 'particular': 'Commission', 'amount': commission},
      {'date': DateTime.now(), 'particular': 'Expenses', 'amount': expense},
      {'date': DateTime.now(), 'particular': 'Salary', 'amount': salary},
      {'date': DateTime.now(), 'particular': 'Profit / Loss', 'amount': gross - commission - expense - salary},
    ];
  }

  String _particular(Map<String, dynamic> row) => '${row['particular'] ?? row['partyName'] ?? row['productName'] ?? row['workerName'] ?? row['type'] ?? ''}';
  double _amount(Map<String, dynamic> row) => _num(row['signedAmount'] ?? row['amount'] ?? row['grossAmount'] ?? row['netAmount'] ?? row['quantity']);
  double get _total => rows.fold<double>(0, (sum, row) => sum + _amount(row));

  Future<void> _exportPdf() async {
    if (rows.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No report data to export.')));
      return;
    }
    await Printing.layoutPdf(onLayout: (format) async {
      final document = pw.Document();
      document.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (context) => [
        pw.Text('DAILY HISAB - $report REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Period: ${_dateText(from)} to ${_dateText(to)}'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(headers: const ['Date', 'Particular', 'Amount'], data: rows.map((row) => [_dateText(_date(row['date'])), _particular(row), _amount(row).toStringAsFixed(2)]).toList()),
        pw.SizedBox(height: 10),
        pw.Text('Total: ${_total.toStringAsFixed(2)}'),
      ]));
      return document.save();
    });
  }

  Widget _partyFilter() {
    final entries = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__NONE__', child: Text('None')),
      ...parties.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name']?.toString() ?? x['id'].toString()))),
    ];
    final value = _partyFilterNone ? '__NONE__' : (partyId ?? '');
    if (value == '') entries.insert(0, const DropdownMenuItem(value: '', child: Text('All Parties')));
    return Column(children: [
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Party', border: OutlineInputBorder()),
        items: entries,
        onChanged: (value) {
          setState(() {
            _partyFilterNone = value == '__NONE__';
            partyId = (value == null || value.isEmpty || value == '__NONE__') ? null : value;
          });
          _load();
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports'), actions: [IconButton(onPressed: loading ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf))]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(initialValue: report, decoration: const InputDecoration(labelText: 'Report', border: OutlineInputBorder()), items: types.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (value) { if (value != null) { setState(() { report = value; partyId = null; _partyFilterNone = false; }); _load(); } }),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: period, decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()), items: const ['Daily', 'Monthly', 'Quarterly', '6 Monthly', 'Yearly'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (value) { if (value != null) _changePeriod(value); }),
          if (!retailUser && report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: shopId ?? '', decoration: const InputDecoration(labelText: 'Retail Shop', border: OutlineInputBorder()), items: [const DropdownMenuItem(value: '', child: Text('All Shops')), ...shops.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name']?.toString() ?? x['id'].toString())))], onChanged: (value) { setState(() => shopId = (value ?? '').isEmpty ? null : value); _load(); }),
          ],
          if (report == 'Sales') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: productId ?? '', decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()), items: [const DropdownMenuItem(value: '', child: Text('All Products')), ...products.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['name']?.toString() ?? x['id'].toString())))], onChanged: (value) { setState(() => productId = (value ?? '').isEmpty ? null : value); _load(); }),
          ],
          if (report == 'Receipt' || report == 'Payments' || report == 'Party Ledger') _partyFilter(),
          if (report == 'Stock Management' && !retailUser) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: stockScope, decoration: const InputDecoration(labelText: 'Stock Location', border: OutlineInputBorder()), items: const ['All', 'Production Unit', 'Retail Shops'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (value) { if (value != null) { setState(() => stockScope = value); _load(); } }),
          ],
          const SizedBox(height: 14),
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (loading) const Center(child: CircularProgressIndicator())
          else if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No data for selected period.'))
          else Card(child: Column(children: [
            ListTile(title: Text('$report Report', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text('Total ${_money(_total)}')),
            const Divider(height: 1),
            ...rows.take(100).map((row) => ListTile(dense: true, title: Text(_particular(row)), subtitle: Text(_dateText(_date(row['date']))), trailing: Text(_money(_amount(row))))),
          ])),
        ],
      ),
    );
  }
}
