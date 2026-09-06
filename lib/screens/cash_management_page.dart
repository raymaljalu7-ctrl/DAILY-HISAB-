import 'package:flutter/material.dart';
import '../services/cash_management_service.dart';

class CashManagementPage extends StatefulWidget {
  const CashManagementPage({super.key});
  @override State<CashManagementPage> createState() => _CashManagementPageState();
}

class _CashManagementPageState extends State<CashManagementPage> {
  late Future<Map<String,double>> _future;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _future = CashManagementService.instance.balances());

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cash Management'), actions: [
      IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh')
    ]),
    body: FutureBuilder<Map<String,double>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Unable to calculate balances:\n${snap.error}', textAlign: TextAlign.center)));
        final data = snap.data ?? {'Cash':0,'Bank':0};
        final cash = data['Cash'] ?? 0;
        final bank = data['Bank'] ?? 0;
        return RefreshIndicator(onRefresh: () async => _reload(), child: ListView(
          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          const Text('Current Balance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: _box(context, 'CASH', cash, Icons.payments_outlined)), const SizedBox(width: 12), Expanded(child: _box(context, 'BANK', bank, Icons.account_balance_outlined))]),
          const SizedBox(height: 20),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Automatic calculation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            SizedBox(height: 8), Text('Receipt → increases Cash/Bank'), Text('Payment → decreases Cash/Bank'), Text('Sales payment → increases selected Cash/Bank'), Text('Salary & expenses → decrease selected Cash/Bank'), Text('Capital received/returned → updates selected Cash/Bank'),
          ]))),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const Icon(Icons.calculate_outlined), title: const Text('No duplicate manual entries'), subtitle: Text('Balances are calculated from the original transactions and business records.'))),
        ]));
      },
    ),
  );

  Widget _box(BuildContext context, String title, double amount, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
      Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(_money(amount), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
    ])),
  );
}
