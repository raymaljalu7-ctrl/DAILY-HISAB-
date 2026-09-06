import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String filterType = 'Date';
  DashboardSummary? summary;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';
  String _dateText(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _loadDashboard() async {
    if (mounted) setState(() { loading = true; errorMessage = null; });
    try {
      final result = await DashboardService.instance.calculate(
        from: fromDate,
        to: DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59),
      );
      if (!mounted) return;
      setState(() { summary = result; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; errorMessage = e.toString(); });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: fromDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() { fromDate = picked; toDate = picked; });
    await _loadDashboard();
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDateRange: DateTimeRange(start: fromDate, end: toDate));
    if (range == null) return;
    setState(() { fromDate = range.start; toDate = range.end; });
    await _loadDashboard();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(context: context, initialDate: fromDate, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDatePickerMode: DatePickerMode.year);
    if (picked == null) return;
    final start = DateTime(picked.year, picked.month, 1);
    final end = DateTime(picked.year, picked.month + 1, 0);
    setState(() { fromDate = start; toDate = end; });
    await _loadDashboard();
  }

  Future<void> _changeFilter(String value) async {
    setState(() => filterType = value);
    if (value == 'Date') await _pickDate();
    else if (value == 'Date Range') await _pickRange();
    else await _pickMonth();
  }

  String _periodText() {
    if (filterType == 'Date') return _dateText(fromDate);
    if (filterType == 'Month') return '${fromDate.month}/${fromDate.year}';
    return '${_dateText(fromDate)} to ${_dateText(toDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), actions: [IconButton(onPressed: loading ? null : _loadDashboard, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          children: [
            Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dashboard Period', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: filterType,
                items: const [
                  DropdownMenuItem(value: 'Date', child: Text('Date-wise')),
                  DropdownMenuItem(value: 'Date Range', child: Text('Date Range-wise')),
                  DropdownMenuItem(value: 'Month', child: Text('Month-wise')),
                ],
                onChanged: (v) { if (v != null) _changeFilter(v); },
                decoration: const InputDecoration(labelText: 'Filter', prefixIcon: Icon(Icons.filter_alt_outlined), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              InkWell(onTap: () { if (filterType == 'Date') _pickDate(); else if (filterType == 'Date Range') _pickRange(); else _pickMonth(); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Selected Period', prefixIcon: Icon(Icons.calendar_month), border: OutlineInputBorder()), child: Text(_periodText()))),
            ]))),
            const SizedBox(height: 10),
            if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (errorMessage != null) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Icon(Icons.error_outline, size: 42), const SizedBox(height: 8), const Text('Unable to load dashboard'), Text(errorMessage!, textAlign: TextAlign.center), const SizedBox(height: 10), FilledButton(onPressed: _loadDashboard, child: const Text('RETRY'))])))
            else if (summary != null) _content(summary!)
            else const Card(child: Padding(padding: EdgeInsets.all(25), child: Text('No dashboard data.'))),
          ],
        ),
      ),
    );
  }

  Widget _content(DashboardSummary d) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Business Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _grid([
        _Metric('Sales', _money(d.sales), Icons.point_of_sale_outlined),
        _Metric('Payments Received', _money(d.paymentsReceived), Icons.arrow_downward),
        _Metric('Payment Made', _money(d.paymentsMade), Icons.arrow_upward),
        _Metric('Cash Payment', _money(d.cashPaymentsMade), Icons.money_outlined),
        _Metric('Bank Payment', _money(d.bankPaymentsMade), Icons.account_balance_outlined),
        _Metric('Outstanding', _money(d.outstanding), Icons.account_balance_wallet_outlined),
        _Metric('Commission', _money(d.commission), Icons.percent_outlined),
      ]),
      const SizedBox(height: 14),
      const Text('Production & Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _grid([
        _Metric('Production', '${d.productionBoxes.toStringAsFixed(0)} Boxes', Icons.factory_outlined),
        _Metric('Expenses', _money(d.expenses), Icons.receipt_long_outlined),
        _Metric('Salary', _money(d.salary), Icons.people_outline),
        _Metric('Profit / Loss', _money(d.profitLoss), d.profitLoss >= 0 ? Icons.trending_up : Icons.trending_down),
      ]),
      const SizedBox(height: 14),
      const Text('Capital', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _grid([
        _Metric('Capital Received', _money(d.capitalReceived), Icons.arrow_downward),
        _Metric('Capital Returned', _money(d.capitalReturned), Icons.arrow_upward),
        _Metric('Capital Balance', _money(d.capitalReceived - d.capitalReturned), Icons.account_balance_outlined),
      ]),
    ]);
  }

  Widget _grid(List<_Metric> items) {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 700 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 7, mainAxisSpacing: 7, childAspectRatio: columns == 4 ? 1.65 : 1.55),
        itemBuilder: (_, i) {
          final m = items[i];
          final cs = Theme.of(context).colorScheme;
          return Card(color: cs.surfaceContainerHighest, margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(7), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(m.icon, size: 20, color: cs.primary), const SizedBox(height: 3), Text(m.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)), const SizedBox(height: 2), FittedBox(child: Text(m.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))])));
        },
      );
    });
  }
}

class _Metric {
  final String title;
  final String value;
  final IconData icon;
  const _Metric(this.title, this.value, this.icon);
}
