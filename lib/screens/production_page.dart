import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/production.dart';
import '../services/firestore_service.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  DateTime selectedDate = DateTime.now();
  final List<_ProductionRow> rows = [];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    rows.add(_ProductionRow());
  }

  @override
  void dispose() {
    for (final row in rows) row.dispose();
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
    if (picked != null && mounted) setState(() => selectedDate = picked);
  }

  void _addRow() => setState(() => rows.add(_ProductionRow()));

  void _removeRow(int index) {
    if (rows.length == 1) return;
    final row = rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _saveProduction(List<Product> products) async {
    final entries = <Production>[];
    for (final row in rows) {
      if (row.productId == null) continue;
      if (row.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quantity must be greater than zero.')),
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
      if (product == null) continue;
      entries.add(Production(
        id: '',
        date: selectedDate,
        productId: product.id,
        productName: product.name,
        quantity: row.quantity,
        unit: 'Box',
      ));
    }

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product to production.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      for (final entry in entries) {
        await FirestoreService.instance.add('production', entry.toMap());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entries.length} production item(s) saved successfully.')),
      );
      for (final row in rows) row.clear();
      setState(() {
        selectedDate = DateTime.now();
        saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save production:\n$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('products'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading products:\n${snapshot.error}', textAlign: TextAlign.center));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = (snapshot.data ?? [])
              .map((data) => Product.fromMap(data['id'].toString(), data))
              .where((product) => product.active)
              .toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return _buildProductionForm(products);
        },
      ),
    );
  }

  Widget _buildProductionForm(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.factory_outlined, size: 56),
              SizedBox(height: 12),
              Text('No active products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Add products in Products Master before entering production.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Production Date', prefixIcon: Icon(Icons.calendar_month), border: OutlineInputBorder()),
                child: Text(_formatDate(selectedDate)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Production Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    FilledButton.tonalIcon(onPressed: _addRow, icon: const Icon(Icons.add), label: const Text('Add Item')),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(rows.length, (index) => _buildProductionRow(index, products)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: saving ? null : () => _saveProduction(products),
            icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
            label: Text(saving ? 'SAVING...' : 'SAVE PRODUCTION'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProductionRow(int index, List<Product> products) {
    final row = rows[index];
    return Container(
      key: ValueKey(row),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              initialValue: row.productId,
              items: products.map((product) => DropdownMenuItem<String>(value: product.id, child: Text(product.name))).toList(),
              onChanged: (value) => setState(() => row.productId = value),
              decoration: const InputDecoration(labelText: 'Bakery Item', prefixIcon: Icon(Icons.inventory_2_outlined), border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: ValueKey('production-quantity-${row.hashCode}'),
              controller: row.quantityController,
              focusNode: row.quantityFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Box', border: OutlineInputBorder()),
            ),
          ),
          if (rows.length > 1) ...[
            const SizedBox(width: 4),
            IconButton(tooltip: 'Remove Item', onPressed: () => _removeRow(index), icon: const Icon(Icons.delete_outline)),
          ],
        ],
      ),
    );
  }
}

class _ProductionRow {
  String? productId;
  final TextEditingController quantityController = TextEditingController();
  final FocusNode quantityFocus = FocusNode();

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0;

  void clear() {
    productId = null;
    quantityController.clear();
  }

  void dispose() {
    quantityController.dispose();
    quantityFocus.dispose();
  }
}
