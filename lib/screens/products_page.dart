import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/firestore_service.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add Product',
            onPressed: () => _productDialog(context),
            icon: const Icon(Icons.add_box),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('products'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading products:\n${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final products = (snapshot.data ?? [])
              .map(
                (data) => Product.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .toList();

          products.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          if (products.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 56,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Add your bakery products to use them in Production and Sales.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    child: Icon(
                      product.active
                          ? Icons.inventory_2
                          : Icons.inventory_2_outlined,
                    ),
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Unit: ${product.unit}\n'
                    'Default MRP: ₹${product.defaultMrp.toStringAsFixed(2)}\n'
                    '${product.active ? 'Active' : 'Inactive'}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _productDialog(
                          context,
                          existing: product,
                        );
                      }

                      if (value == 'toggle') {
                        await FirestoreService.instance.update(
                          'products',
                          product.id,
                          product
                              .copyWith(active: !product.active)
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
                          product.active ? 'Deactivate' : 'Activate',
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

  Future<void> _productDialog(
    BuildContext context, {
    Product? existing,
  }) async {
    final nameController = TextEditingController(
      text: existing?.name ?? '',
    );

    final mrpController = TextEditingController(
      text: existing == null
          ? ''
          : existing.defaultMrp.toStringAsFixed(2),
    );

    String unit = existing?.unit ?? 'Box';
    bool active = existing?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                existing == null
                    ? 'Add Product'
                    : 'Edit Product',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      items: const [
                        DropdownMenuItem(
                          value: 'Box',
                          child: Text('Box'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => unit = value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mrpController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default MRP',
                        prefixText: '₹ ',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Product'),
                      subtitle: const Text(
                        'Inactive products will not be used for new entries.',
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
                          content: Text('Enter product name.'),
                        ),
                      );
                      return;
                    }

                    final mrp =
                        double.tryParse(
                              mrpController.text.trim(),
                            ) ??
                            0;

                    if (mrp < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'MRP cannot be negative.',
                          ),
                        ),
                      );
                      return;
                    }

                    final product = Product(
                      id: existing?.id ?? '',
                      name: name,
                      unit: unit,
                      defaultMrp: mrp,
                      active: active,
                    );

                    if (existing == null) {
                      await FirestoreService.instance.add(
                        'products',
                        product.toMap(),
                      );
                    } else {
                      await FirestoreService.instance.update(
                        'products',
                        existing.id,
                        product.toMap(),
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
