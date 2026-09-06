import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../services/firestore_service.dart';

class ProductionExpensesPage extends StatefulWidget {
  const ProductionExpensesPage({super.key});

  @override
  State<ProductionExpensesPage> createState() =>
      _ProductionExpensesPageState();
}

class _ProductionExpensesPageState
    extends State<ProductionExpensesPage> {
  DateTime selectedDate = DateTime.now();

  String expenseHead = 'Raw Material';
  String account = 'Cash';

  final descriptionController = TextEditingController();
  final amountController = TextEditingController();

  bool saving = false;

  final List<String> expenseHeads = const [
    'Raw Material',
    'Capital',
    'Salary',
    'Transport',
    'Other',
  ];

  final List<String> accounts = const [
    'Cash',
    'Bank',
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
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

  Future<void> _saveExpense() async {
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

    final expense = Expense(
      id: '',
      date: selectedDate,
      head: expenseHead,
      description: descriptionController.text.trim(),
      amount: amount,
      account: account,
    );

    setState(() {
      saving = true;
    });

    try {
      await FirestoreService.instance.add(
        'productionExpenses',
        expense.toMap(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Production expense saved successfully.',
          ),
        ),
      );

      descriptionController.clear();
      amountController.clear();

      setState(() {
        selectedDate = DateTime.now();
        expenseHead = 'Raw Material';
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
            'Unable to save expense:\n$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Expenses'),
      ),
      body: ListView(
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
                    'Expense Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _selectDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Expense Date',
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
                    initialValue: expenseHead,
                    items: expenseHeads.map((head) {
                      return DropdownMenuItem<String>(
                        value: head,
                        child: Text(head),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          expenseHead = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Expense Head',
                      prefixIcon:
                          Icon(Icons.category_outlined),
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
                    decoration: const InputDecoration(
                      labelText: 'Payment Account',
                      prefixIcon:
                          Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: descriptionController,
                    textCapitalization:
                        TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Example: Flour, butter, transport, etc.',
                      prefixIcon:
                          Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹ ',
                      prefixIcon:
                          Icon(Icons.currency_rupee),
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
              onPressed: saving ? null : _saveExpense,
              icon: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                saving
                    ? 'SAVING...'
                    : 'SAVE EXPENSE',
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
