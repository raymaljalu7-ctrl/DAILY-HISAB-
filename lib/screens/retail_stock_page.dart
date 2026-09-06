import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RetailStockPage extends StatelessWidget {
  const RetailStockPage({super.key});

  DocumentReference<Map<String, dynamic>> _db() => FirebaseFirestore.instance.collection('sharedData').doc('dailyHisab');

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please login again.')));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final profile = userSnap.data!.data() ?? {};
        final shopId = profile['shopId']?.toString();
        final shopName = profile['shopName']?.toString() ?? 'Assigned Shop';
        if (shopId == null || shopId.isEmpty) return const Scaffold(body: Center(child: Text('No retail shop is assigned to this user.')));
        return Scaffold(
          appBar: AppBar(title: Text('$shopName Stock')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db().collection('products').snapshots(),
            builder: (context, productSnap) {
              if (productSnap.hasError) return Center(child: Text('Unable to load products:\n${productSnap.error}'));
              if (!productSnap.hasData) return const Center(child: CircularProgressIndicator());
              final products = productSnap.data!.docs.where((d) => d.data()['active'] != false).toList();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db().collection('stockTransfers').where('shopId', isEqualTo: shopId).snapshots(),
                builder: (context, transferSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db().collection('stockOtherReceived').where('shopId', isEqualTo: shopId).snapshots(),
                  builder: (context, receivedSnap) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db().collection('sales').where('shopId', isEqualTo: shopId).snapshots(),
                    builder: (context, salesSnap) {
                      if (transferSnap.hasError || receivedSnap.hasError || salesSnap.hasError) return Center(child: Text('Unable to load shop stock.\n${transferSnap.error ?? receivedSnap.error ?? salesSnap.error}'));
                      if (!transferSnap.hasData || !receivedSnap.hasData || !salesSnap.hasData) return const Center(child: CircularProgressIndicator());
                      final transfers = transferSnap.data!.docs.map((d) => d.data()).toList();
                      final received = receivedSnap.data!.docs.map((d) => d.data()).toList();
                      final sales = salesSnap.data!.docs.map((d) => d.data()).toList();
                      double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
                      return ListView(padding: const EdgeInsets.all(16), children: [
                        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.store)), title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Only your assigned shop stock is shown.'))),
                        const SizedBox(height: 12),
                        ...products.map((d) {
                          final p = d.data(); final pid = d.id;
                          final incoming = transfers.where((x) => x['productId'] == pid).fold<double>(0, (s, x) => s + n(x['quantity']));
                          final other = received.where((x) => x['productId'] == pid).fold<double>(0, (s, x) => s + n(x['quantity']));
                          final sold = sales.fold<double>(0, (s, x) { final items = (x['items'] as List?) ?? []; return s + items.whereType<Map>().where((i) => i['productId'] == pid).fold<double>(0, (a, i) => a + n(i['quantity'])); });
                          final stock = incoming + other - sold;
                          return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)), title: Text(p['name']?.toString() ?? pid), subtitle: Text('Received: ${incoming.toStringAsFixed(2)}  •  Other: ${other.toStringAsFixed(2)}  •  Sold: ${sold.toStringAsFixed(2)}'), trailing: Text('${stock.toStringAsFixed(2)} Box', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));
                        }),
                      ]);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
