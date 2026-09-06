import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class BusinessHistoryPage extends StatelessWidget {
  final String collection;
  final String title;
  const BusinessHistoryPage({super.key, required this.collection, required this.title});

  String _date(dynamic value) {
    final d = value is Timestamp ? value.toDate() : DateTime.tryParse('$value') ?? DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  String _amount(Map<String,dynamic> d) => (d['amount'] ?? 0).toString();

  String _summary(Map<String,dynamic> d) {
    if (collection == 'productionExpenses') return '${d['name'] ?? d['head'] ?? 'Expense'} • ₹${_amount(d)} • ${d['account'] ?? 'Cash'}';
    if (collection == 'salary') return '${d['workerName'] ?? d['worker'] ?? 'Worker'} • ${d['type'] ?? 'Salary'} • ₹${_amount(d)}';
    return '${d['type'] ?? 'Capital'} • ₹${_amount(d)} • ${d['account'] ?? 'Cash'}';
  }

  Future<void> _edit(BuildContext context, DocumentSnapshot<Map<String,dynamic>> doc) async {
    final d = doc.data() ?? {};
    final amount = TextEditingController(text: _amount(d));
    final description = TextEditingController(text: '${d['description'] ?? ''}');
    final result = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('Edit $title'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
        const SizedBox(height: 10),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('SAVE'))],
    ));
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (result != true || value <= 0 || !context.mounted) { amount.dispose(); description.dispose(); return; }
    try {
      final update = <String,dynamic>{...d, 'amount': value, 'description': description.text.trim()};
      update.remove('id');
      update.remove('createdAt');
      await FirestoreService.instance.update(collection, doc.id, update);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit request sent to Admin.')));
    } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send edit request: $e'))); }
    amount.dispose(); description.dispose();
  }

  Future<void> _delete(BuildContext context, DocumentSnapshot<Map<String,dynamic>> doc) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('Delete $title record?'), content: const Text('Non-admin deletion will be sent to Admin for approval.'), actions: [TextButton(onPressed: () => Navigator.pop(c,false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c,true), child: const Text('REQUEST DELETE'))]));
    if (ok != true || !context.mounted) return;
    try { await FirestoreService.instance.delete(collection, doc.id); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete request sent to Admin.'))); }
    catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to send delete request: $e'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('$title History')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirestoreService.instance.query(collection),
      builder: (context,snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error loading records:\n${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = [...(snapshot.data?.docs ?? [])]..sort((a,b) {
          final ad = (a.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final bd = (b.data()['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return bd.compareTo(ad);
        });
        if (docs.isEmpty) return const Center(child: Text('No records recorded yet.'));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (context,index) {
          final doc = docs[index]; final d = doc.data();
          return Card(margin: const EdgeInsets.only(bottom:8), child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.history)),
            title: Text(_summary(d), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_date(d['date'])}\n${d['description'] ?? ''}'), isThreeLine: true,
            trailing: Wrap(children: [IconButton(tooltip:'Edit',onPressed:()=>_edit(context,doc),icon:const Icon(Icons.edit_outlined)),IconButton(tooltip:'Delete',onPressed:()=>_delete(context,doc),icon:const Icon(Icons.delete_outline))]),
          ));
        });
      },
    ),
  );
}
