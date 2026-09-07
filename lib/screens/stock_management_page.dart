import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({super.key});
  @override State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  int tab = 0;
  String? productId, shopId;
  final qty = TextEditingController();
  final note = TextEditingController();
  final source = TextEditingController();
  double n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  @override void dispose() { qty.dispose(); note.dispose(); source.dispose(); super.dispose(); }
  void snack(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> saveRecord(String collection, List<Map<String,dynamic>> products, List<Map<String,dynamic>> shops) async {
    if (productId == null) { snack('Select product.'); return; }
    if (collection != 'stockOpening' && shopId == null) { snack('Select retail shop.'); return; }
    final q = n(qty.text); if (q <= 0) { snack('Enter quantity greater than zero.'); return; }
    final p = products.where((x) => x['id'].toString() == productId).firstOrNull;
    if (p == null) { snack('Product not found.'); return; }
    final data = <String,dynamic>{'date':Timestamp.fromDate(DateTime.now()),'productId':productId,'productName':p['name']?.toString() ?? 'Product','quantity':q,'unit':'Box'};
    if (collection == 'stockOpening') {
      data['locationType'] = shopId == null ? 'production' : 'retail';
      if (shopId != null) { final s = shops.where((x) => x['id'].toString() == shopId).firstOrNull; data['shopId'] = shopId; data['shopName'] = s?['name']?.toString() ?? 'Shop'; }
    } else {
      final s = shops.where((x) => x['id'].toString() == shopId).firstOrNull;
      if (s == null) { snack('Retail shop not found.'); return; }
      data['shopId'] = shopId; data['shopName'] = s['name']?.toString() ?? 'Shop';
      if (collection == 'stockTransfers') data['description'] = note.text.trim();
      if (collection == 'stockOtherReceived') data['source'] = source.text.trim();
    }
    await FirestoreService.instance.add(collection, data);
    qty.clear(); note.clear(); source.clear(); setState(() { productId = null; shopId = null; });
    snack(collection == 'stockOpening' ? 'Opening stock saved.' : collection == 'stockTransfers' ? 'Stock transfer saved.' : 'Other received stock saved.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Stock Management')), body: StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('products'),builder:(context,ps)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('retailShops'),builder:(context,ss){
    if(ps.connectionState==ConnectionState.waiting||ss.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
    if(ps.hasError||ss.hasError)return Center(child:Text('Unable to load stock setup.\n${ps.error??ss.error}'));
    final products=(ps.data??[]).where((x)=>x['active']!=false).toList(); final shops=(ss.data??[]).where((x)=>x['active']!=false).toList();
    return Column(children:[Padding(padding:const EdgeInsets.all(12),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<int>(segments:const[ButtonSegment(value:0,label:Text('STOCK')),ButtonSegment(value:1,label:Text('OPENING')),ButtonSegment(value:2,label:Text('TRANSFER')),ButtonSegment(value:3,label:Text('OTHER RECEIVED'))],selected:{tab},onSelectionChanged:(v)=>setState(()=>tab=v.first)))),Expanded(child:tab==0?overview(products,shops):entry(products,shops))]);
  })));

  Widget entry(List<Map<String,dynamic>> products,List<Map<String,dynamic>> shops){
    final opening=tab==1, transfer=tab==2;
    return ListView(padding:const EdgeInsets.all(12),children:[Text(opening?'Opening Stock':transfer?'Production Unit → Retail Shop':'Retail Shop Other Received',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:14),
      DropdownButtonFormField<String>(initialValue:productId,decoration:const InputDecoration(labelText:'Product',border:OutlineInputBorder()),items:products.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['name']?.toString()??'Product'))).toList(),onChanged:(v)=>setState(()=>productId=v)),const SizedBox(height:12),
      if(opening) ...[DropdownButtonFormField<String?>(initialValue:shopId,decoration:const InputDecoration(labelText:'Location',border:OutlineInputBorder()),items:[const DropdownMenuItem<String?>(value:null,child:Text('Production Unit')),...shops.map((s)=>DropdownMenuItem<String?>(value:s['id'].toString(),child:Text(s['name']?.toString()??'Shop')))],onChanged:(v)=>setState(()=>shopId=v)),const SizedBox(height:12)] else ...[DropdownButtonFormField<String>(initialValue:shopId,decoration:const InputDecoration(labelText:'Retail Shop',border:OutlineInputBorder()),items:shops.map((s)=>DropdownMenuItem(value:s['id'].toString(),child:Text(s['name']?.toString()??'Shop'))).toList(),onChanged:(v)=>setState(()=>shopId=v)),const SizedBox(height:12)],
      TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity',suffixText:'Box',border:OutlineInputBorder())),const SizedBox(height:12),
      if(transfer)TextField(controller:note,decoration:const InputDecoration(labelText:'Note',border:OutlineInputBorder())) else if(!opening)TextField(controller:source,decoration:const InputDecoration(labelText:'Source / Supplier',border:OutlineInputBorder())),
      const SizedBox(height:18),SizedBox(height:50,child:FilledButton.icon(onPressed:()=>saveRecord(opening?'stockOpening':transfer?'stockTransfers':'stockOtherReceived',products,shops),icon:Icon(opening?Icons.inventory_2_outlined:transfer?Icons.local_shipping_outlined:Icons.add_box_outlined),label:Text(opening?'SAVE OPENING STOCK':transfer?'SAVE TRANSFER':'SAVE OTHER RECEIVED')))
    ]);
  }

  Widget overview(List<Map<String,dynamic>> products,List<Map<String,dynamic>> shops){
    return StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('stockOpening'),builder:(context,os)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('production'),builder:(context,ps)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('stockTransfers'),builder:(context,ts)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('stockOtherReceived'),builder:(context,rs)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('sales'),builder:(context,ss){
      if(!os.hasData||!ps.hasData||!ts.hasData||!rs.hasData||!ss.hasData)return const Center(child:CircularProgressIndicator());
      final opening=os.data!,production=ps.data!,transfers=ts.data!,received=rs.data!,sales=ss.data!;
      double openingUnit(String pid){var v=0.0;for(final x in opening)if(x['productId']==pid&&x['locationType']=='production')v+=n(x['quantity']);return v;}
      double made(String pid){var v=0.0;for(final x in production)if(x['productId']==pid)v+=n(x['quantity']);return v;}
      double movedOut(String pid){var v=0.0;for(final x in transfers)if(x['productId']==pid)v+=n(x['quantity']);return v;}
      double shopOpening(String sid,String pid){var v=0.0;for(final x in opening)if(x['productId']==pid&&x['locationType']=='retail'&&x['shopId']==sid)v+=n(x['quantity']);return v;}
      double shopIn(String sid,String pid){var v=0.0;for(final x in transfers)if(x['productId']==pid&&x['shopId']==sid)v+=n(x['quantity']);for(final x in received)if(x['productId']==pid&&x['shopId']==sid)v+=n(x['quantity']);return v;}
      double sold(String sid,String pid){var v=0.0;for(final x in sales)if(x['shopId']==sid&&x['items'] is List)for(final i in (x['items'] as List))if(i is Map&&i['productId']==pid)v+=n(i['quantity']);return v;}
      double unitClosing(String pid){return openingUnit(pid)+made(pid)-movedOut(pid);}
      double shopClosing(String sid,String pid)=>shopOpening(sid,pid)+shopIn(sid,pid)-sold(sid,pid);
      double totalFor(String pid)=>unitClosing(pid)+shops.fold(0.0,(a,s)=>a+shopClosing(s['id'].toString(),pid));
      final unitTotal=products.fold(0.0,(a,p)=>a+unitClosing(p['id'].toString())); final retailTotal=shops.fold(0.0,(a,s)=>a+products.fold(0.0,(b,p)=>b+shopClosing(s['id'].toString(),p['id'].toString()))); final grand=unitTotal+retailTotal;
      return ListView(padding:const EdgeInsets.all(12),children:[
        Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Total Stock Summary',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text('Production Unit Closing: ${unitTotal.toStringAsFixed(2)} Box'),Text('All Retail Shops Closing: ${retailTotal.toStringAsFixed(2)} Box'),const Divider(),Text('Total Business Stock: ${grand.toStringAsFixed(2)} Box',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))]))),
        const SizedBox(height:14),const Text('Production Unit Stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:6),
        for(final p in products)Card(child:ListTile(title:Text(p['name']?.toString()??'Product'),subtitle:Text('Opening + Production − Transfers'),trailing:Text('${unitClosing(p['id'].toString()).toStringAsFixed(2)} Box',style:const TextStyle(fontWeight:FontWeight.bold)))),
        const SizedBox(height:14),const Text('Retail Shop Stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:6),
        for(final s in shops)Card(child:ExpansionTile(title:Text(s['name']?.toString()??'Shop'),subtitle:Text('Total: ${products.fold(0.0,(a,p)=>a+shopClosing(s['id'].toString(),p['id'].toString())).toStringAsFixed(2)} Box'),children:[for(final p in products)ListTile(title:Text(p['name']?.toString()??'Product'),subtitle:const Text('Opening + Received − Sales'),trailing:Text('${shopClosing(s['id'].toString(),p['id'].toString()).toStringAsFixed(2)} Box'))])),
        const SizedBox(height:14),const Text('Item-wise Total Stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:6),
        for(final p in products)Card(child:ListTile(title:Text(p['name']?.toString()??'Product'),trailing:Text('${totalFor(p['id'].toString()).toStringAsFixed(2)} Box',style:const TextStyle(fontWeight:FontWeight.bold)))),
      ]);
    }))));
  }
}
