import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RetailStockPage extends StatefulWidget {
  const RetailStockPage({super.key});
  @override State<RetailStockPage> createState() => _RetailStockPageState();
}

class _RetailStockPageState extends State<RetailStockPage> {
  final db = FirebaseFirestore.instance;
  bool loading = true;
  String? error;
  bool retailUser = false;
  String? assignedShopId;
  String? assignedShopName;
  List<Map<String,dynamic>> products = [], shops = [], production = [], transfers = [], received = [], sales = [];

  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  String name(Map<String,dynamic> x) => x['name']?.toString() ?? x['productName']?.toString() ?? x['id']?.toString() ?? 'Product';

  @override void initState() { super.initState(); _load(); }

  Future<List<Map<String,dynamic>>> _all(String collection, {String? shopId}) async {
    Query<Map<String,dynamic>> q = db.collection('sharedData').doc('dailyHisab').collection(collection);
    if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
    final s = await q.get();
    return s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Please login again.');
      final profile = (await db.collection('users').doc(uid).get()).data() ?? {};
      final role = profile['role']?.toString() ?? '';
      final shopId = profile['shopId']?.toString();
      final isRetail = role == 'retail_shop_user';
      final shopName = profile['shopName']?.toString();
      final p = await _all('products');
      final activeProducts = p.where((x) => x['active'] != false).toList();
      if (isRetail && (shopId == null || shopId.isEmpty)) throw StateError('No retail shop is assigned to this user.');
      final shopList = isRetail ? (await _all('retailShops')).where((x) => x['id'].toString() == shopId).toList() : await _all('retailShops');
      final prod = isRetail ? <Map<String,dynamic>>[] : await _all('production');
      final tr = isRetail ? await _all('stockTransfers', shopId: shopId) : await _all('stockTransfers');
      final rc = isRetail ? await _all('stockOtherReceived', shopId: shopId) : await _all('stockOtherReceived');
      final sl = isRetail ? await _all('sales', shopId: shopId) : await _all('sales');
      if (!mounted) return;
      setState(() { retailUser=isRetail; assignedShopId=shopId; assignedShopName=shopName; products=activeProducts; shops=shopList; production=prod; transfers=tr; received=rc; sales=sl; loading=false; });
    } catch (e) { if (mounted) setState(() { error = '$e'; loading=false; }); }
  }

  double _productionStock(String pid) {
    final made = production.where((x) => x['productId']?.toString() == pid).fold(0.0, (s,x) => s+n(x['quantity']));
    final moved = transfers.where((x) => x['productId']?.toString() == pid).fold(0.0, (s,x) => s+n(x['quantity']));
    return made - moved;
  }
  double _shopStock(String pid, String sid) {
    final incoming = transfers.where((x) => x['productId']?.toString()==pid && x['shopId']?.toString()==sid).fold(0.0,(s,x)=>s+n(x['quantity']));
    final other = received.where((x) => x['productId']?.toString()==pid && x['shopId']?.toString()==sid).fold(0.0,(s,x)=>s+n(x['quantity']));
    final sold = sales.where((x)=>x['shopId']?.toString()==sid).fold(0.0,(s,x){ final items=x['items']; if(items is! List)return s; return s+items.whereType<Map>().where((i)=>i['productId']?.toString()==pid).fold(0.0,(a,i)=>a+n(i['quantity'])); });
    return incoming+other-sold;
  }

  Widget _productCard(String pid, String title, double stock, String detail) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)), title: Text(title), subtitle: Text(detail), trailing: Text('${stock.toStringAsFixed(2)} Box', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))));

  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(appBar: AppBar(title: const Text('Stock Management')), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline,size:48), const SizedBox(height:12), Text(error!,textAlign:TextAlign.center), const SizedBox(height:12), FilledButton.icon(onPressed:_load,icon:const Icon(Icons.refresh),label:const Text('RETRY'))]))));
    final shopIds = shops.map((s)=>s['id'].toString()).toList();
    return Scaffold(appBar: AppBar(title: const Text('Stock Management'), actions: [IconButton(onPressed:loading?null:_load, icon:const Icon(Icons.refresh))]), body: RefreshIndicator(onRefresh:_load, child: ListView(padding:const EdgeInsets.all(16), children: [
      if (retailUser) ...[
        Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.store)),title:Text(assignedShopName??'Retail Shop',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Only your assigned retail shop stock is shown.'))),
        const SizedBox(height:12),
        const Text('Retail Shop Stock',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        ...products.map((p)=>_productCard(p['id'].toString(),name(p),_shopStock(p['id'].toString(),assignedShopId!), 'Received + Other Received − Sales')),
      ] else ...[
        const Card(child:ListTile(leading:CircleAvatar(child:Icon(Icons.factory_outlined)),title:Text('Production Unit Stock',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('Production made minus stock transferred to retail shops.'))),
        const SizedBox(height:10),
        ...products.map((p)=>_productCard(p['id'].toString(),name(p),_productionStock(p['id'].toString()),'Produced − Transferred')),
        const SizedBox(height:18),
        const Text('Retail Shops Stock',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        ...shops.map((s){ final sid=s['id'].toString(); final sn=s['name']?.toString()??sid; return Card(child:ExpansionTile(title:Text(sn,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Received + Other Received − Sales'),children:products.map((p)=>Padding(padding:const EdgeInsets.fromLTRB(12,0,12,8),child:_productCard(p['id'].toString(),name(p),_shopStock(p['id'].toString(),sid),'Current stock'))).toList())); }),
        if (shopIds.isEmpty) const Padding(padding:EdgeInsets.all(20),child:Text('No active retail shops found.')),
      ],
    ])));
  }
}
