import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsV2Page extends StatefulWidget {
  const ReportsV2Page({super.key});
  @override State<ReportsV2Page> createState() => _ReportsV2PageState();
}

class _ReportsV2PageState extends State<ReportsV2Page> {
  final db = FirebaseFirestore.instance;
  String report='Sales', period='Daily', stockScope='All';
  DateTime from=DateTime.now(), to=DateTime.now();
  bool loading=true, retailUser=false, admin=false;
  String? assignedShopId, assignedShopName, shopId, productId, error;
  List<Map<String,dynamic>> rows=[], shops=[], products=[];

  List<String> get types => retailUser
      ? const ['Sales','Receipt','Payments','Party Ledger','Expenses','Cash Management','Stock Management']
      : const ['Sales','Receipt','Payments','Outstanding','Commission','Production','Expenses','Salary','Capital','Stock Management','Cash Management','Profit/Loss'];
  CollectionReference<Map<String,dynamic>> col(String n) => db.collection('sharedData').doc('dailyHisab').collection(n);
  double numVal(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  DateTime dateVal(dynamic v) { if(v is Timestamp)return v.toDate(); if(v is DateTime)return v; return DateTime.tryParse('$v') ?? DateTime.fromMillisecondsSinceEpoch(0); }
  bool inRange(DateTime d) { final s=DateTime(from.year,from.month,from.day), e=DateTime(to.year,to.month,to.day,23,59,59); return !d.isBefore(s)&&!d.isAfter(e); }
  String dateText(DateTime d)=>'${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
  String money(dynamic v)=>'₹${numVal(v).toStringAsFixed(2)}';

  @override void initState(){super.initState();_initialize();}
  Future<void> _initialize() async {
    try {
      final uid=FirebaseAuth.instance.currentUser?.uid; if(uid==null) throw StateError('Please login again.');
      final u=(await db.collection('users').doc(uid).get()).data()??{};
      retailUser=u['role']=='retail_shop_user'; admin=u['role']=='admin'; assignedShopId=u['shopId']?.toString(); assignedShopName=u['shopName']?.toString();
      final ps=await col('products').get(); products=ps.docs.map((d)=>{'id':d.id,...d.data()}).where((x)=>x['active']!=false).toList();
      if(!retailUser){final ss=await col('retailShops').get();shops=ss.docs.map((d)=>{'id':d.id,...d.data()}).where((x)=>x['active']!=false).toList();}
      if(!types.contains(report))report=types.first; await _load();
    }catch(e){if(mounted)setState(()=>{error='$e';loading=false;});}
  }
  Future<List<Map<String,dynamic>>> fetch(String name,{String? shop}) async {
    Query<Map<String,dynamic>> q=col(name); if(retailUser&&shop!=null&&shop.isNotEmpty)q=q.where('shopId',isEqualTo:shop);
    final s=await q.get(); return s.docs.map((d)=>{'id':d.id,...d.data()}).where((x)=>inRange(dateVal(x['date']))).toList();
  }
  void changePeriod(String v){final n=DateTime.now();DateTime s=n,e=n;if(v=='Monthly'){s=DateTime(n.year,n.month,1);e=DateTime(n.year,n.month+1,0);}else if(v=='Quarterly'){final m=((n.month-1)~/3)*3+1;s=DateTime(n.year,m,1);e=DateTime(n.year,m+3,0);}else if(v=='6 Monthly'){final m=n.month<=6?1:7;s=DateTime(n.year,m,1);e=DateTime(n.year,m+6,0);}else if(v=='Yearly'){s=DateTime(n.year,1,1);e=DateTime(n.year,12,31);}setState(()=>{period=v;from=s;to=e;});_load();}
  Future<void> _load() async {
    if(!mounted)return;setState(()=>{loading=true;error=null;});
    try{
      List<Map<String,dynamic>> r=[];
      if(report=='Sales'||report=='Outstanding'||report=='Commission'){
        r=await fetch('sales',shop:assignedShopId);
        if(!retailUser&&shopId!=null&&shopId!.isNotEmpty)r=r.where((x)=>x['shopId']?.toString()==shopId).toList();
        if(productId!=null&&productId!.isNotEmpty)r=r.where((x){final it=x['items'];return it is List&&it.any((i)=>i is Map&&i['productId']?.toString()==productId);}).toList();
        if(report=='Outstanding')r=r.where((x)=>numVal(x['outstanding'])>0).toList();
      }else if(report=='Receipt'||report=='Payments'||report=='Party Ledger'){
        r=await fetch('transactions',shop:assignedShopId);if(report=='Receipt')r=r.where((x)=>x['type']=='Receipt').toList();if(report=='Payments')r=r.where((x)=>x['type']=='Payment').toList();if(report=='Party Ledger')r=r.where((x)=>(x['partyId']?.toString()??'').isNotEmpty).map((x)=>{...x,'signedAmount':x['type']=='Receipt'?numVal(x['amount']):-numVal(x['amount'])}).toList();
      }else if(report=='Expenses'){r=retailUser?await fetch('transactions',shop:assignedShopId):await fetch('productionExpenses');if(retailUser)r=r.where((x)=>x['type']=='Payment'&&x['subType']=='Expense').toList();}
      else if(report=='Production')r=await fetch('production');else if(report=='Salary')r=await fetch('salary');else if(report=='Capital')r=await fetch('capital');else if(report=='Cash Management')r=await _cash();else if(report=='Stock Management')r=await _stock();else if(report=='Profit/Loss')r=await _profit();
      r.sort((a,b)=>dateVal(b['date']).compareTo(dateVal(a['date'])));if(mounted)setState(()=>{rows=r;loading=false;});
    }catch(e){if(mounted)setState(()=>{error='$e';loading=false;});}
  }
  Future<List<Map<String,dynamic>>> _cash() async {final r=<Map<String,dynamic>>[];final t=await fetch('transactions',shop:assignedShopId);final s=await fetch('sales',shop:assignedShopId);for(final x in t){final a=numVal(x['amount']),type=x['type']?.toString()??'';final sign=type=='Receipt'?1:type=='Payment'?-1:0;r.add({'date':x['date'],'particular':'$type • ${x['partyName']??x['description']??''}','amount':a,'signedAmount':a*sign});}for(final x in s){final a=numVal(x['paymentReceived']);if(a>0)r.add({'date':x['date'],'particular':'Sales • ${x['shopName']??assignedShopName??''}','amount':a,'signedAmount':a});}return r;}
  Future<List<Map<String,dynamic>>> _stock() async {final r=<Map<String,dynamic>>[];final t=await fetch('stockTransfers',shop:assignedShopId);final s=await fetch('sales',shop:assignedShopId);final p=retailUser?<Map<String,dynamic>>[]:await fetch('production');if(!retailUser&&(stockScope=='All'||stockScope=='Production Unit'))for(final x in products){final id=x['id'].toString();final made=p.where((z)=>z['productId']?.toString()==id).fold<double>(0,(a,z)=>a+numVal(z['quantity']));final moved=t.where((z)=>z['productId']?.toString()==id).fold<double>(0,(a,z)=>a+numVal(z['quantity']));r.add({'date':DateTime.now(),'particular':'Production Unit • ${x['name']??id}','quantity':made-moved});}if(stockScope=='All'||stockScope=='Retail Shops'){final ids=retailUser?[assignedShopId??'']:shops.map((x)=>x['id'].toString()).toList();for(final sid in ids){for(final x in products){final id=x['id'].toString();final incoming=t.where((z)=>z['shopId']?.toString()==sid&&z['productId']?.toString()==id).fold<double>(0,(a,z)=>a+numVal(z['quantity']));double sold=0;for(final sale in s.where((z)=>z['shopId']?.toString()==sid)){final items=sale['items'];if(items is List)for(final i in items){if(i is Map&&i['productId']?.toString()==id)sold+=numVal(i['quantity']);}}final shop=retailUser?(assignedShopName??'Retail Shop'):(shops.firstWhere((z)=>z['id'].toString()==sid,orElse:()=>{'name':sid})['name']??sid);r.add({'date':DateTime.now(),'particular':'$shop • ${x['name']??id}','quantity':incoming-sold});}}}return r;}
  Future<List<Map<String,dynamic>>> _profit() async {final s=await fetch('sales'),e=await fetch('productionExpenses'),w=await fetch('salary');final gross=s.fold<double>(0,(a,x)=>a+numVal(x['grossAmount'])),comm=s.fold<double>(0,(a,x)=>a+numVal(x['commission'])),exp=e.fold<double>(0,(a,x)=>a+numVal(x['amount'])),sal=w.fold<double>(0,(a,x)=>a+numVal(x['amount']));return [{'date':DateTime.now(),'particular':'Gross Sales','amount':gross},{'date':DateTime.now(),'particular':'Commission','amount':comm},{'date':DateTime.now(),'particular':'Expenses','amount':exp},{'date':DateTime.now(),'particular':'Salary','amount':sal},{'date':DateTime.now(),'particular':'Profit / Loss','amount':gross-comm-exp-sal}];}
  String particular(Map<String,dynamic>x)=>'${x['particular']??x['partyName']??x['productName']??x['workerName']??x['type']??''}';double amount(Map<String,dynamic>x)=>numVal(x['signedAmount']??x['amount']??x['grossAmount']??x['netAmount']??x['quantity']);double get total=>rows.fold<double>(0,(a,x)=>a+amount(x));
  Future<void> exportPdf() async {if(rows.isEmpty){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No report data to export.')));return;}await Printing.layoutPdf(onLayout:(format)async{final d=pw.Document();d.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,build:(_)=>[pw.Text('DAILY HISAB - $report REPORT',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),pw.Text('Period: ${dateText(from)} to ${dateText(to)}'),pw.SizedBox(height:10),pw.TableHelper.fromTextArray(headers:const ['Date','Particular','Amount'],data:rows.map((x)=>[dateText(dateVal(x['date'])),particular(x),amount(x).toStringAsFixed(2)]).toList()),pw.Text('Total: ${total.toStringAsFixed(2)}')]));return d.save();});}
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('Reports'),actions:[IconButton(onPressed:loading?null:exportPdf,icon:const Icon(Icons.picture_as_pdf))]),body:ListView(padding:const EdgeInsets.all(16),children:[DropdownButtonFormField<String>(initialValue:report,decoration:const InputDecoration(labelText:'Report',border:OutlineInputBorder()),items:types.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null){setState(()=>report=v);_load();}}),const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:period,decoration:const InputDecoration(labelText:'Period',border:OutlineInputBorder()),items:const ['Daily','Monthly','Quarterly','6 Monthly','Yearly'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null)changePeriod(v);}),if(!retailUser&&report=='Sales')...[const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:shopId??'',decoration:const InputDecoration(labelText:'Retail Shop',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'',child:Text('All Shops')),...shops.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name']?.toString()??x['id'].toString())))],onChanged:(v){setState(()=>shopId=(v??'').isEmpty?null:v);_load();})],if(report=='Sales')...[const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:productId??'',decoration:const InputDecoration(labelText:'Product',border:OutlineInputBorder()),items:[const DropdownMenuItem(value:'',child:Text('All Products')),...products.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name']?.toString()??x['id'].toString())))],onChanged:(v){setState(()=>productId=(v??'').isEmpty?null:v);_load();})],if(report=='Stock Management'&&!retailUser)...[const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:stockScope,decoration:const InputDecoration(labelText:'Stock Location',border:OutlineInputBorder()),items:const ['All','Production Unit','Retail Shops'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v){if(v!=null){setState(()=>stockScope=v);_load();}})],const SizedBox(height:14),if(error!=null)Text(error!,style:const TextStyle(color:Colors.red)),if(loading)const Center(child:CircularProgressIndicator())else if(rows.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('No data for selected period.'))else Card(child:Column(children:[ListTile(title:Text('$report Report',style:const TextStyle(fontWeight:FontWeight.bold)),trailing:Text('Total ${money(total)}')),const Divider(height:1),...rows.take(100).map((x)=>ListTile(dense:true,title:Text(particular(x)),subtitle:Text(dateText(dateVal(x['date']))),trailing:Text(money(amount(x)))))]))]) );}
}
