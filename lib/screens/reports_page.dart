import 'package:cloud_firestore/cloud_firestore.dart';
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
  final ReportService _reportService = ReportService.instance;

  String _reportType = 'Sales';
  String _periodType = 'Date';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String? _shopId;
  String? _workerId;
  String? _productId;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _products = [];

  final List<String> _reportTypes = [
    'Sales',
    'Payments',
    'Outstanding',
    'Commission',
    'Production',
    'Expenses',
    'Salary',
    'Capital',
    'Profit/Loss',
  ];

  @override
  void initState() {
    super.initState();
    _loadMasters();
    _loadReport();
  }

  Future<void> _loadMasters() async {
    try {
      final db = FirebaseFirestore.instance;
      final root = db.collection('sharedData').doc('dailyHisab');

      final shopSnap = await root.collection('retailShops').get();
      final workerSnap = await root.collection('workers').get();
      final productSnap = await root.collection('products').get();

      if (!mounted) return;

      setState(() {
        _shops = shopSnap.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .where((e) => e['active'] != false)
            .toList();

        _workers = workerSnap.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .where((e) => e['active'] != false)
            .toList();

        _products = productSnap.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .where((e) => e['active'] != false)
            .toList();
      });
    } catch (_) {
      // Masters are optional for reports.
    }
  }

  DateTime get _start {
    return DateTime(
      _fromDate.year,
      _fromDate.month,
      _fromDate.day,
    );
  }

  DateTime get _end {
    return DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    );
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> result = [];

      switch (_reportType) {
        case 'Sales':
          result = await _reportService.sales(
            from: _start,
            to: _end,
            shopId: _shopId,
            productId: _productId,
          );
          break;

        case 'Payments':
          result = await _reportService.transactions(
            from: _start,
            to: _end,
          );
          result = result
              .where(
                (row) =>
                    row['type']?.toString().toLowerCase() == 'receipt',
              )
              .toList();
          break;

        case 'Outstanding':
          result = await _reportService.sales(
            from: _start,
            to: _end,
            shopId: _shopId,
            productId: _productId,
          );
          break;

        case 'Commission':
          result = await _reportService.commissions(
            from: _start,
            to: _end,
            shopId: _shopId,
          );
          break;

        case 'Production':
          result = await _reportService.production(
            from: _start,
            to: _end,
          );
          break;

        case 'Expenses':
          result = await _reportService.expenses(
            from: _start,
            to: _end,
          );
          break;

        case 'Salary':
          result = await _reportService.salary(
            from: _start,
            to: _end,
            workerId: _workerId,
          );
          break;

        case 'Capital':
          result = await _reportService.capital(
            from: _start,
            to: _end,
          );
          break;

        case 'Profit/Loss':
          result = await _buildProfitLoss();
          break;
      }

      if (!mounted) return;

      setState(() {
        _rows = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _buildProfitLoss() async {
    final sales = await _reportService.sales(
      from: _start,
      to: _end,
      shopId: _shopId,
    );

    final expenses = await _reportService.expenses(
      from: _start,
      to: _end,
    );

    final salary = await _reportService.salary(
      from: _start,
      to: _end,
      workerId: _workerId,
    );

    double grossSales = 0;
    double commission = 0;
    double totalExpenses = 0;
    double totalSalary = 0;

    for (final row in sales) {
      grossSales += _number(
        row['grossAmount'] ?? row['amount'],
      );

      commission += _number(
        row['commission'],
      );
    }

    for (final row in expenses) {
      totalExpenses += _number(
        row['amount'],
      );
    }

    for (final row in salary) {
      totalSalary += _number(
        row['amount'],
      );
    }

    final profit =
        grossSales - commission - totalExpenses - totalSalary;

    return [
      {
        'Particular': 'Gross Sales',
        'Amount': grossSales,
      },
      {
        'Particular': 'Commission',
        'Amount': commission,
      },
      {
        'Particular': 'Expenses',
        'Amount': totalExpenses,
      },
      {
        'Particular': 'Salary',
        'Amount': totalSalary,
      },
      {
        'Particular': 'Profit / Loss',
        'Amount': profit,
      },
    ];
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  DateTime? _dateFromRow(Map<String, dynamic> row) {
    final value = row['date'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _dateText(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return value?.toString() ?? '';
    }

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _money(dynamic value) {
    return '₹${_number(value).toStringAsFixed(2)}';
  }

  Future<void> _pickDate({
    required bool from,
  }) async {
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

        if (_toDate.isBefore(selected)) {
          _toDate = selected;
        }
      } else {
        _toDate = selected;

        if (_fromDate.isAfter(selected)) {
          _fromDate = selected;
        }
      }
    });

    await _loadReport();
  }

  void _setPeriod(String value) {
    final now = DateTime.now();

    setState(() {
      _periodType = value;

      if (value == 'Date') {
        _fromDate = DateTime(
          now.year,
          now.month,
          now.day,
        );
        _toDate = _fromDate;
      } else if (value == 'Month') {
        _fromDate = DateTime(
          now.year,
          now.month,
          1,
        );

        _toDate = DateTime(
          now.year,
          now.month + 1,
          0,
        );
      }
    });

    _loadReport();
  }

  void _setCurrentMonth() {
    final now = DateTime.now();

    setState(() {
      _fromDate = DateTime(
        now.year,
        now.month,
        1,
      );

      _toDate = DateTime(
        now.year,
        now.month + 1,
        0,
      );

      _periodType = 'Month';
    });

    _loadReport();
  }

  double get _totalAmount {
    return _rows.fold<double>(
      0,
      (total, row) {
        return total + _number(
          row['amount'] ??
              row['grossAmount'] ??
              row['netAmount'] ??
              row['total'],
        );
      },
    );
  }

  double get _totalCommission {
    return _rows.fold<double>(
      0,
      (total, row) {
        return total + _number(
          row['commission'],
        );
      },
    );
  }

  double get _totalOutstanding {
    return _rows.fold<double>(
      0,
      (total, row) {
        return total + _number(
          row['outstanding'],
        );
      },
    );
  }

  String _title() {
    switch (_reportType) {
      case 'Sales':
        return 'Retail Shop Sales';
      case 'Payments':
        return 'Payment Collection';
      case 'Outstanding':
        return 'Outstanding';
      case 'Commission':
        return 'Commission';
      case 'Production':
        return 'Production Performance';
      case 'Expenses':
        return 'Production Expenses';
      case 'Salary':
        return 'Worker Salary';
      case 'Capital':
        return 'Capital Movement';
      case 'Profit/Loss':
        return 'Profit / Loss';
      default:
        return 'Report';
    }
  }

  IconData _icon() {
    switch (_reportType) {
      case 'Sales':
        return Icons.point_of_sale_outlined;
      case 'Payments':
        return Icons.payments_outlined;
      case 'Outstanding':
        return Icons.account_balance_wallet_outlined;
      case 'Commission':
        return Icons.percent_outlined;
      case 'Production':
        return Icons.factory_outlined;
      case 'Expenses':
        return Icons.receipt_long_outlined;
      case 'Salary':
        return Icons.badge_outlined;
      case 'Capital':
        return Icons.account_balance_outlined;
      case 'Profit/Loss':
        return Icons.trending_up_outlined;
      default:
        return Icons.assessment_outlined;
    }
  }

  Widget _filterCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Report Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _reportType,
              decoration: const InputDecoration(
                labelText: 'Report',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.assessment_outlined),
              ),
              items: _reportTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _reportType = value;
                  _error = null;
                });

                _loadReport();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _periodType,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.date_range_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Date',
                  child: Text('Date-wise'),
                ),
                DropdownMenuItem(
                  value: 'Range',
                  child: Text('Date Range'),
                ),
                DropdownMenuItem(
                  value: 'Month',
                  child: Text('Month-wise'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _setPeriod(value);
                }
              },
            ),
            const SizedBox(height: 12),
            if (_periodType == 'Month')
              OutlinedButton.icon(
                onPressed: _setCurrentMonth,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Current Month'),
              ),
            if (_periodType != 'Month')
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(from: true),
                      icon: const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      label: Text(
                        _dateText(_fromDate),
                      ),
                    ),
                  ),
                  if (_periodType == 'Range') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(from: false),
                        icon: const Icon(
                          Icons.event_outlined,
                        ),
                        label: Text(
                          _dateText(_toDate),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            if (_reportType == 'Sales' ||
                _reportType == 'Outstanding' ||
                _reportType == 'Commission') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _shopId,
                decoration: const InputDecoration(
                  labelText: 'Retail Shop',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Retail Shops'),
                  ),
                  ..._shops.map(
                    (shop) => DropdownMenuItem<String?>(
                      value: shop['id']?.toString(),
                      child: Text(
                        shop['name']?.toString() ?? '',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _shopId = value;
                  });
                  _loadReport();
                },
              ),
            ],
            if (_reportType == 'Production' ||
                _reportType == 'Sales') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _productId,
                decoration: const InputDecoration(
                  labelText: 'Product',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Products'),
                  ),
                  ..._products.map(
                    (product) => DropdownMenuItem<String?>(
                      value: product['id']?.toString(),
                      child: Text(
                        product['name']?.toString() ?? '',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _productId = value;
                  });
                  _loadReport();
                },
              ),
            ],
            if (_reportType == 'Salary') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _workerId,
                decoration: const InputDecoration(
                  labelText: 'Worker',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Workers'),
                  ),
                  ..._workers.map(
                    (worker) => DropdownMenuItem<String?>(
                      value: worker['id']?.toString(),
                      child: Text(
                        worker['name']?.toString() ?? '',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _workerId = value;
                  });
                  _loadReport();
                },
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _loadReport,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate Report'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading || _rows.isEmpty
                        ? null
                        : _createPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Download PDF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards() {
    if (_rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final cards = <Widget>[
      _summaryCard(
        'Records',
        _rows.length.toString(),
        Icons.list_alt_outlined,
      ),
    ];

    if (_reportType == 'Sales') {
      cards.add(
        _summaryCard(
          'Sales',
          _money(_totalAmount),
          Icons.point_of_sale_outlined,
        ),
      );

      cards.add(
        _summaryCard(
          'Commission',
          _money(_totalCommission),
          Icons.percent_outlined,
        ),
      );
    } else if (_reportType == 'Outstanding') {
      cards.add(
        _summaryCard(
          'Outstanding',
          _money(_totalOutstanding),
          Icons.account_balance_wallet_outlined,
        ),
      );
    } else if (_reportType == 'Profit/Loss') {
      cards.add(
        _summaryCard(
          'Net Result',
          _money(
            _rows.isEmpty ? 0 : _rows.last['Amount'],
          ),
          Icons.trending_up_outlined,
        ),
      );
    } else {
      cards.add(
        _summaryCard(
          'Total',
          _money(_totalAmount),
          Icons.currency_rupee,
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) => SizedBox(
          width: 155,
          child: cards[index],
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Icon(
                icon,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPdf() async {
    if (_rows.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No report records available for PDF.'),
        ),
      );
      return;
    }

    final doc = pw.Document();

    final headers = <String>[
      'Date',
      'Party / Shop',
      'Product',
      'Amount',
      'Status',
    ];

    final data = _rows.map((row) {
      final date = _dateFromRow(row);

      final party =
          row['shopName'] ??
          row['partyName'] ??
          row['workerName'] ??
          row['description'] ??
          '';

      final product =
          row['productName'] ??
          row['product'] ??
          '';

      final amount =
          row['amount'] ??
          row['grossAmount'] ??
          row['netAmount'] ??
          row['total'] ??
          0;

      final status =
          row['paymentStatus'] ??
          row['type'] ??
          row['head'] ??
          '';

      return <String>[
        date == null ? '' : _dateText(date),
        party.toString(),
        product.toString(),
        _money(amount),
        status.toString(),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Daily Hisab - ${_title()}',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            'Period: ${_dateText(_fromDate)} to ${_dateText(_toDate)}',
          ),
          pw.SizedBox(height: 8),
          pw.Text('Report: $_reportType'),
          if (_shopId != null)
            pw.Text(
              'Retail Shop: ${_shops.firstWhere(
                (shop) => shop['id']?.toString() == _shopId,
                orElse: () => {'name': 'Selected Shop'},
              )['name']}',
            ),
          if (_productId != null)
            pw.Text(
              'Product: ${_products.firstWhere(
                (product) => product['id']?.toString() == _productId,
                orElse: () => {'name': 'Selected Product'},
              )['name']}',
            ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(
              fontSize: 8,
            ),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total Records: ${_rows.length}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (_reportType == 'Sales')
            pw.Text('Total Sales: ${_money(_totalAmount)}'),
          if (_reportType == 'Outstanding')
            pw.Text(
              'Total Outstanding: ${_money(_totalOutstanding)}',
            ),
          if (_reportType == 'Commission')
            pw.Text(
              'Total Commission: ${_money(_totalCommission)}',
            ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
    );
  }

  Widget _reportTable() {
    if (_rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.assessment_outlined,
                  size: 42,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No records found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Try changing the date or report filters.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reportType == 'Profit/Loss') {
      return Card(
        child: Column(
          children: _rows.map((row) {
            final name = row['Particular']?.toString() ?? '';
            final amount = _number(row['Amount']);

            return ListTile(
              leading: CircleAvatar(
                radius: 18,
                child: Icon(
                  name == 'Profit / Loss'
                      ? Icons.trending_up
                      : Icons.receipt_long_outlined,
                  size: 18,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                _money(amount),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: name == 'Profit / Loss' && amount < 0
                      ? Colors.red
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Party / Shop')),
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Status')),
          ],
          rows: _rows.map((row) {
            final date = _dateFromRow(row);

            final party =
                row['shopName'] ??
                row['partyName'] ??
                row['workerName'] ??
                row['description'] ??
                '';

            final product =
                row['productName'] ??
                row['product'] ??
                '';

            final amount =
                row['amount'] ??
                row['grossAmount'] ??
                row['netAmount'] ??
                row['total'] ??
                0;

            final status =
                row['paymentStatus'] ??
                row['type'] ??
                row['head'] ??
                '';

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    date == null
                        ? ''
                        : _dateText(date),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      party.toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 150,
                    child: Text(
                      product.toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _money(amount),
                  ),
                ),
                DataCell(
                  Text(
                    status.toString(),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              _icon(),
              size: 22,
            ),
            const SizedBox(width: 8),
            const Text('Reports'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(_icon()),
                ),
                title: Text(
                  _title(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  '${_dateText(_fromDate)}'
                  '  to  '
                  '${_dateText(_toDate)}',
                ),
              ),
            ),
            const SizedBox(height: 10),
            _filterCard(),
            const SizedBox(height: 10),
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(25),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unable to generate report',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadReport,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_loading && _error == null) ...[
              _summaryCards(),
              if (_rows.isNotEmpty)
                const SizedBox(height: 10),
              _reportTable(),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
