import 'package:flutter/material.dart';

void main() {
  runApp(const DailyHisabApp());
}

class DailyHisabApp extends StatelessWidget {
  const DailyHisabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Hisab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DailyHisabHome(),
    );
  }
}

class HisabEntry {
  HisabEntry({
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
  });

  final DateTime date;
  final String description;
  final double amount;
  final String type;
}

class DailyHisabHome extends StatefulWidget {
  const DailyHisabHome({super.key});

  @override
  State<DailyHisabHome> createState() => _DailyHisabHomeState();
}

class _DailyHisabHomeState extends State<DailyHisabHome> {
  final List<HisabEntry> _entries = [];

  double get _receipts => _entries
      .where((e) => e.type == 'Receipt')
      .fold(0, (sum, e) => sum + e.amount);

  double get _payments => _entries
      .where((e) => e.type == 'Payment')
      .fold(0, (sum, e) => sum + e.amount);

  double get _expenses => _entries
      .where((e) => e.type == 'Expense')
      .fold(0, (sum, e) => sum + e.amount);

  double get _balance => _receipts - _payments - _expenses;

  void _addEntry() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'Receipt';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Hisab Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Receipt',
                          child: Text('Receipt'),
                        ),
                        DropdownMenuItem(
                          value: 'Payment',
                          child: Text('Payment'),
                        ),
                        DropdownMenuItem(
                          value: 'Expense',
                          child: Text('Expense'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Customer payment',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final description = descriptionController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim());

                    if (description.isEmpty || amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a description and valid amount.',
                          ),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _entries.insert(
                        0,
                        HisabEntry(
                          date: DateTime.now(),
                          description: description,
                          amount: amount,
                          type: type,
                        ),
                      );
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteEntry(int index) {
    setState(() => _entries.removeAt(index));
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  Widget _summaryCard(String title, double amount, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    _money(amount),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Hisab',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const Text('Current Balance'),
                    const SizedBox(height: 6),
                    Text(
                      _money(_balance),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 105,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              scrollDirection: Axis.horizontal,
              children: [
                SizedBox(
                  width: 180,
                  child: _summaryCard(
                    'Receipts',
                    _receipts,
                    Icons.call_received,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _summaryCard(
                    'Payments',
                    _payments,
                    Icons.call_made,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: _summaryCard(
                    'Expenses',
                    _expenses,
                    Icons.receipt_long,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transactions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions yet.\nTap + to add your first entry.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];

                      final IconData icon = entry.type == 'Receipt'
                          ? Icons.arrow_downward
                          : entry.type == 'Payment'
                              ? Icons.arrow_upward
                              : Icons.shopping_cart;

                      return Dismissible(
                        key: ObjectKey(entry),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteEntry(index),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(child: Icon(icon)),
                          title: Text(entry.description),
                          subtitle: Text(
                            '${entry.type} • '
                            '${entry.date.day.toString().padLeft(2, '0')}/'
                            '${entry.date.month.toString().padLeft(2, '0')}/'
                            '${entry.date.year}',
                          ),
                          trailing: Text(
                            '${entry.type == 'Receipt' ? '+' : '-'}'
                            '${_money(entry.amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
    );
  }
}
