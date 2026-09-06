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
  String? transferProduct;
  String? transferShop;
  String? receivedProduct;
  String? receivedShop;
  final transferQty = TextEditingController();
  final receivedQty = TextEditingController();
  final receivedSource = TextEditingController();
  final transferNote = TextEditingController();

  @override
  void dispose() { transferQty.dispose(); receivedQty.dispose(); receivedSource.dispose(); transferNote.dispose(); super.dispose(); }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  DateTime _date(dynamic v) => v is Timestamp ? v.toDate() : DateTime.tryParse('$v') ?? DateTime.now();

  Future<void> _saveTransfer(List<Product> products, List<RetailShop> shops) async {
    if (transferProduct == null || transferShop == null) { _snack('Select product and shop.'); return; }
    final qty = _num(transferQty.text); if (qty <= 0) { _snack('Enter quantity greater than zero.'); return; }
    final p = products.firstWhere((x) => x.id == transferProduct);
    final s = shops.firstWhere((x) => x.id == transferShop);
    await FirestoreService.instance.add('stockTransfers', {'date': Timestamp.fromDate(DateTime.now()),'productId':p.id,'productName':p.name,'shopId':s.id,'shopName':s.name,'quantity':qty,'unit':'Box','description':transferNote.text.trim()});
    transferQty.clear(); transferNote.clear(); setState(() { transferProduct=null; transferShop=null; }); _snack('Stock transfer saved. Production Unit stock decreased and shop stock increased.');
  }

  Future<void> _saveReceived(List<Product> products, List<RetailShop> shops) async {
    if (receivedProduct == null || receivedShop == null) { _snack('Select product and shop.'); return; }
    final qty = _num(receivedQty.text); if (qty <= 0) { _snack('Enter quantity greater than zero.'); return; }
    final p = products.firstWhere((x) => x.id == receivedProduct);
    final s = shops.firstWhere((x) => x.id == receivedShop);
    await FirestoreService.instance.add('stockOtherReceived', {'date':Timestamp.fromDate(DateTime.now()),'productId':p.id,'productName':p.name,'shopId':s.id,'shopName':s.name,'quantity':qty,'unit':'Box','source':receivedSource.text.trim()});
    receivedQty.clear(); receivedSource.clear(); setState(() { receivedProduct=null; receivedShop=null; }); _snack('Other received stock saved.');
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Stock Management')),
    body: StreamBuilder<List<Map<String,dynamic>>>(stream: FirestoreService.instance.stream('products'), builder: (context, ps) {
      return StreamBuilder<List<Map<String,dynamic>>>(stream: FirestoreService.instance.stream('retailShops'), builder: (context, ss) {
        if (ps.connectionState == ConnectionState.waiting || ss.connectionState == ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
        final products=(ps.data??[]).map((x)=>Product.fromMap(x['id'].toString(),x)).where((x)=>x.active).toList();
        final shops=(ss.data??[]).map((x)=>RetailShop.fromMap(x['id'].toString(),x)).where((x)=>x.active).toList();
        return Column(children:[
          Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<int>(segments:const [ButtonSegment(value:0,label:Text('STOCK')),ButtonSegment(value:1,label:Text('TRANSFER')),ButtonSegment(value:2,label:Text('OTHER RECEIVED'))],selected:{tab},onSelectionChanged:(v)=>setState(()=>tab=v.first))),
          Expanded(child: tab==0 ? _overview(products,shops) : tab==1 ? _transfer(products,shops) : _received(products,shops)),
        ]);
      });
    }),
  );

  Widget _overview(List<Product> products,List<RetailShop> shops) => StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('production'),builder:(context,prodSnap)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('stockTransfers'),builder:(context,trSnap)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('stockOtherReceived'),builder:(context,orSnap)=>StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('sales'),builder:(context,salesSnap){
    final production=prodSnap.data??[]; final transfers=trSnap.data??[]; final received=orSnap.data??[]; final sales=salesSnap.data??[];
    double prodStock(String pid){final made=production.where((x)=>x['productId']==pid).fold(0.0,(s,x)=>s+_num(x['quantity']));final out=transfers.where((x)=>x['productId']==pid).fold(0.0,(s,x)=>s+_num(x['quantity']));return made-out;}
    double shopStock(String sid,String pid){final inTransfer=transfers.where((x)=>x['shopId']==sid&&x['productId']==pid).fold(0.0,(s,x)=>s+_num(x['quantity']));final other=received.where((x)=>x['shopId']==sid&&x['productId']==pid).fold(0.0,(s,x)=>s+_num(x['quantity']));final sold=sales.where((x)=>x['shopId']==sid).fold(0.0,(s,x){final items=(x['items'] as List?)??[];return s+items.whereType<Map>().where((i)=>i['productId']==pid).fold(0.0,(a,i)=>a+_num(i['quantity']));});return inTransfer+other-sold;}
    return ListView(padding:const EdgeInsets.all(12),children:[const Text('Production Unit Stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:8),...products.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.factory_outlined)),title:Text(p.name),trailing:Text('${prodStock(p.id).toStringAsFixed(2)} Box',style:const TextStyle(fontWeight:FontWeight.bold))))),const SizedBox(height:18),const Text('Retail Shop Stock',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:8),...shops.map((s)=>Card(child:ExpansionTile(title:Text(s.name,style:const TextStyle(fontWeight:FontWeight.bold)),children:products.map((p)=>ListTile(title:Text(p.name),trailing:Text('${shopStock(s.id,p.id).toStringAsFixed(2)} Box'))).toList()))),const SizedBox(height:20),const Text('Stock rule: Production adds only to Production Unit. Transfers move stock to a shop. Retail sales reduce only that shop. Other Received increases only that shop.',style:TextStyle(fontSize:13))]);
  })))));

  Widget _transfer(List<Product> products,List<RetailShop> shops) => ListView(padding:const EdgeInsets.all(12),children:[const Text('Production Unit → Retail Shop',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('This is a stock transfer, not a customer sale.'),const SizedBox(height:14),DropdownButtonFormField<String>(initialValue:transferProduct,items:products.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name))).toList(),onChanged:(v)=>setState(()=>transferProduct=v),decoration:const InputDecoration(labelText:'Product')),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:transferShop,items:shops.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name))).toList(),onChanged:(v)=>setState(()=>transferShop=v),decoration:const InputDecoration(labelText:'Retail Shop')),const SizedBox(height:12),TextField(controller:transferQty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity',suffixText:'Box')),const SizedBox(height:12),TextField(controller:transferNote,decoration:const InputDecoration(labelText:'Note')),const SizedBox(height:18),SizedBox(height:50,child:FilledButton.icon(onPressed:()=>_saveTransfer(products,shops),icon:const Icon(Icons.local_shipping_outlined),label:const Text('SAVE TRANSFER'))]);

  Widget _received(List<Product> products,List<RetailShop> shops) => ListView(padding:const EdgeInsets.all(12),children:[const Text('Retail Shop Other Received',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('Adds stock directly to the selected shop. It does not reduce Production Unit stock.'),const SizedBox(height:14),DropdownButtonFormField<String>(initialValue:receivedProduct,items:products.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name))).toList(),onChanged:(v)=>setState(()=>receivedProduct=v),decoration:const InputDecoration(labelText:'Product')),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:receivedShop,items:shops.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name))).toList(),onChanged:(v)=>setState(()=>receivedShop=v),decoration:const InputDecoration(labelText:'Retail Shop')),const SizedBox(height:12),TextField(controller:receivedQty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity',suffixText:'Box')),const SizedBox(height:12),TextField(controller:receivedSource,decoration:const InputDecoration(labelText:'Source / Supplier')),const SizedBox(height:18),SizedBox(height:50,child:FilledButton.icon(onPressed:()=>_saveReceived(products,shops),icon:const Icon(Icons.add_box_outlined),label:const Text('SAVE OTHER RECEIVED'))]);
}
