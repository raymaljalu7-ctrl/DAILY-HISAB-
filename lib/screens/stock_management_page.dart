import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/retail_shop.dart';
import '../services/firestore_service.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});
  @override State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  int tab = 0;
  String? transferProduct, transferShop, receivedProduct, receivedShop;
  final transferQty = TextEditingController();
  final receivedQty = TextEditingController();
  final receivedSource = TextEditingController();
  final transferNote = TextEditingController();

  @override
  void dispose() {
    transferQty.dispose(); receivedQty.dispose(); receivedSource.dispose(); transferNote.dispose(); super.dispose();
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  void _snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _saveTransfer(List<Product> products, List<RetailShop> shops) async {
    if (transferProduct == null || transferShop == null) { _snack('Select product and shop.'); return; }
    final qty = _num(transferQty.text);
    if (qty <= 0) { _snack('Enter quantity greater than zero.'); return; }
    final p = products.firstWhere((x) => x.id == transferProduct);
    final s = shops.firstWhere((x) => x.id == transferShop);
    await FirestoreService.instance.add('stockTransfers', {
      'date': Timestamp.fromDate(DateTime.now()), 'productId': p.id, 'productName': p.name,
      'shopId': s.id, 'shopName': s.name, 'quantity': qty, 'unit': 'Box', 'description': transferNote.text.trim(),
    });
    transferQty.clear(); transferNote.clear();
    setState(() { transferProduct = null; transferShop = null; });
    _snack('Stock transfer saved.');
  }

  Future<void> _saveReceived(List<Product> products, List<RetailShop> shops) async {
    if (receivedProduct == null || receivedShop == null) { _snack('Select product and shop.'); return; }
    final qty = _num(receivedQty.text);
    if (qty <= 0) { _snack('Enter quantity greater than zero.'); return; }
    final p = products.firstWhere((x) => x.id == receivedProduct);
    final s = shops.firstWhere((x) => x.id == receivedShop);
    await FirestoreService.instance.add('stockOtherReceived', {
      'date': Timestamp.fromDate(DateTime.now()), 'productId': p.id, 'productName': p.name,
      'shopId': s.id, 'shopName': s.name, 'quantity': qty, 'unit': 'Box', 'source': receivedSource.text.trim(),
    });
    receivedQty.clear(); receivedSource.clear();
    setState(() { receivedProduct = null; receivedShop = null; });
    _snack('Other received stock saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('products'),
        builder: (context, ps) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.instance.stream('retailShops'),
            builder: (context, ss) {
              if (ps.connectionState == ConnectionState.waiting || ss.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (ps.hasError || ss.hasError) return Center(child: Text('Unable to load stock setup.\n${ps.error ?? ss.error}'));
              final products = (ps.data ?? []).map((x) => Product.fromMap(x['id'].toString(), x)).where((x) => x.active).toList();
              final shops = (ss.data ?? []).map((x) => RetailShop.fromMap(x['id'].toString(), x)).where((x) => x.active).toList();
              Widget content;
              if (tab == 0) content = _overview(products, shops);
              else if (tab == 1) content = _transfer(products, shops);
              else content = _received(products, shops);
              return Column(children: [
                Padding(padding: const EdgeInsets.all(12), child: SegmentedButton<int>(
                  segments: const [ButtonSegment(value: 0, label: Text('STOCK')), ButtonSegment(value: 1, label: Text('TRANSFER')), ButtonSegment(value: 2, label: Text('OTHER RECEIVED'))],
                  selected: {tab}, onSelectionChanged: (v) => setState(() => tab = v.first),
                )),
                Expanded(child: content),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _overview(List<Product> products, List<RetailShop> shops) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('production'),
      builder: (context, prodSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService.instance.stream('stockTransfers'),
          builder: (context, transferSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreService.instance.stream('stockOtherReceived'),
              builder: (context, receivedSnap) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirestoreService.instance.stream('sales'),
                  builder: (context, salesSnap) {
                    if (!prodSnap.hasData || !transferSnap.hasData || !receivedSnap.hasData || !salesSnap.hasData) return const Center(child: CircularProgressIndicator());
                    final production = prodSnap.data!;
                    final transfers = transferSnap.data!;
                    final received = receivedSnap.data!;
                    final sales = salesSnap.data!;
                    double productionStock(String pid) {
                      var made = 0.0;
                      var moved = 0.0;
                      for (final x in production) { if (x['productId'] == pid) made += _num(x['quantity']); }
                      for (final x in transfers) { if (x['productId'] == pid) moved += _num(x['quantity']); }
                      return made - moved;
                    }
                    double shopStock(String sid, String pid) {
                      var movedIn = 0.0, otherIn = 0.0, sold = 0.0;
                      for (final x in transfers) { if (x['shopId'] == sid && x['productId'] == pid) movedIn += _num(x['quantity']); }
                      for (final x in received) { if (x['shopId'] == sid && x['productId'] == pid) otherIn += _num(x['quantity']); }
                      for (final x in sales) {
                        if (x['shopId'] != sid) continue;
                        final items = x['items'];
                        if (items is List) {
                          for (final item in items) { if (item is Map && item['productId'] == pid) sold += _num(item['quantity']); }
                        }
                      }
                      return movedIn + otherIn - sold;
                    }
                    return ListView(padding: const EdgeInsets.all(12), children: [
                      const Text('Production Unit Stock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final p in products) Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.factory_outlined)), title: Text(p.name), trailing: Text('${productionStock(p.id).toStringAsFixed(2)} Box', style: const TextStyle(fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 18),
                      const Text('Retail Shop Stock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final s in shops) Card(child: ExpansionTile(title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)), children: [for (final p in products) ListTile(title: Text(p.name), trailing: Text('${shopStock(s.id, p.id).toStringAsFixed(2)} Box'))])),
                    ]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _transfer(List<Product> products, List<RetailShop> shops) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Production Unit → Retail Shop', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: transferProduct, items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => setState(() => transferProduct = v), decoration: const InputDecoration(labelText: 'Product')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: transferShop, items: shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(), onChanged: (v) => setState(() => transferShop = v), decoration: const InputDecoration(labelText: 'Retail Shop')),
      const SizedBox(height: 12),
      TextField(controller: transferQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Box')),
      const SizedBox(height: 12),
      TextField(controller: transferNote, decoration: const InputDecoration(labelText: 'Note')),
      const SizedBox(height: 18),
      SizedBox(height: 50, child: FilledButton.icon(onPressed: () => _saveTransfer(products, shops), icon: const Icon(Icons.local_shipping_outlined), label: const Text('SAVE TRANSFER'))),
    ]);
  }

  Widget _received(List<Product> products, List<RetailShop> shops) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('Retail Shop Other Received', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: receivedProduct, items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => setState(() => receivedProduct = v), decoration: const InputDecoration(labelText: 'Product')),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(initialValue: receivedShop, items: shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(), onChanged: (v) => setState(() => receivedShop = v), decoration: const InputDecoration(labelText: 'Retail Shop')),
      const SizedBox(height: 12),
      TextField(controller: receivedQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Box')),
      const SizedBox(height: 12),
      TextField(controller: receivedSource, decoration: const InputDecoration(labelText: 'Source / Supplier')),
      const SizedBox(height: 18),
      SizedBox(height: 50, child: FilledButton.icon(onPressed: () => _saveReceived(products, shops), icon: const Icon(Icons.add_box_outlined), label: const Text('SAVE OTHER RECEIVED'))),
    ]);
  }
}
