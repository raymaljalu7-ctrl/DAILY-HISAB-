import 'package:flutter/material.dart';

import '../models/party.dart';
import '../models/transaction.dart';
import '../services/firestore_service.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTime selectedDate = DateTime.now();
  String transactionType = 'Receipt';
  String account = 'Cash';
  Party? selectedParty;
  String? selectedPartyId;
  String? editingId;

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  bool saving = false;

  final List<String> transactionTypes = const [
    'Receipt',
    'Payment',
    'Commission Payment',
    'Capital',
    'Others',
  ];

  final List<String> accounts = const ['Cash', 'Bank'];

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _clearForm() {
    amountController.clear();
    descriptionController.clear();
    setState(() {
      selectedDate = DateTime.now();
      transactionType = 'Receipt';
      account = 'Cash';
      selectedParty = null;
      selectedPartyId = null;
      editingId = null;
      saving = false;
    });
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than zero.')));
      return;
    }
    if (transactionType != 'Others' && selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a party.')));
      return;
    }

    final transaction = HisabTransaction(
      id: editingId ?? '',
      date: selectedDate,
      type: transactionType,
      amount: amount,
      account: account,
      partyId: selectedParty?.id ?? '',
      partyName: selectedParty?.name ?? '',
      description: descriptionController.text.trim(),
    );

    setState(() => saving = true);
    try {
      if (editingId == null) {
        await FirestoreService.instance.add('transactions', transaction.toMap());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved successfully.')));
      } else {
        final id = editingId!;
        await FirestoreService.instance.update('transactions', id, transaction.toMap());
        if (!mounted) return;
        final admin = await FirestoreService.instance.isAdmin();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(admin ? 'Transaction updated successfully.' : 'Edit request sent to Admin for approval.'),
        ));
      }
      _clearForm();
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save transaction:\n$error')));
    }
  }

  Future<void> _addNewParty() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final result = await showDialog<Party>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add New Party'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Party Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Enter party name.')));
                return;
              }
              try {
                final party = Party(id: '', name: name, phone: phoneController.text.trim());
                final id = await FirestoreService.instance.add('parties', party.toMap());
                if (dialogContext.mounted) Navigator.pop(dialogContext, Party(id: id, name: party.name, phone: party.phone));
              } catch (error) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Unable to add party:\n$error')));
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (result != null && mounted) setState(() { selectedParty = result; selectedPartyId = result.id; });
  }

  void _startEdit(HisabTransaction transaction, List<Party> parties) {
    Party? party;
    for (final item in parties) {
      if (item.id == transaction.partyId) { party = item; break; }
    }
    setState(() {
      editingId = transaction.id;
      selectedDate = transaction.date;
      transactionType = transaction.type;
      account = transaction.account == 'Bank' ? 'Bank' : 'Cash';
      selectedParty = party;
      selectedPartyId = transaction.partyId.isEmpty ? null : transaction.partyId;
      amountController.text = transaction.amount.toStringAsFixed(2);
      descriptionController.text = transaction.description;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction loaded for editing.')));
  }

  Future<void> _deleteTransaction(HisabTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Delete ${transaction.type} of ₹${transaction.amount.toStringAsFixed(2)} dated ${_formatDate(transaction.date)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirestoreService.instance.delete('transactions', transaction.id);
      if (!mounted) return;
      final admin = await FirestoreService.instance.isAdmin();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(admin ? 'Transaction deleted successfully.' : 'Delete request sent to Admin for approval.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to delete transaction:\n$error')));
    }
  }

  Widget _entryForm(List<Party> parties) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(editingId == null ? 'Transaction Entry' : 'Edit Transaction', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            if (editingId != null) TextButton(onPressed: _clearForm, child: const Text('CANCEL EDIT')),
          ]),
          const SizedBox(height: 16),
          InkWell(onTap: _selectDate, borderRadius: BorderRadius.circular(8), child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_month), border: OutlineInputBorder()), child: Text(_formatDate(selectedDate)))),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: transactionType, items: transactionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (value) { if (value != null) setState(() => transactionType = value); }, decoration: const InputDecoration(labelText: 'Transaction Type', prefixIcon: Icon(Icons.swap_horiz), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          if (transactionType != 'Others') ...[
            DropdownButtonFormField<String>(initialValue: selectedPartyId, isExpanded: true, items: parties.map((party) => DropdownMenuItem(value: party.id, child: Text(party.name))).toList(), onChanged: (id) { if (id == null) return; setState(() { selectedPartyId = id; selectedParty = parties.firstWhere((p) => p.id == id); }); }, decoration: const InputDecoration(labelText: 'Party', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder())),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _addNewParty, icon: const Icon(Icons.person_add_alt_1), label: const Text('ADD NEW PARTY'))),
            const SizedBox(height: 8),
          ],
          DropdownButtonFormField<String>(initialValue: account, items: accounts.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) setState(() => account = value); }, decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: descriptionController, textCapitalization: TextCapitalization.sentences, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', hintText: 'Enter transaction details', prefixIcon: Icon(Icons.notes_outlined), border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(height: 52, width: double.infinity, child: FilledButton.icon(onPressed: saving ? null : _saveTransaction, icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(saving ? 'SAVING...' : editingId == null ? 'SAVE TRANSACTION' : 'SUBMIT EDIT'))),
        ]),
      ),
    );
  }

  Widget _history(List<Party> parties) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('transactions'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading transactions:\n${snapshot.error}')));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final transactions = (snapshot.data ?? []).map((d) => HisabTransaction.fromMap(d['id'].toString(), d)).toList();
        transactions.sort((a, b) => b.date.compareTo(a.date));
        if (transactions.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No transactions found.')));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Transaction History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...transactions.map((transaction) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
            title: Text(transaction.partyName.isEmpty ? transaction.type : '${transaction.type} • ${transaction.partyName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${_formatDate(transaction.date)} • ${transaction.account}\n${transaction.description.isEmpty ? 'No description' : transaction.description}'),
            isThreeLine: true,
            trailing: SizedBox(width: 150, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${transaction.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(tooltip: 'Edit', onPressed: saving ? null : () => _startEdit(transaction, parties), icon: const Icon(Icons.edit_outlined, size: 20)),
                IconButton(tooltip: 'Delete', onPressed: saving ? null : () => _deleteTransaction(transaction), icon: const Icon(Icons.delete_outline, size: 20)),
              ]),
            ])),
          )))
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('parties'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error loading parties:\n${snapshot.error}', textAlign: TextAlign.center));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final parties = (snapshot.data ?? []).map((data) => Party.fromMap(data['id'].toString(), data)).where((party) => party.active).toList();
          parties.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          if (selectedPartyId != null && !parties.any((party) => party.id == selectedPartyId)) { selectedPartyId = null; selectedParty = null; }
          return ListView(padding: const EdgeInsets.all(12), children: [_entryForm(parties), const SizedBox(height: 24), _history(parties), const SizedBox(height: 24)]);
        },
      ),
    );
  }
}
