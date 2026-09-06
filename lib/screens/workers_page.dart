import 'package:flutter/material.dart';

import '../models/worker.dart';
import '../services/firestore_service.dart';

class WorkersPage extends StatelessWidget {
  const WorkersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers'),
        actions: [
          IconButton(
            tooltip: 'Add Worker',
            onPressed: () => _workerDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
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

          if (snapshot.connectionState == ConnectionState.waiting) {
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
                      'No workers',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your production workers to manage salary, advances and payments.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: workers.length,
            itemBuilder: (context, index) {
              final worker = workers[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      worker.active
                          ? Icons.person
                          : Icons.person_outline,
                    ),
                  ),
                  title: Text(
                    worker.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (worker.phone.isNotEmpty) worker.phone,
                      'Monthly Salary: ₹${worker.monthlySalary.toStringAsFixed(2)}',
                      worker.active ? 'Active' : 'Inactive',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _workerDialog(
                          context,
                          existing: worker,
                        );
                      }

                      if (value == 'toggle') {
                        await FirestoreService.instance.update(
                          'workers',
                          worker.id,
                          worker
                              .copyWith(active: !worker.active)
                              .toMap(),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          worker.active
                              ? 'Deactivate'
                              : 'Activate',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _workerDialog(
    BuildContext context, {
    Worker? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    final phoneController = TextEditingController(
      text: existing?.phone ?? '',
    );

    final salaryController = TextEditingController(
      text: existing == null
          ? ''
          : existing.monthlySalary.toStringAsFixed(2),
    );

    bool active = existing?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Add Worker'
                    : 'Edit Worker',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Worker Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: salaryController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Salary',
                        prefixText: '₹ ',
                        prefixIcon:
                            Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Worker'),
                      subtitle: const Text(
                        'Inactive workers will not be used for new salary entries.',
                      ),
                      value: active,
                      onChanged: (value) {
                        setState(() => active = value);
                      },
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter worker name.',
                          ),
                        ),
                      );
                      return;
                    }

                    final salary =
                        double.tryParse(
                              salaryController.text.trim(),
                            ) ??
                            0;

                    if (salary < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Monthly salary cannot be negative.',
                          ),
                        ),
                      );
                      return;
                    }

                    final worker = Worker(
                      id: existing?.id ?? '',
                      name: name,
                      phone: phoneController.text.trim(),
                      monthlySalary: salary,
                      active: active,
                    );

                    if (existing == null) {
                      await FirestoreService.instance.add(
                        'workers',
                        worker.toMap(),
                      );
                    } else {
                      await FirestoreService.instance.update(
                        'workers',
                        existing.id,
                        worker.toMap(),
                      );
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(
                    existing == null ? 'SAVE' : 'UPDATE',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
