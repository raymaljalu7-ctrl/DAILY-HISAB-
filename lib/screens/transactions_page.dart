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
  bool saving = false;

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  static const transactionTypes = <String>[
    'Receipt',
    'Payment',
    'Commission Payment',
    'Capital',
    'Others',
  ];
  static const accounts = <String>['Cash', 'Bank'];

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  void _clearForm() {
    amountController.clear();
    descriptionController.clear();
    if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }
    if (transactionType != 'Others' && selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a party.')),
      );
      return;
    }

    setState(() => saving = true);
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

    try {
      if (editingId == null) {
        await FirestoreService.instance.add('transactions', transaction.toMap());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully.')),
        );
      } else {
        final id = editingId!;
        await FirestoreService.instance.update('transactions', id, transaction.toMap());
        if (!mounted) return;
        final admin = await FirestoreService.instance.isAdmin();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              admin
                  ? 'Transaction updated successfully.'
                  : 'Edit request sent to Admin for approval.',
            ),
          ),
        );
      }
      _clearForm();
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save transaction:\n$error')),
      );
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Party Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Enter party name.')),
                  );
                }
                return;
              }
              try {
                final party = Party(
                  id: '',
                  name: name,
                  phone: phoneController.text.trim(),
                );
                final id = await FirestoreService.instance.add(
                  'parties',
                  party.toMap(),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(
                    dialogContext,
                    Party(id: id, name: party.name, phone: party.phone),
                  );
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Unable to add party:\n$error')),
                  );
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    if (result != null && mounted) {
      setState(() {
        selectedParty = result;
        selectedPartyId = result.id;
      });
    }
  }

  void _startEdit(HisabTransaction transaction, List<Party> parties) {
    Party? party;
    for (final item in parties) {
      if (item.id == transaction.partyId) {
        party = item;
        break;
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction loaded for editing.')),
    );
  }

  Future<void> _deleteTransaction(HisabTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'Delete ${transaction.type} of ₹${transaction.amount.toStringAsFixed(2)} dated ${_formatDate(transaction.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirestoreService.instance.delete('transactions', transaction.id);
      if (!mounted) return;
      final admin = await FirestoreService.instance.isAdmin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            admin
                ? 'Transaction deleted successfully.'
                : 'Delete request sent to Admin for approval.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete transaction:\n$error')),
      );
    }
  }

  Widget _entryForm(List<Party> parties) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    editingId == null ? 'Transaction Entry' : 'Edit Transaction',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (editingId != null)
                  TextButton(
                    onPressed: _clearForm,
                    child: const Text('CANCEL EDIT'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_month),
                  border: OutlineInputBorder(),
                ),
                child: Text(_formatDate(selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: transactionType,
              items: transactionTypes
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => transactionType = value);
              },
              decoration: const InputDecoration(
                labelText: 'Transaction Type',
                prefixIcon: Icon(Icons.swap_horiz),
                border: OutlineInputBorder(),
              ),
            ),
            if (transactionType != 'Others') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedPartyId,
                isExpanded: true,
                items: parties
                    .map((party) => DropdownMenuItem(
                          value: party.id,
                          child: Text(party.name),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final party = parties.firstWhere((item) => item.id == id);
                  setState(() {
                    selectedPartyId = id;
                    selectedParty = party;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Party',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addNewParty,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('ADD NEW PARTY'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: account,
              items: accounts
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => account = value);
              },
              decoration: const InputDecoration(
                labelText: 'Account',
                prefixIcon: Icon(Icons.account_balance_wallet),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter transaction details',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _history(List<Party> parties) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('transactions'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Error loading transaction history:\n${snapshot.error}'),
          );
        }

        final transactions = (snapshot.data ?? [])
            .map((data) => HisabTransaction.fromMap(data['id'].toString(), data))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        if (transactions.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No transactions found.'),
            ),
          );
        }

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...transactions.map(
                (transaction) => ListTile(
                  title: Text(
                    transaction.partyName.isEmpty
                        ? transaction.type
                        : '${transaction.type} • ${transaction.partyName}',
                  ),
                  subtitle: Text(
                    '${_formatDate(transaction.date)} • ${transaction.account}'
                    '${transaction.description.isEmpty ? '' : ' • ${transaction.description}'}',
                  ),
                  trailing: SizedBox(
                    width: 108,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${transaction.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _startEdit(transaction, parties),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteTransaction(transaction),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
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
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading parties:\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final parties = (snapshot.data ?? [])
              .map((data) => Party.fromMap(data['id'].toString(), data))
              .where((party) => party.active)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

          if (selectedPartyId != null &&
              !parties.any((party) => party.id == selectedPartyId)) {
            selectedPartyId = null;
            selectedParty = null;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _entryForm(parties),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: saving ? null : _saveTransaction,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(editingId == null ? Icons.save : Icons.check),
                  label: Text(
                    saving
                        ? 'SAVING...'
                        : editingId == null
                            ? 'SAVE TRANSACTION'
                            : 'SAVE EDIT REQUEST',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _history(parties),
            ],
          );
        },
      ),
    );
  }
}
