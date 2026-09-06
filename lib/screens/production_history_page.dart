import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/production.dart';
import '../services/firestore_service.dart';

class ProductionHistoryPage extends StatelessWidget {
  const ProductionHistoryPage({super.key});

  Future<void> _edit(BuildContext context, Production item) async {
    final quantity = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Production'),
        content: TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Box')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('SAVE'))],
      ),
    );
    final value = double.tryParse(quantity.text.trim()) ?? 0;
    quantity.dispose();
    if (result != true || value <= 0 || !context.mounted) return;
    try {
      await FirestoreService.instance.update('production', item.id, {
        'date': Timestamp.fromDate(item.date),
        'productId': item.productId,
        'productName': item.productName,
        'quantity': value,
        'unit': item.unit,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request sent to Admin.')));
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send edit request: $e'))); }
  }

  Future<void> _delete(BuildContext context, Production item) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete Production?'), content: const Text('Non-admin deletion will be sent to Admin for approval.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('REQUEST DELETE'))]));
    if (ok != true || !context.mounted) return;
    try {
      await FirestoreService.instance.delete('production', item.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request sent to Admin.')));
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send delete request: $e'))); }
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('production'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error loading production:\n${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final items = (snapshot.data ?? []).map((x) => Production.fromMap(x['id'].toString(), x)).toList()..sort((a,b) => b.date.compareTo(a.date));
          if (items.isEmpty) return const Center(child: Text('No production records recorded yet.'));
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length, itemBuilder: (context, index) {
            final item = items[index];
            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.factory_outlined)),
              title: Text('${item.productName} • ${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_date(item.date)),
              trailing: Wrap(children: [IconButton(tooltip: 'Edit', onPressed: () => _edit(context, item), icon: const Icon(Icons.edit_outlined)), IconButton(tooltip: 'Delete', onPressed: () => _delete(context, item), icon: const Icon(Icons.delete_outline))]),
            ));
          });
        },
      ),
    );
  }
}
