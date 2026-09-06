import 'package:flutter/material.dart';

import '../models/salary.dart';
import '../models/worker.dart';
import '../services/firestore_service.dart';

class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  DateTime selectedDate = DateTime.now();
  String salaryType = 'Salary Payment';
  Worker? selectedWorker;

  final amountController = TextEditingController();
  final descriptionController = TextEditingController();

  bool saving = false;

  final List<String> salaryTypes = const [
    'Salary Payment',
    'Advance Payment',
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

  Future<void> _saveSalary() async {
    if (selectedWorker == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a worker.'),
        ),
      );
      return;
    }

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

    final salary = Salary(
      id: '',
      date: selectedDate,
      workerId: selectedWorker!.id,
      workerName: selectedWorker!.name,
      type: salaryType,
      amount: amount,
      description: descriptionController.text.trim(),
    );

    setState(() {
      saving = true;
    });

    try {
      await FirestoreService.instance.add(
        'salary',
        salary.toMap(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Salary payment saved successfully.',
          ),
        ),
      );

      amountController.clear();
      descriptionController.clear();

      setState(() {
        selectedDate = DateTime.now();
        salaryType = 'Salary Payment';
        selectedWorker = null;
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
            'Unable to save salary payment:\n$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary & Advances'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('workers'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading workers:\n${snapshot.error}',
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

          final workers = (snapshot.data ?? [])
              .map(
                (data) => Worker.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .where((worker) => worker.active)
              .toList();

          workers.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          if (workers.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 56,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No active workers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add workers first from the Workers section.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (selectedWorker != null &&
              !workers.any(
                (worker) => worker.id == selectedWorker!.id,
              )) {
            selectedWorker = null;
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
                        'Salary Entry',
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
                          decoration:
                              const InputDecoration(
                            labelText: 'Payment Date',
                            prefixIcon:
                                Icon(Icons.calendar_month),
                            border:
                                OutlineInputBorder(),
                          ),
                          child: Text(
                            _formatDate(selectedDate),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<Worker>(
                        initialValue: selectedWorker,
                        isExpanded: true,
                        items: workers.map((worker) {
                          return DropdownMenuItem<Worker>(
                            value: worker,
                            child: Text(
                              worker.name,
                            ),
                          );
                        }).toList(),
                        onChanged: (worker) {
                          setState(() {
                            selectedWorker = worker;
                          });
                        },
                        decoration:
                            const InputDecoration(
                          labelText: 'Worker',
                          prefixIcon:
                              Icon(Icons.person),
                          border:
                              OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (selectedWorker != null)
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedWorker!.name,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monthly Salary: ₹${selectedWorker!.monthlySalary.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),

                      if (selectedWorker != null)
                        const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: salaryType,
                        items: salaryTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              salaryType = value;
                            });
                          }
                        },
                        decoration:
                            const InputDecoration(
                          labelText: 'Payment Type',
                          prefixIcon:
                              Icon(Icons.payments_outlined),
                          border:
                              OutlineInputBorder(),
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
                              'Example: April salary, advance, etc.',
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
                      saving ? null : _saveSalary,
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
                        : 'SAVE SALARY PAYMENT',
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
