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

  final List<String> accounts = const [
    'Cash',
    'Bank',
  ];

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

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(
          amountController.text.trim(),
        ) ??
        0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount greater than zero.'),
        ),
      );
      return;
    }

    if (transactionType != 'Others' &&
        selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a party.'),
        ),
      );
      return;
    }

    final transaction = HisabTransaction(
      id: '',
      date: selectedDate,
      type: transactionType,
      amount: amount,
      account: account,
      partyId: selectedParty?.id ?? '',
      partyName: selectedParty?.name ?? '',
      description: descriptionController.text.trim(),
    );

    setState(() {
      saving = true;
    });

    try {
      await FirestoreService.instance.add(
        'transactions',
        transaction.toMap(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Transaction saved successfully.',
          ),
        ),
      );

      amountController.clear();
      descriptionController.clear();

      setState(() {
        selectedDate = DateTime.now();
        transactionType = 'Receipt';
        account = 'Cash';
        selectedParty = null;
        selectedPartyId = null;
        saving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to save transaction:\n$error',
          ),
        ),
      );
    }
  }

  Future<void> _addNewParty() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Party>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter party name.'),
                    ),
                  );
                  return;
                }

                final party = Party(
                  id: '',
                  name: name,
                  phone: phoneController.text.trim(),
                );

                try {
                  final id =
                      await FirestoreService.instance.add(
                    'parties',
                    party.toMap(),
                  );

                  if (dialogContext.mounted) {
                    Navigator.pop(
                      dialogContext,
                      Party(
                        id: id,
                        name: party.name,
                        phone: party.phone,
                      ),
                    );
                  }
                } catch (error) {
                  if (!dialogContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Unable to add party:\n$error',
                      ),
                    ),
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
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

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final parties = (snapshot.data ?? [])
              .map(
                (data) => Party.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .where((party) => party.active)
              .toList();

          parties.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          if (selectedPartyId != null &&
              !parties.any(
                (party) => party.id == selectedPartyId,
              )) {
            selectedPartyId = null;
            selectedParty = null;
          } else if (selectedPartyId != null) {
            selectedParty = parties.firstWhere(
              (party) => party.id == selectedPartyId,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      InkWell(
                        onTap: _selectDate,
                        borderRadius:
                            BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon:
                                Icon(Icons.calendar_month),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _formatDate(selectedDate),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: transactionType,
                        items: transactionTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              transactionType = value;
                            });
                          }
                        },
                        decoration:
                            const InputDecoration(
                          labelText: 'Transaction Type',
                          prefixIcon:
                              Icon(Icons.swap_horiz),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (transactionType != 'Others')
                        DropdownButtonFormField<String>(
                          initialValue: selectedPartyId,
                          isExpanded: true,
                          items: parties.map((party) {
                            return DropdownMenuItem<String>(
                              value: party.id,
                              child: Text(party.name),
                            );
                          }).toList(),
                          onChanged: (partyId) {
                            if (partyId == null) {
                              return;
                            }
                            setState(() {
                              selectedPartyId = partyId;
                              selectedParty = parties.firstWhere(
                                (party) => party.id == partyId,
                              );
                            });
                          },
                          decoration:
                              const InputDecoration(
                            labelText: 'Party',
                            prefixIcon:
                                Icon(Icons.person_outline),
                            border:
                                OutlineInputBorder(),
                          ),
                        ),

                      if (transactionType != 'Others')
                        const SizedBox(height: 8),

                      if (transactionType != 'Others')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _addNewParty,
                            icon: const Icon(
                              Icons.person_add_alt_1,
                            ),
                            label: const Text(
                              'ADD NEW PARTY',
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: account,
                        items: accounts.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              account = value;
                            });
                          }
                        },
                        decoration:
                            const InputDecoration(
                          labelText: 'Account',
                          prefixIcon: Icon(
                            Icons.account_balance_wallet,
                          ),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          prefixIcon:
                              Icon(Icons.currency_rupee),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller:
                            descriptionController,
                        textCapitalization:
                            TextCapitalization.sentences,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(
                          labelText: 'Description',
                          hintText:
                              'Enter transaction details',
                          prefixIcon:
                              Icon(Icons.notes_outlined),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      saving ? null : _saveTransaction,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    saving
                        ? 'SAVING...'
                        : 'SAVE TRANSACTION',
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
