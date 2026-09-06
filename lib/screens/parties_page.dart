import 'package:flutter/material.dart';

import '../models/party.dart';
import '../services/firestore_service.dart';

class PartiesPage extends StatelessWidget {
  const PartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties'),
        actions: [
          IconButton(
            tooltip: 'Add Party',
            onPressed: () => _partyDialog(context),
            icon: const Icon(Icons.person_add),
          ),
        ],
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

          if (snapshot.connectionState == ConnectionState.waiting) {
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
              .toList();

          parties.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          if (parties.isEmpty) {
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
                      'No parties',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add customers, suppliers or other parties here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: parties.length,
            itemBuilder: (context, index) {
              final party = parties[index];

              final openingText = party.openingBalance == 0
                  ? 'Opening Balance: ₹0.00'
                  : 'Opening: ₹${party.openingBalance.toStringAsFixed(2)} '
                      '(${party.openingType})';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      party.active
                          ? Icons.person
                          : Icons.person_outline,
                    ),
                  ),
                  title: Text(
                    party.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (party.phone.isNotEmpty) party.phone,
                      if (party.address.isNotEmpty) party.address,
                      openingText,
                      party.active ? 'Active' : 'Inactive',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _partyDialog(
                          context,
                          existing: party,
                        );
                      }

                      if (value == 'toggle') {
                        await FirestoreService.instance.update(
                          'parties',
                          party.id,
                          party
                              .copyWith(
                                active: !party.active,
                              )
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
                          party.active
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

  Future<void> _partyDialog(
    BuildContext context, {
    Party? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    final phoneController = TextEditingController(
      text: existing?.phone ?? '',
    );

    final addressController = TextEditingController(
      text: existing?.address ?? '',
    );

    final openingController = TextEditingController(
      text: existing == null
          ? ''
          : existing.openingBalance.toStringAsFixed(2),
    );

    String openingType = existing?.openingType ?? 'Receivable';
    bool active = existing?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Add Party'
                    : 'Edit Party',
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
                        labelText: 'Party Name',
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
                      controller: addressController,
                      textCapitalization:
                          TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: openingController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance',
                        prefixText: '₹ ',
                        prefixIcon:
                            Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: openingType,
                      items: const [
                        DropdownMenuItem(
                          value: 'Receivable',
                          child: Text('Receivable'),
                        ),
                        DropdownMenuItem(
                          value: 'Payable',
                          child: Text('Payable'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(
                            () => openingType = value,
                          );
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Opening Balance Type',
                        prefixIcon:
                            Icon(Icons.account_balance_wallet),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Party'),
                      subtitle: const Text(
                        'Inactive parties will not be used for new transactions.',
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
                            'Enter party name.',
                          ),
                        ),
                      );
                      return;
                    }

                    final opening =
                        double.tryParse(
                              openingController.text.trim(),
                            ) ??
                            0;

                    if (opening < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Opening balance cannot be negative.',
                          ),
                        ),
                      );
                      return;
                    }

                    final party = Party(
                      id: existing?.id ?? '',
                      name: name,
                      phone: phoneController.text.trim(),
                      address: addressController.text.trim(),
                      openingBalance: opening,
                      openingType: openingType,
                      active: active,
                    );

                    if (existing == null) {
                      await FirestoreService.instance.add(
                        'parties',
                        party.toMap(),
                      );
                    } else {
                      await FirestoreService.instance.update(
                        'parties',
                        existing.id,
                        party.toMap(),
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
