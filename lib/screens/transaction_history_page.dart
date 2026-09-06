import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/firestore_service.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  Future<void> _edit(BuildContext context, HisabTransaction item) async {
    final amount = TextEditingController(text: item.amount.toStringAsFixed(2));
    final description = TextEditingController(text: item.description);
    String type = item.type;
    String account = item.account;
    DateTime date = item.date;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Edit Transaction'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.calendar_month), title: Text('${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}'), onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setLocal(() => date = picked);
            }),
            DropdownButtonFormField<String>(initialValue: type, items: const ['Receipt','Payment','Commission Payment','Capital','Others'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) { if (x != null) setLocal(() => type = x); }, decoration: const InputDecoration(labelText: 'Type')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(initialValue: account, items: const ['Cash','Bank'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) { if (x != null) setLocal(() => account = x); }, decoration: const InputDecoration(labelText: 'Account')),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
            const SizedBox(height: 10),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('SAVE')),
          ],
        ),
      ),
    );

    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (result != true || value <= 0 || !context.mounted) { amount.dispose(); description.dispose(); return; }

    try {
      await FirestoreService.instance.update('transactions', item.id, {
        'date': Timestamp.fromDate(date),
        'type': type,
        'amount': value,
        'account': account,
        'partyId': item.partyId,
        'partyName': item.partyName,
        'description': description.text.trim(),
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request sent to Admin.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send edit request: $e')));
    }
    amount.dispose(); description.dispose();
  }

  Future<void> _delete(BuildContext context, HisabTransaction item) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete Transaction?'), content: const Text('For non-admin users, this will be sent to Admin for approval. The record will remain unchanged until approval.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('REQUEST DELETE'))]));
    if (ok != true || !context.mounted) return;
    try {
      await FirestoreService.instance.delete('transactions', item.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request sent to Admin.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send delete request: $e')));
    }
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('transactions'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error loading transactions:\n${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final items = (snapshot.data ?? []).map((x) => HisabTransaction.fromMap(x['id'].toString(), x)).toList();
          items.sort((a,b) => b.date.compareTo(a.date));
          if (items.isEmpty) return const Center(child: Text('No transactions recorded yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                leading: CircleAvatar(child: Icon(item.type == 'Receipt' ? Icons.arrow_downward : Icons.arrow_upward)),
                title: Text('${item.type} • ₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${_date(item.date)} • ${item.account}\n${item.partyName.isEmpty ? 'No party' : item.partyName}${item.description.isEmpty ? '' : ' • ${item.description}'}'),
                isThreeLine: true,
                trailing: Wrap(children: [IconButton(tooltip: 'Edit', onPressed: () => _edit(context, item), icon: const Icon(Icons.edit_outlined)), IconButton(tooltip: 'Delete', onPressed: () => _delete(context, item), icon: const Icon(Icons.delete_outline))]),
              ));
            },
          );
        },
      ),
    );
  }
}
