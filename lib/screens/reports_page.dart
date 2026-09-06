import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/report_service.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportService _service = ReportService.instance;

  String _reportType = 'Sales';
  String _periodType = 'Daily';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String? _shopId;
  String? _productId;
  String? _workerId;
  String? _assignedShopId;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _workers = [];

  final _reportTypes = const [
    'Sales', 'Payments', 'Outstanding', 'Commission', 'Production',
    'Expenses', 'Salary', 'Capital', 'Profit/Loss',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadMasters();
    await _loadAssignedShop();
    if (mounted) await _loadReport();
  }

  Future<void> _loadAssignedShop() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data() ?? <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _assignedShopId = data['role']?.toString() == 'retail_shop_user'
          ? data['shopId']?.toString()
          : null;
      if (_assignedShopId != null && _assignedShopId!.isNotEmpty) {
        _shopId = _assignedShopId;
      }
    });
  }

  Future<void> _loadMasters() async {
    try {
      final root = FirebaseFirestore.instance.collection('sharedData').doc('dailyHisab');
      final results = await Future.wait([
        root.collection('retailShops').get(),
        root.collection('products').get(),
        root.collection('workers').get(),
      ]);
      if (!mounted) return;
      setState(() {
        _shops = results[0].docs.map((d) => {'id': d.id, ...d.data()}).where((e) => e['active'] != false).toList();
        _products = results[1].docs.map((d) => {'id': d.id, ...d.data()}).where((e) => e['active'] != false).toList();
        _workers = results[2].docs.map((d) => {'id': d.id, ...d.data()}).where((e) => e['active'] != false).toList();
      });
    } catch (_) {}
  }

  DateTime get _start => DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
  DateTime get _end => DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59, 999);

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(dynamic value) => '₹${_number(value).toStringAsFixed(2)}';

  String _dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  void _setPeriod(String value) {
    final now = DateTime.now();
    DateTime from = now;
    DateTime to = now;
    switch (value) {
      case 'Daily':
        from = DateTime(now.year, now.month, now.day);
        to = from;
        break;
      case 'Monthly':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case 'Quarterly':
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        from = DateTime(now.year, quarterStartMonth, 1);
        to = DateTime(now.year, quarterStartMonth + 3, 0);
        break;
      case '6 Monthly':
        final halfStartMonth = now.month <= 6 ? 1 : 7;
        from = DateTime(now.year, halfStartMonth, 1);
        to = DateTime(now.year, halfStartMonth + 6, 0);
        break;
      case 'Yearly':
        from = DateTime(now.year, 1, 1);
        to = DateTime(now.year, 12, 31);
        break;
      case 'Date Range':
        from = _fromDate;
        to = _toDate;
        break;
    }
    setState(() {
      _periodType = value;
      _fromDate = from;
      _toDate = to;
    });
    _loadReport();
  }

  Future<void> _pickDate(bool from) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: from ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (from) {
        _fromDate = selected;
        if (_toDate.isBefore(selected)) _toDate = selected;
      } else {
        _toDate = selected;
        if (_fromDate.isAfter(selected)) _fromDate = selected;
      }
      _periodType = 'Date Range';
    });
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      List<Map<String, dynamic>> result;
      final effectiveShop = _assignedShopId ?? _shopId;
      switch (_reportType) {
        case 'Sales':
          result = await _service.sales(from: _start, to: _end, shopId: effectiveShop, productId: _productId);
          break;
        case 'Payments':
          result = await _service.transactions(from: _start, to: _end, type: 'Receipt', shopId: effectiveShop);
          break;
        case 'Outstanding':
          result = (await _service.sales(from: _start, to: _end, shopId: effectiveShop, productId: _productId))
              .where((r) => _number(r['outstanding']) > 0).toList();
          break;
        case 'Commission':
          result = await _service.commissions(from: _start, to: _end, shopId: effectiveShop);
          break;
        case 'Production':
          result = await _service.production(from: _start, to: _end, productId: _productId);
          break;
        case 'Expenses':
          result = await _service.expenses(from: _start, to: _end);
          break;
        case 'Salary':
          result = await _service.salary(from: _start, to: _end, workerId: _workerId);
          break;
        case 'Capital':
          result = await _service.capital(from: _start, to: _end);
          break;
        case 'Profit/Loss':
          result = await _profitLoss();
          break;
        default:
          result = [];
      }
      if (!mounted) return;
      setState(() { _rows = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<List<Map<String, dynamic>>> _profitLoss() async {
    final shop = _assignedShopId ?? _shopId;
    final sales = await _service.sales(from: _start, to: _end, shopId: shop);
    final expenses = await _service.expenses(from: _start, to: _end);
    final salary = await _service.salary(from: _start, to: _end, workerId: _workerId);
    final gross = sales.fold<double>(0, (s, r) => s + _number(r['grossAmount'] ?? r['amount']));
    final commission = sales.fold<double>(0, (s, r) => s + _number(r['commission']));
    final exp = expenses.fold<double>(0, (s, r) => s + _number(r['amount']));
    final sal = salary.fold<double>(0, (s, r) => s + _number(r['amount']));
    return [
      {'Particular': 'Gross Sales', 'Amount': gross},
      {'Particular': 'Commission', 'Amount': commission},
      {'Particular': 'Expenses', 'Amount': exp},
      {'Particular': 'Salary', 'Amount': sal},
      {'Particular': 'Profit / Loss', 'Amount': gross - commission - exp - sal},
    ];
  }

  String _title() => _reportType == 'Profit/Loss' ? 'Profit / Loss' : _reportType;

  double _rowAmount(Map<String, dynamic> row) {
    return _number(row['amount'] ?? row['grossAmount'] ?? row['netAmount'] ?? row['total'] ?? row['Amount']);
  }

  Future<void> _downloadPdf() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generate a report before downloading PDF.')));
      return;
    }
    try {
      await Printing.layoutPdf(onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) => [
            pw.Text('DAILY HISAB', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text('${_title()} Report'),
            pw.Text('Period: ${_dateText(_fromDate)} to ${_dateText(_toDate)}'),
            if ((_assignedShopId ?? '').isNotEmpty) pw.Text('Retail Shop: ${_shops.firstWhere((s) => s['id']?.toString() == _assignedShopId, orElse: () => {'name': 'Assigned Shop'})['name']}'),
            pw.SizedBox(height: 14),
            pw.Table.fromTextArray(
              headers: const ['Date', 'Particular', 'Amount (Rs.)'],
              data: _rows.map((row) => [
                _dateForPdf(row['date']),
                (row['shopName'] ?? row['productName'] ?? row['workerName'] ?? row['Particular'] ?? row['type'] ?? '').toString(),
                _number(row['Amount'] ?? _rowAmount(row)).toStringAsFixed(2),
              ]).toList(),
            ),
            pw.SizedBox(height: 14),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Total: Rs. ${_total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ],
        ));
        return doc.save();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to generate PDF: $e')));
    }
  }

  String _dateForPdf(dynamic value) {
    if (value is Timestamp) return _dateText(value.toDate());
    if (value is DateTime) return _dateText(value);
    return '';
  }

  double get _total => _rows.fold<double>(0, (s, r) => s + _number(r['Amount'] ?? _rowAmount(r)));

  @override
  Widget build(BuildContext context) {
    final retailLocked = _assignedShopId != null && _assignedShopId!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filterCard(retailLocked),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!))),
          _resultCard(),
        ],
      ),
    );
  }

  Widget _filterCard(bool retailLocked) {
    final periods = const ['Daily', 'Monthly', 'Quarterly', '6 Monthly', 'Yearly', 'Date Range'];
    final showShop = ['Sales', 'Payments', 'Outstanding', 'Commission'].contains(_reportType);
    final showProduct = ['Sales', 'Outstanding', 'Production'].contains(_reportType);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Report Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reportType,
            decoration: const InputDecoration(labelText: 'Report', border: OutlineInputBorder()),
            items: _reportTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) { if (v == null) return; setState(() { _reportType = v; }); _loadReport(); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _periodType,
            decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
            items: periods.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) { if (v != null) _setPeriod(v); },
          ),
          if (_periodType == 'Date Range') ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text('From: ${_dateText(_fromDate)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text('To: ${_dateText(_toDate)}'))),
            ]),
          ],
          if (showShop) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _shopId,
              decoration: InputDecoration(labelText: retailLocked ? 'Retail Shop (Assigned)' : 'Retail Shop', border: const OutlineInputBorder()),
              items: [
                if (!retailLocked) const DropdownMenuItem<String?>(value: null, child: Text('All Retail Shops')),
                ..._shops.map((s) => DropdownMenuItem<String?>(value: s['id']?.toString(), child: Text(s['name']?.toString() ?? ''))),
              ],
              onChanged: retailLocked ? null : (v) { setState(() { _shopId = v; }); _loadReport(); },
            ),
          ],
          if (showProduct) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _productId,
              decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
              items: [const DropdownMenuItem<String?>(value: null, child: Text('All Products')), ..._products.map((p) => DropdownMenuItem<String?>(value: p['id']?.toString(), child: Text(p['name']?.toString() ?? '')))],
              onChanged: (v) { setState(() { _productId = v; }); _loadReport(); },
            ),
          ],
          if (_reportType == 'Salary') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _workerId,
              decoration: const InputDecoration(labelText: 'Worker', border: OutlineInputBorder()),
              items: [const DropdownMenuItem<String?>(value: null, child: Text('All Workers')), ..._workers.map((w) => DropdownMenuItem<String?>(value: w['id']?.toString(), child: Text(w['name']?.toString() ?? '')))],
              onChanged: (v) { setState(() { _workerId = v; }); _loadReport(); },
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _loading ? null : _loadReport, icon: const Icon(Icons.assessment_outlined), label: const Text('GENERATE REPORT'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _rows.isEmpty ? null : _downloadPdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('DOWNLOAD PDF'))),
          ]),
        ]),
      ),
    );
  }

  Widget _resultCard() {
    if (_loading && _rows.isEmpty) return const SizedBox.shrink();
    if (_rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No records found for the selected period.'))));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(_title(), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))), Text('Total: ${_money(_total)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Divider(),
          ..._rows.map((row) => ListTile(
            dense: true,
            title: Text((row['shopName'] ?? row['productName'] ?? row['workerName'] ?? row['Particular'] ?? row['type'] ?? 'Transaction').toString()),
            subtitle: Text(_dateForPdf(row['date'])),
            trailing: Text(_money(row['Amount'] ?? _rowAmount(row)), style: const TextStyle(fontWeight: FontWeight.w600)),
          )),
        ]),
      ),
    );
  }
}
