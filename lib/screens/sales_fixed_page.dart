import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/retail_shop.dart';
import '../models/sales.dart';
import '../services/firestore_service.dart';
import '../services/sales_service.dart';

class SalesFixedPage extends StatefulWidget {
  const SalesFixedPage({super.key});
  @override State<SalesFixedPage> createState() => _SalesFixedPageState();
}

class _SaleRow {
  String? productId;
  final qty = TextEditingController();
  final rate = TextEditingController();
  void dispose() { qty.dispose(); rate.dispose(); }
}

class _SalesFixedPageState extends State<SalesFixedPage> {
  final rows = <_SaleRow>[_SaleRow()];
  final paid = TextEditingController();
  String? shopId;
  String? assignedShopId;
  String account = 'Cash';
  DateTime date = DateTime.now();
  bool retailUser = false;
  bool loading = true;
  bool saving = false;
  String? editingId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final r in rows) r.dispose();
    paid.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final data = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data() ?? {};
      if (!mounted) return;
      setState(() {
        retailUser = data['role']?.toString() == 'retail_shop_user';
        assignedShopId = data['shopId']?.toString();
        shopId = retailUser ? assignedShopId : null;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  double _number(String value) => double.tryParse(value.trim()) ?? 0;

  double _gross() => rows.fold<double>(0, (sum, row) => sum + _number(row.qty.text) * _number(row.rate.text));

  void _reset() {
    for (final r in rows) r.dispose();
    rows
      ..clear()
      ..add(_SaleRow());
    paid.clear();
    editingId = null;
    account = 'Cash';
    date = DateTime.now();
    shopId = retailUser ? assignedShopId : null;
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save(List<Product> products, List<RetailShop> shops) async {
    final shop = shops.where((x) => x.id == shopId).firstOrNull;
    if (shop == null) {
      _message('Please select a retail shop.');
      return;
    }

    final items = <SaleItem>[];
    for (final row in rows) {
      if (row.productId == null) continue;
      final product = products.where((x) => x.id == row.productId).firstOrNull;
      if (product == null) continue;
      final quantity = _number(row.qty.text);
      final rate = _number(row.rate.text);
      if (quantity <= 0) {
        _message('Quantity must be greater than zero.');
        return;
      }
      if (rate < 0) {
        _message('Rate cannot be negative.');
        return;
      }
      items.add(SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        unitPrice: rate,
        amount: quantity * rate,
      ));
    }

    if (items.isEmpty) {
      _message('Add at least one product.');
      return;
    }

    final gross = SalesService.instance.calculateGross(items);
    final commission = SalesService.instance.calculateCommission(items, shop.commissionPerBox);
    final net = SalesService.instance.calculateNet(gross, commission);
    final payment = _number(paid.text);
    if (payment > net) {
      _message('Payment received cannot exceed the net amount.');
      return;
    }

    final sale = Sale(
      id: editingId ?? '',
      date: date,
      shopId: shop.id,
      shopName: shop.name,
      items: items,
      grossAmount: gross,
      commission: commission,
      netAmount: net,
      paymentReceived: payment,
      outstanding: SalesService.instance.calculateOutstanding(net, payment),
      paymentStatus: SalesService.instance.paymentStatus(net, payment),
      paymentAccount: account,
    );

    setState(() => saving = true);
    try {
      if (editingId == null) {
        await SalesService.instance.addSale(sale);
        _message('Sales transaction saved successfully.');
      } else {
        final admin = await FirestoreService.instance.isAdmin();
        await SalesService.instance.updateSale(sale);
        _message(admin ? 'Sales transaction updated successfully.' : 'Edit request sent to Admin for approval.');
      }
      if (!mounted) return;
      _reset();
      setState(() => saving = false);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        _message('Unable to save sale: $e');
      }
    }
  }

  void _edit(Sale sale) {
    for (final r in rows) r.dispose();
    rows.clear();
    for (final item in sale.items) {
      rows.add(_SaleRow()
        ..productId = item.productId
        ..qty.text = item.quantity.toString()
        ..rate.text = item.unitPrice.toStringAsFixed(2));
    }
    if (rows.isEmpty) rows.add(_SaleRow());
    setState(() {
      editingId = sale.id;
      date = sale.date;
      shopId = sale.shopId;
      paid.text = sale.paymentReceived.toStringAsFixed(2);
      account = sale.paymentAccount.isEmpty ? 'Cash' : sale.paymentAccount;
    });
  }

  Future<void> _delete(Sale sale) async {
    try {
      final admin = await FirestoreService.instance.isAdmin();
      await SalesService.instance.deleteSale(sale.id);
      _message(admin ? 'Sales transaction deleted.' : 'Delete request sent to Admin for approval.');
    } catch (e) {
      _message('Unable to delete sale: $e');
    }
  }

  Widget _summary(List<RetailShop> shops) {
    final listenables = <Listenable>[paid];
    for (final row in rows) {
      listenables.add(row.qty);
      listenables.add(row.rate);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, child) {
        final shop = shops.where((x) => x.id == shopId).firstOrNull;
        final gross = _gross();
        final quantity = rows.fold<double>(0, (sum, row) => sum + _number(row.qty.text));
        final commission = quantity * (shop?.commissionPerBox ?? 0);
        final net = (gross - commission).clamp(0, double.infinity).toDouble();
        final payment = _number(paid.text);
        final outstanding = (net - payment).clamp(0, double.infinity).toDouble();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _line('Gross Sales', gross),
                _line('Commission', commission),
                _line('Net Amount', net, bold: true),
                const SizedBox(height: 10),
                TextField(
                  controller: paid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Payment Received', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: account,
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                  ],
                  onChanged: saving ? null : (value) { if (value != null) setState(() => account = value); },
                  decoration: const InputDecoration(labelText: 'Payment Account', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                _line('Outstanding', outstanding, bold: true),
                Text('Status: ${SalesService.instance.paymentStatus(net, payment)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _line(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
          Text('₹${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('retailShops'),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.hasError) return Center(child: Text('Error loading shops: ${shopSnapshot.error}'));
          if (!shopSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final shops = (shopSnapshot.data ?? [])
              .map((data) => RetailShop.fromMap(data['id'].toString(), data))
              .where((shop) => shop.active && (!retailUser || shop.id == assignedShopId))
              .toList();
          if (shopId != null && shops.every((shop) => shop.id != shopId)) shopId = null;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.instance.stream('products'),
            builder: (context, productSnapshot) {
              if (productSnapshot.hasError) return Center(child: Text('Error loading products: ${productSnapshot.error}'));
              if (!productSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              final products = (productSnapshot.data ?? [])
                  .map((data) => Product.fromMap(data['id'].toString(), data))
                  .where((product) => product.active)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Align(alignment: Alignment.centerLeft, child: Text('Sales Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                              if (selected != null && mounted) setState(() => date = selected);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                              child: Text('${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: shopId,
                            items: shops.map((shop) => DropdownMenuItem(value: shop.id, child: Text(shop.name))).toList(),
                            onChanged: retailUser || saving ? null : (value) => setState(() => shopId = value),
                            decoration: InputDecoration(labelText: 'Retail Shop', border: const OutlineInputBorder(), helperText: retailUser ? 'Assigned shop' : null),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              FilledButton.tonalIcon(onPressed: saving ? null : () => setState(() => rows.add(_SaleRow())), icon: const Icon(Icons.add), label: const Text('Add Item')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(rows.length, (index) {
                            final row = rows[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  children: [
                                    DropdownButtonFormField<String>(
                                      initialValue: row.productId,
                                      items: products.map((product) => DropdownMenuItem(value: product.id, child: Text(product.name))).toList(),
                                      onChanged: saving ? null : (value) => setState(() => row.productId = value),
                                      decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(child: TextField(controller: row.qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))),
                                        const SizedBox(width: 10),
                                        Expanded(child: TextField(controller: row.rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate', prefixText: '₹ ', border: OutlineInputBorder()))),
                                        if (rows.length > 1)
                                          IconButton(onPressed: saving ? null : () { final removed = rows.removeAt(index); removed.dispose(); setState(() {}); }, icon: const Icon(Icons.delete_outline)),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    AnimatedBuilder(
                                      animation: Listenable.merge([row.qty, row.rate]),
                                      builder: (context, child) => Align(alignment: Alignment.centerRight, child: Text('Amount: ₹${(_number(row.qty.text) * _number(row.rate.text)).toStringAsFixed(2)}')),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  _summary(shops),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: saving ? null : () => _save(products, shops),
                      icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                      label: Text(saving ? 'SAVING...' : (editingId == null ? 'SAVE SALES' : 'UPDATE SALES')),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Sales Transactions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  StreamBuilder<List<Sale>>(
                    stream: SalesService.instance.watchSales(),
                    builder: (context, historySnapshot) {
                      if (historySnapshot.hasError) return Text('Error loading sales: ${historySnapshot.error}');
                      if (!historySnapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
                      final sales = historySnapshot.data ?? [];
                      if (sales.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No sales transactions found.'));
                      return Column(
                        children: sales.map((sale) => Card(
                          child: ListTile(
                            title: Text(sale.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Net ₹${sale.netAmount.toStringAsFixed(2)} • Paid ₹${sale.paymentReceived.toStringAsFixed(2)} • Outstanding ₹${sale.outstanding.toStringAsFixed(2)}'),
                            trailing: Wrap(children: [
                              IconButton(onPressed: saving ? null : () => _edit(sale), icon: const Icon(Icons.edit_outlined)),
                              IconButton(onPressed: saving ? null : () => _delete(sale), icon: const Icon(Icons.delete_outline)),
                            ]),
                          ),
                        )).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
