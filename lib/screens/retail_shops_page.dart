import 'package:flutter/material.dart';

import '../models/retail_shop.dart';
import '../services/firestore_service.dart';

class RetailShopsPage extends StatelessWidget {
  const RetailShopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retail Shops'),
        actions: [
          IconButton(
            tooltip: 'Add Retail Shop',
            onPressed: () => _shopDialog(context),
            icon: const Icon(Icons.add_business),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('retailShops'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading shops:\n${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final shops = (snapshot.data ?? [])
              .map(
                (data) => RetailShop.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .toList();

          shops.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          if (shops.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 56,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No retail shops',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your retail shops to use them in Sales.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      shop.active
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                    ),
                  ),
                  title: Text(
                    shop.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (shop.phone.isNotEmpty) shop.phone,
                      if (shop.address.isNotEmpty) shop.address,
                      'Commission: ₹${shop.commissionPerBox.toStringAsFixed(2)} / Box',
                      shop.active ? 'Active' : 'Inactive',
                    ].join('\n'),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _shopDialog(
                          context,
                          existing: shop,
                        );
                      }

                      if (value == 'toggle') {
                        await FirestoreService.instance.update(
                          'retailShops',
                          shop.id,
                          shop
                              .copyWith(active: !shop.active)
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
                          shop.active ? 'Deactivate' : 'Activate',
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

  Future<void> _shopDialog(
    BuildContext context, {
    RetailShop? existing,
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

    final commissionController = TextEditingController(
      text: existing == null
          ? ''
          : existing.commissionPerBox.toStringAsFixed(2),
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
                    ? 'Add Retail Shop'
                    : 'Edit Retail Shop',
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
                        labelText: 'Shop Name',
                        prefixIcon: Icon(Icons.storefront),
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
                      controller: commissionController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Commission per Box',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.percent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Shop'),
                      subtitle: const Text(
                        'Inactive shops will not be used for new sales.',
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
                          content: Text('Enter shop name.'),
                        ),
                      );
                      return;
                    }

                    final commission =
                        double.tryParse(
                              commissionController.text.trim(),
                            ) ??
                            0;

                    if (commission < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Commission cannot be negative.',
                          ),
                        ),
                      );
                      return;
                    }

                    final data = RetailShop(
                      id: existing?.id ?? '',
                      name: name,
                      phone: phoneController.text.trim(),
                      address: addressController.text.trim(),
                      commissionPerBox: commission,
                      active: active,
                    ).toMap();

                    if (existing == null) {
                      await FirestoreService.instance.add(
                        'retailShops',
                        data,
                      );
                    } else {
                      await FirestoreService.instance.update(
                        'retailShops',
                        existing.id,
                        data,
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
