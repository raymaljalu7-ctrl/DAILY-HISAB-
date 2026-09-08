import 'package:flutter/material.dart';

import '../models/party.dart';
import '../services/firestore_service.dart';
import '../services/retail_cash_service.dart';

class RetailTransactionsPage extends StatefulWidget {
  const RetailTransactionsPage({super.key});
  @override State<RetailTransactionsPage> createState() => _RetailTransactionsPageState();
}

class _RetailTransactionsPageState extends State<RetailTransactionsPage> {
  String transactionType = 'Receipt';
  String paymentSubType = 'Party';
  String account = 'Cash';
  Party? selectedParty;
  String? selectedPartyId;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  bool saving = false;

  @override
  void dispose() { amountController.dispose(); descriptionController.dispose(); super.dispose(); }

  Future<void> _save(List<Party> parties) async {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) { _message('Enter an amount greater than zero.'); return; }
    final needsParty = transactionType == 'Receipt' || paymentSubType == 'Party';
    if (needsParty && selectedParty == null) { _message('Please select a party.'); return; }
    if (transactionType == 'Payment' && paymentSubType == 'Expense' && descriptionController.text.trim().isEmpty) {
      _message('Please enter the expense details.'); return;
    }
    setState(() => saving = true);
    final map = <String, dynamic>{
      'date': DateTime.now(), 'type': transactionType, 'amount': amount, 'account': account,
      'partyId': selectedParty?.id ?? '', 'partyName': selectedParty?.name ?? '',
      'description': descriptionController.text.trim(),
      if (transactionType == 'Payment') 'subType': paymentSubType,
    };
    try {
      await FirestoreService.instance.add('transactions', map);
      if (!mounted) return;
      amountController.clear(); descriptionController.clear();
      setState(() { selectedParty = null; selectedPartyId = null; saving = false; });
      _message('Transaction saved successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false); _message('Unable to save transaction:\n$error');
    }
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Widget _balanceCard() {
    return FutureBuilder<Map<String, double>>(
      future: RetailCashService.instance.balances(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Unable to calculate retail balance:\n${snapshot.error}')));
        }
        final data = snapshot.data ?? {'Cash': 0, 'Bank': 0};
        final cash = data['Cash'] ?? 0;
        final bank = data['Bank'] ?? 0;
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('End-of-Day Cash / Bank Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _balanceTile('CASH IN HAND', cash, Icons.payments_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _balanceTile('BANK BALANCE', bank, Icons.account_balance_outlined)),
          ]),
          const SizedBox(height: 8),
          Text('Total available: ₹${(cash + bank).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Includes this shop\'s receipts/payments and retail sales payments.'),
        ])));
      },
    );
  }

  Widget _balanceTile(String title, double amount, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Column(children: [Icon(icon), const SizedBox(height: 5), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text('₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
  );

  Widget _entryForm(List<Party> parties) {
    final showParty = transactionType == 'Receipt' || paymentSubType == 'Party';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Retail Transaction Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: transactionType,
        items: const [DropdownMenuItem(value: 'Receipt', child: Text('Receipt')), DropdownMenuItem(value: 'Payment', child: Text('Payment'))],
        onChanged: saving ? null : (value) { if (value == null) return; setState(() { transactionType = value; if (value == 'Receipt') paymentSubType = 'Party'; selectedParty = null; selectedPartyId = null; }); },
        decoration: const InputDecoration(labelText: 'Transaction', prefixIcon: Icon(Icons.swap_horiz), border: OutlineInputBorder()),
      ),
      if (transactionType == 'Payment') ...[
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: paymentSubType,
          items: const [DropdownMenuItem(value: 'Party', child: Text('Party Payment')), DropdownMenuItem(value: 'Expense', child: Text('Expense'))],
          onChanged: saving ? null : (value) { if (value == null) return; setState(() { paymentSubType = value; selectedParty = null; selectedPartyId = null; }); },
          decoration: const InputDecoration(labelText: 'Payment For', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
        ),
      ],
      if (showParty) ...[
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: selectedPartyId, isExpanded: true,
          items: parties.map((party) => DropdownMenuItem(value: party.id, child: Text(party.name))).toList(),
          onChanged: saving ? null : (id) { if (id == null) return; final party = parties.firstWhere((item) => item.id == id); setState(() { selectedPartyId = id; selectedParty = party; }); },
          decoration: const InputDecoration(labelText: 'Party', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
        ),
      ],
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: account,
        items: const [DropdownMenuItem(value: 'Cash', child: Text('Cash')), DropdownMenuItem(value: 'Bank', child: Text('Bank'))],
        onChanged: saving ? null : (value) => setState(() => account = value ?? 'Cash'),
        decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder()),
      ),
      const SizedBox(height: 14),
      TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee), border: OutlineInputBorder())),
      const SizedBox(height: 14),
      TextField(controller: descriptionController, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: transactionType == 'Payment' && paymentSubType == 'Expense' ? 'Expense Details' : 'Description', prefixIcon: const Icon(Icons.notes_outlined), border: const OutlineInputBorder())),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: saving ? null : () => _save(parties), icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(saving ? 'SAVING...' : 'SAVE TRANSACTION'))),
    ])));
  }

  Widget _history(List<Map<String, dynamic>> rows) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      if (rows.isEmpty) const Text('No transactions found.'),
      ...rows.reversed.take(30).map((row) {
        final type = row['type']?.toString() ?? 'Transaction';
        final sub = row['subType']?.toString();
        final party = row['partyName']?.toString() ?? '';
        final accountName = row['account']?.toString() ?? 'Cash';
        final amount = (row['amount'] as num?)?.toDouble() ?? 0;
        final description = row['description']?.toString() ?? '';
        final detail = [if (sub != null && sub.isNotEmpty) sub, if (party.isNotEmpty) party, accountName, if (description.isNotEmpty) description].join(' • ');
        return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(type == 'Receipt' ? Icons.arrow_downward : Icons.arrow_upward), title: Text('$type • ₹${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(detail));
      }),
    ])));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Retail Cash & Bank')),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('parties'),
      builder: (context, partySnapshot) {
        if (partySnapshot.hasError) return Center(child: Text('Unable to load parties:\n${partySnapshot.error}'));
        if (partySnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final parties = (partySnapshot.data ?? []).map((data) => Party.fromMap(data['id'].toString(), data)).where((party) => party.active).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService.instance.stream('transactions'),
          builder: (context, transactionSnapshot) {
            if (transactionSnapshot.hasError) return Center(child: Text('Unable to load transactions:\n${transactionSnapshot.error}'));
            if (transactionSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final rows = transactionSnapshot.data ?? [];
            return ListView(padding: const EdgeInsets.all(12), children: [_balanceCard(), const SizedBox(height: 12), _entryForm(parties), const SizedBox(height: 12), _history(rows)]);
          },
        );
      },
    ),
  );
}
