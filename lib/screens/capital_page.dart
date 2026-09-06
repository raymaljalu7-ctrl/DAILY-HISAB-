import 'package:flutter/material.dart';

import '../models/capital.dart';
import '../services/firestore_service.dart';

class CapitalPage extends StatefulWidget {
  const CapitalPage({super.key});

  @override
  State<CapitalPage> createState() => _CapitalPageState();
}

class _CapitalPageState extends State<CapitalPage> {
  DateTime selectedDate = DateTime.now();
  String capitalType = 'Capital Received';
  String account = 'Cash';

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  bool saving = false;

  final List<String> capitalTypes = const [
    'Capital Received',
    'Capital Returned',
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

  Future<void> _saveCapital() async {
    final amount = double.tryParse(
          amountController.text.trim(),
        ) ??
        0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an amount greater than zero.',
          ),
        ),
      );
      return;
    }

    final capital = Capital(
      id: '',
      date: selectedDate,
      type: capitalType,
      amount: amount,
      account: account,
      description: descriptionController.text.trim(),
    );

    setState(() {
      saving = true;
    });

    try {
      await FirestoreService.instance.add(
        'capital',
        capital.toMap(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Capital entry saved successfully.',
          ),
        ),
      );

      amountController.clear();
      descriptionController.clear();

      setState(() {
        selectedDate = DateTime.now();
        capitalType = 'Capital Received';
        account = 'Cash';
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
            'Unable to save capital entry:\n$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capital Management'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('capital'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading capital entries:\n${snapshot.error}',
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

          final entries = (snapshot.data ?? [])
              .map(
                (data) => Capital.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .toList();

          entries.sort(
            (a, b) => b.date.compareTo(a.date),
          );

          final totalReceived = entries
              .where(
                (entry) =>
                    entry.type == 'Capital Received',
              )
              .fold<double>(
                0,
                (total, entry) => total + entry.amount,
              );

          final totalReturned = entries
              .where(
                (entry) =>
                    entry.type == 'Capital Returned',
              )
              .fold<double>(
                0,
                (total, entry) => total + entry.amount,
              );

          final outstanding =
              totalReceived - totalReturned;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _summaryCard(
                      context,
                      'Received',
                      totalReceived,
                      Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryCard(
                      context,
                      'Returned',
                      totalReturned,
                      Icons.arrow_upward,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.account_balance),
                  ),
                  title: const Text(
                    'Capital Outstanding',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Received capital minus returned capital',
                  ),
                  trailing: Text(
                    '₹${outstanding.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capital Entry',
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
                        initialValue: capitalType,
                        items: capitalTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              capitalType = value;
                            });
                          }
                        },
                        decoration:
                            const InputDecoration(
                          labelText: 'Capital Type',
                          prefixIcon:
                              Icon(Icons.swap_vert),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

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
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: amountController,
                        keyboardType:
                            const TextInputType
                                .numberWithOptions(
                          decimal: true,
                        ),
                        decoration:
                            const InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          prefixIcon:
                              Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(),
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
                              'Example: Production funding, daily capital return, etc.',
                          prefixIcon:
                              Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(),
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
                      saving ? null : _saveCapital,
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
                        : 'SAVE CAPITAL ENTRY',
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (entries.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    bottom: 8,
                  ),
                  child: Text(
                    'Recent Capital Entries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ...entries.take(20).map(
                (entry) {
                  final received =
                      entry.type == 'Capital Received';

                  return Card(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          received
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                        ),
                      ),
                      title: Text(
                        entry.type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        [
                          _formatDate(entry.date),
                          entry.account,
                          if (entry.description.isNotEmpty)
                            entry.description,
                        ].join(' • '),
                      ),
                      trailing: Text(
                        '₹${entry.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String title,
    double amount,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
