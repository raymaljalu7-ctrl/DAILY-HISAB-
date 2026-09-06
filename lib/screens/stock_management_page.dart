import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});
  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  int tab = 0;
  String? productId;
  String? shopId;
  final qty = TextEditingController();
  final note = TextEditingController();
  final source = TextEditingController();

  double numValue(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  @override
  void dispose() {
    qty.dispose();
    note.dispose();
    source.dispose();
    super.dispose();
  }

  void snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> saveRecord(String collection, List<Map<String, dynamic>> products, List<Map<String, dynamic>> shops) async {
    if (productId == null || shopId == null) {
      snack('Select product and retail shop.');
      return;
    }
    final quantity = numValue(qty.text);
    if (quantity <= 0) {
      snack('Enter quantity greater than zero.');
      return;
    }
    Map<String, dynamic>? product;
    Map<String, dynamic>? shop;
    for (final p in products) {
      if (p['id'].toString() == productId) product = p;
    }
    for (final s in shops) {
      if (s['id'].toString() == shopId) shop = s;
    }
    if (product == null || shop == null) {
      snack('Selected product or shop was not found.');
      return;
    }
    final data = <String, dynamic>{
      'date': Timestamp.fromDate(DateTime.now()),
      'productId': productId,
      'productName': product['name']?.toString() ?? 'Product',
      'shopId': shopId,
      'shopName': shop['name']?.toString() ?? 'Shop',
      'quantity': quantity,
      'unit': 'Box',
    };
    if (collection == 'stockTransfers') data['description'] = note.text.trim();
    if (collection == 'stockOtherReceived') data['source'] = source.text.trim();
    await FirestoreService.instance.add(collection, data);
    qty.clear();
    note.clear();
    source.clear();
    setState(() {
      productId = null;
      shopId = null;
    });
    snack(collection == 'stockTransfers' ? 'Stock transfer saved.' : 'Other received stock saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('products'),
        builder: (context, productSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.instance.stream('retailShops'),
            builder: (context, shopSnap) {
              if (productSnap.connectionState == ConnectionState.waiting || shopSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (productSnap.hasError || shopSnap.hasError) {
                return Center(child: Text('Unable to load stock setup.\n${productSnap.error ?? shopSnap.error}'));
              }
              final products = (productSnap.data ?? []).where((p) => p['active'] != false).toList();
              final shops = (shopSnap.data ?? []).where((s) => s['active'] != false).toList();
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('STOCK')),
                        ButtonSegment(value: 1, label: Text('TRANSFER')),
                        ButtonSegment(value: 2, label: Text('OTHER RECEIVED')),
                      ],
                      selected: {tab},
                      onSelectionChanged: (values) => setState(() => tab = values.first),
                    ),
                  ),
                  Expanded(child: tab == 0 ? buildOverview(products, shops) : buildEntry(products, shops)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget buildEntry(List<Map<String, dynamic>> products, List<Map<String, dynamic>> shops) {
    final transfer = tab == 1;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(transfer ? 'Production Unit → Retail Shop' : 'Retail Shop Other Received', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: productId,
          decoration: const InputDecoration(labelText: 'Product'),
          items: products.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text(p['name']?.toString() ?? 'Product'))).toList(),
          onChanged: (value) => setState(() => productId = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: shopId,
          decoration: const InputDecoration(labelText: 'Retail Shop'),
          items: shops.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text(s['name']?.toString() ?? 'Shop'))).toList(),
          onChanged: (value) => setState(() => shopId = value),
        ),
        const SizedBox(height: 12),
        TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', suffixText: 'Box')),
        const SizedBox(height: 12),
        TextField(controller: transfer ? note : source, decoration: InputDecoration(labelText: transfer ? 'Note' : 'Source / Supplier')),
        const SizedBox(height: 18),
        SizedBox(height: 50, child: FilledButton.icon(
          onPressed: () => saveRecord(transfer ? 'stockTransfers' : 'stockOtherReceived', products, shops),
          icon: Icon(transfer ? Icons.local_shipping_outlined : Icons.add_box_outlined),
          label: Text(transfer ? 'SAVE TRANSFER' : 'SAVE OTHER RECEIVED'),
        )),
      ],
    );
  }

  Widget buildOverview(List<Map<String, dynamic>> products, List<Map<String, dynamic>> shops) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('production'),
      builder: (context, productionSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirestoreService.instance.stream('stockTransfers'),
          builder: (context, transferSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreService.instance.stream('stockOtherReceived'),
              builder: (context, receivedSnap) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirestoreService.instance.stream('sales'),
                  builder: (context, salesSnap) {
                    if (!productionSnap.hasData || !transferSnap.hasData || !receivedSnap.hasData || !salesSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final production = productionSnap.data!;
                    final transfers = transferSnap.data!;
                    final received = receivedSnap.data!;
                    final sales = salesSnap.data!;
                    double unitStock(String pid) {
                      var made = 0.0;
                      var moved = 0.0;
                      for (final x in production) if (x['productId'] == pid) made += numValue(x['quantity']);
                      for (final x in transfers) if (x['productId'] == pid) moved += numValue(x['quantity']);
                      return made - moved;
                    }
                    double shopStock(String sid, String pid) {
                      var incoming = 0.0;
                      var other = 0.0;
                      var sold = 0.0;
                      for (final x in transfers) if (x['shopId'] == sid && x['productId'] == pid) incoming += numValue(x['quantity']);
                      for (final x in received) if (x['shopId'] == sid && x['productId'] == pid) other += numValue(x['quantity']);
                      for (final x in sales) {
                        if (x['shopId'] != sid || x['items'] is! List) continue;
                        for (final item in (x['items'] as List)) {
                          if (item is Map && item['productId'] == pid) sold += numValue(item['quantity']);
                        }
                      }
                      return incoming + other - sold;
                    }
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Text('Production Unit Stock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        for (final p in products) Card(child: ListTile(title: Text(p['name']?.toString() ?? 'Product'), trailing: Text('${unitStock(p['id'].toString()).toStringAsFixed(2)} Box'))),
                        const SizedBox(height: 18),
                        const Text('Retail Shop Stock', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        for (final s in shops) Card(child: ExpansionTile(title: Text(s['name']?.toString() ?? 'Shop'), children: [for (final p in products) ListTile(title: Text(p['name']?.toString() ?? 'Product'), trailing: Text('${shopStock(s['id'].toString(), p['id'].toString()).toStringAsFixed(2)} Box'))])),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
