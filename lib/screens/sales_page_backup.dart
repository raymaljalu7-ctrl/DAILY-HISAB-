import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/retail_shop.dart';
import '../models/sales.dart';
import '../services/firestore_service.dart';
import '../services/sales_service.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTime selectedDate = DateTime.now();
  String? selectedShopId;
  RetailShop? selectedShop;

  final List<_SalesRow> rows = [];

  bool saving = false;

  @override
  void initState() {
    super.initState();
    rows.add(_SalesRow());
  }

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  double get grossAmount {
    return rows.fold<double>(
      0,
      (total, row) => total + row.amount,
    );
  }

  double get commissionAmount {
    final commissionPerBox =
        selectedShop?.commissionPerBox ?? 0;

    final boxes = rows.fold<double>(
      0,
      (total, row) => total + row.quantity,
    );

    return boxes * commissionPerBox;
  }

  double get netAmount {
    final value = grossAmount - commissionAmount;
    return value < 0 ? 0 : value;
  }

  double get paymentReceived {
    return rows.fold<double>(
      0,
      (total, row) => total,
    );
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

  void _addRow() {
    setState(() {
      rows.add(_SalesRow());
    });
  }

  void _removeRow(int index) {
    if (rows.length == 1) {
      return;
    }

    final row = rows.removeAt(index);
    row.dispose();

    setState(() {});
  }

  void _update() {
    setState(() {});
  }

  Future<void> _saveSale(List<Product> products) async {
    if (selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a retail shop.'),
        ),
      );
      return;
    }

    final saleItems = <SaleItem>[];

    for (final row in rows) {
      if (row.productId == null) {
        continue;
      }

      if (row.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quantity must be greater than zero.',
            ),
          ),
        );
        return;
      }

      if (row.unitPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unit price cannot be negative.',
            ),
          ),
        );
        return;
      }

      Product? product;

      for (final item in products) {
        if (item.id == row.productId) {
          product = item;
          break;
        }
      }

      if (product == null) {
        continue;
      }

      saleItems.add(
        SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: row.quantity,
          unitPrice: row.unitPrice,
          amount: row.amount,
        ),
      );
    }

    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one product to the sale.',
          ),
        ),
      );
      return;
    }

    final gross = saleItems.fold<double>(
      0,
      (total, item) => total + item.amount,
    );

    final commission =
        SalesService.instance.calculateCommission(
      saleItems,
      selectedShop!.commissionPerBox,
    );

    final net = SalesService.instance.calculateNet(
      gross,
      commission,
    );

    final sale = Sale(
      id: '',
      date: selectedDate,
      shopId: selectedShop!.id,
      shopName: selectedShop!.name,
      items: saleItems,
      grossAmount: gross,
      commission: commission,
      netAmount: net,
      paymentReceived: 0,
      outstanding: net,
      paymentStatus: 'Pending',
    );

    setState(() {
      saving = true;
    });

    try {
      await SalesService.instance.addSale(sale);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales transaction saved successfully.'),
        ),
      );

      for (final row in rows) {
        row.clear();
      }

      setState(() {
        selectedShopId = null;
        selectedShop = null;
        selectedDate = DateTime.now();
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
            'Unable to save sale:\n$error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('retailShops'),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) {
            return Center(
              child: Text(
                'Error loading shops:\n${shopSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (shopSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final shops = (shopSnapshot.data ?? [])
              .map(
                (data) => RetailShop.fromMap(
                  data['id'].toString(),
                  data,
                ),
              )
              .where((shop) => shop.active)
              .toList();

          shops.sort(
            (a, b) => a.name.toLowerCase().compareTo(
                  b.name.toLowerCase(),
                ),
          );

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.instance.stream('products'),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading products:\n${productSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (productSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final products = (productSnapshot.data ?? [])
                  .map(
                    (data) => Product.fromMap(
                      data['id'].toString(),
                      data,
                    ),
                  )
                  .where((product) => product.active)
                  .toList();

              products.sort(
                (a, b) => a.name.toLowerCase().compareTo(
                      b.name.toLowerCase(),
                    ),
              );

              return _buildSalesForm(
                shops,
                products,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSalesForm(
    List<RetailShop> shops,
    List<Product> products,
  ) {
    if (shops.isEmpty || products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.point_of_sale_outlined,
                size: 56,
              ),
              const SizedBox(height: 12),
              const Text(
                'Sales setup incomplete',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                shops.isEmpty
                    ? 'Please add at least one active Retail Shop.'
                    : 'Please add at least one active Product.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (selectedShopId != null) {
      RetailShop? foundShop;

      for (final shop in shops) {
        if (shop.id == selectedShopId) {
          foundShop = shop;
          break;
        }
      }

      if (foundShop == null) {
        selectedShopId = null;
        selectedShop = null;
      } else {
        selectedShop = foundShop;
      }
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
                  'Sales Details',
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
                  initialValue: selectedShopId,
                  items: shops.map((shop) {
                    return DropdownMenuItem<String>(
                      value: shop.id,
                      child: Text(shop.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    RetailShop? shop;

                    for (final item in shops) {
                      if (item.id == value) {
                        shop = item;
                        break;
                      }
                    }

                    setState(() {
                      selectedShopId = value;
                      selectedShop = shop;

                      for (final row in rows) {
                        row.updateAmount();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Retail Shop',
                    prefixIcon:
                        Icon(Icons.storefront),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedShop != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(8),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    child: Text(
                      'Commission: ₹${selectedShop!.commissionPerBox.toStringAsFixed(2)} / Box',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  rows.length,
                  (index) => _buildProductRow(
                    index,
                    products,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow(
                  'Gross Sales',
                  grossAmount,
                ),
                const Divider(),
                _summaryRow(
                  'Commission',
                  commissionAmount,
                ),
                const Divider(),
                _summaryRow(
                  'Net Amount',
                  netAmount,
                  bold: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Payment received can be recorded separately through the Payment section.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: saving
                ? null
                : () => _saveSale(products),
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
              saving ? 'SAVING...' : 'SAVE SALES',
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProductRow(
    int index,
    List<Product> products,
  ) {
    final row = rows[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: row.productId,
                  items: products.map((product) {
                    return DropdownMenuItem<String>(
                      value: product.id,
                      child: Text(product.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    Product? product;

                    for (final item in products) {
                      if (item.id == value) {
                        product = item;
                        break;
                      }
                    }

                    row.productId = value;

                    if (product != null &&
                        row.unitPriceController.text
                            .trim()
                            .isEmpty &&
                        product.defaultMrp > 0) {
                      row.unitPriceController.text =
                          product.defaultMrp.toStringAsFixed(2);
                    }

                    row.updateAmount();
                    _update();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Bakery Item',
                    prefixIcon:
                        Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (rows.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove Item',
                  onPressed: () => _removeRow(index),
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: row.quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    row.updateAmount();
                    _update();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    suffixText: 'Box',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: row.unitPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    row.updateAmount();
                    _update();
                  },
                  decoration: const InputDecoration(
                    labelText: 'MRP / Unit Price',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Amount: ₹${row.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: bold ? 18 : 16,
            fontWeight:
                bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SalesRow {
  String? productId;

  final TextEditingController quantityController =
      TextEditingController();

  final TextEditingController unitPriceController =
      TextEditingController();

  double amount = 0;

  double get quantity {
    return double.tryParse(
          quantityController.text.trim(),
        ) ??
        0;
  }

  double get unitPrice {
    return double.tryParse(
          unitPriceController.text.trim(),
        ) ??
        0;
  }

  void updateAmount() {
    amount = quantity * unitPrice;
  }

  void clear() {
    productId = null;
    quantityController.clear();
    unitPriceController.clear();
    amount = 0;
  }

  void dispose() {
    quantityController.dispose();
    unitPriceController.dispose();
  }
}
