import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';
import '../models/retail_shop.dart';
import '../models/sales.dart';
import '../services/firestore_service.dart';
import '../services/sales_service.dart';

class SalesFixedPage extends StatefulWidget {
  const SalesFixedPage({super.key});
  @override State<SalesFixedPage> createState() => _SalesFixedPageState();
}

class _SalesRow {
  String? productId;
  final quantityController = TextEditingController();
  final rateController = TextEditingController();
  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0;
  double get rate => double.tryParse(rateController.text.trim()) ?? 0;
  double get amount => quantity * rate;
  void dispose() { quantityController.dispose(); rateController.dispose(); }
}

class _SalesFixedPageState extends State<SalesFixedPage> {
  final rows = <_SalesRow>[];
  final paymentController = TextEditingController();
  final formVersion = ValueNotifier<int>(0);
  DateTime selectedDate = DateTime.now();
  String? selectedShopId, assignedShopId, editingSaleId;
  RetailShop? selectedShop;
  String paymentAccount = 'Cash';
  bool retailUser = false, loadingProfile = true, saving = false;

  double get grossAmount => rows.fold(0, (s, r) => s + r.amount);
  double get commissionAmount => rows.fold(0, (s, r) => s + r.quantity) * (selectedShop?.commissionPerBox ?? 0);
  double get netAmount => (grossAmount - commissionAmount).clamp(0, double.infinity).toDouble();
  double get paymentReceived => (double.tryParse(paymentController.text.trim()) ?? 0).clamp(0, double.infinity).toDouble();
  double get outstanding => (netAmount - paymentReceived).clamp(0, double.infinity).toDouble();
  String fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
  void msg(String x) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(x))); }
  void notifyFormChanged() => formVersion.value++;

  _SalesRow newRow() {
    final row = _SalesRow();
    row.quantityController.addListener(notifyFormChanged);
    row.rateController.addListener(notifyFormChanged);
    return row;
  }

  @override void initState() { super.initState(); rows.add(newRow()); paymentController.addListener(notifyFormChanged); _loadProfile(); }
  @override void dispose() { for (final r in rows) r.dispose(); paymentController.dispose(); formVersion.dispose(); super.dispose(); }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => loadingProfile = false); return; }
    try {
      final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final x = d.data() ?? {};
      if (!mounted) return;
      setState(() { retailUser = x['role']?.toString() == 'retail_shop_user'; assignedShopId = x['shopId']?.toString(); selectedShopId = retailUser ? assignedShopId : null; loadingProfile = false; });
    } catch (e) { if (mounted) { setState(() => loadingProfile = false); msg('Unable to load user profile: $e'); } }
  }

  void addRow() => setState(() => rows.add(newRow()));
  void removeRow(int i) { if (rows.length == 1) return; final r = rows.removeAt(i); r.dispose(); notifyFormChanged(); setState(() {}); }
  Future<void> pickDate() async { final x = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (x != null && mounted) setState(() => selectedDate = x); }

  void resetForm() {
    for (final r in rows) r.dispose();
    rows..clear()..add(newRow());
    paymentController.clear(); editingSaleId = null; selectedDate = DateTime.now(); paymentAccount = 'Cash'; selectedShopId = retailUser ? assignedShopId : null; selectedShop = null;
    notifyFormChanged();
  }

  Future<void> save(List<RetailShop> shops, List<Product> products) async {
    if (selectedShop == null) { msg('Please select a retail shop.'); return; }
    if (retailUser && selectedShop!.id != assignedShopId) { msg('You can only enter sales for your assigned shop.'); return; }
    final items = <SaleItem>[];
    for (final row in rows) {
      if (row.productId == null) continue;
      if (row.quantity <= 0) { msg('Quantity must be greater than zero.'); return; }
      if (row.rate < 0) { msg('Rate cannot be negative.'); return; }
      final p = products.where((x) => x.id == row.productId).firstOrNull;
      if (p == null) continue;
      items.add(SaleItem(productId: p.id, productName: p.name, quantity: row.quantity, unitPrice: row.rate, amount: row.amount));
    }
    if (items.isEmpty) { msg('Add at least one product.'); return; }
    final gross = SalesService.instance.calculateGross(items);
    final commission = SalesService.instance.calculateCommission(items, selectedShop!.commissionPerBox);
    final net = SalesService.instance.calculateNet(gross, commission);
    final paid = paymentReceived;
    if (paid > net) { msg('Payment received cannot exceed the net amount.'); return; }
    final sale = Sale(id: editingSaleId ?? '', date: selectedDate, shopId: selectedShop!.id, shopName: selectedShop!.name, items: items, grossAmount: gross, commission: commission, netAmount: net, paymentReceived: paid, outstanding: (net-paid).clamp(0,double.infinity).toDouble(), paymentStatus: paid <= 0 ? 'Pending' : paid >= net ? 'Paid' : 'Partial', paymentAccount: paymentAccount);
    setState(() => saving = true);
    try {
      if (editingSaleId != null) {
        final isAdmin = await FirestoreService.instance.isAdmin();
        await SalesService.instance.updateSale(sale);
        if (!mounted) return;
        msg(isAdmin ? 'Sales transaction updated successfully.' : 'Edit request sent to Admin for approval.'); resetForm(); setState(() => saving = false); return;
      }
      final id = await SalesService.instance.addSale(sale);
      final saved = Sale(id: id, date: sale.date, shopId: sale.shopId, shopName: sale.shopName, items: sale.items, grossAmount: sale.grossAmount, commission: sale.commission, netAmount: sale.netAmount, paymentReceived: sale.paymentReceived, outstanding: sale.outstanding, paymentStatus: sale.paymentStatus, paymentAccount: sale.paymentAccount);
      if (!mounted) return;
      msg('Sales transaction saved successfully.'); resetForm(); setState(() => saving = false); await documentChoice(saved);
    } catch (e) { if (mounted) { setState(() => saving = false); msg('Unable to save sale: $e'); } }
  }

  void edit(Sale sale, List<RetailShop> shops) {
    for (final r in rows) r.dispose();
    rows.clear();
    for (final item in sale.items) {
      final r = newRow();
      r.productId = item.productId; r.quantityController.text = item.quantity.toString(); r.rateController.text = item.unitPrice.toStringAsFixed(2); rows.add(r);
    }
    if (rows.isEmpty) rows.add(newRow());
    selectedDate = sale.date; selectedShopId = sale.shopId; selectedShop = shops.where((s) => s.id == sale.shopId).firstOrNull; paymentController.text = sale.paymentReceived.toStringAsFixed(2); paymentAccount = sale.paymentAccount.isEmpty ? 'Cash' : sale.paymentAccount; editingSaleId = sale.id; notifyFormChanged(); setState(() {});
  }

  Future<void> delete(Sale sale) async { try { final isAdmin = await FirestoreService.instance.isAdmin(); await SalesService.instance.deleteSale(sale.id); msg(isAdmin ? 'Sales transaction deleted.' : 'Delete request sent to Admin for approval.'); } catch (e) { msg('Unable to delete sale: $e'); } }

  Future<void> documentChoice(Sale sale) async {
    final choice = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('Sale Saved Successfully'), content: const Text('Generate a sales document?'), actions: [TextButton(onPressed: () => Navigator.pop(c,'skip'), child: const Text('Skip')), OutlinedButton(onPressed: () => Navigator.pop(c,'challan'), child: const Text('Delivery Challan')), FilledButton(onPressed: () => Navigator.pop(c,'invoice'), child: const Text('Sales Invoice'))]));
    if (!mounted || choice == null || choice == 'skip') return;
    await printDocument(sale, invoice: choice == 'invoice');
  }

  Future<void> printDocument(Sale sale, {required bool invoice}) async {
    try { await Printing.layoutPdf(onLayout: (format) async { final doc = pw.Document(); doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (_) => [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('JALU BAKERY', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)), pw.Text(invoice ? 'SALES INVOICE' : 'DELIVERY CHALLAN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))]),
      pw.SizedBox(height: 14), pw.Text('Date: ${fmt(sale.date)}'), pw.Text('Retail Shop: ${sale.shopName}'), pw.SizedBox(height: 14),
      pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: [pw.TableRow(children: [_cell('#',true),_cell('Product',true),_cell('Qty',true),if(invoice)_cell('Rate',true),if(invoice)_cell('Amount',true)]), ...sale.items.asMap().entries.map((e) { final i=e.key+1; final x=e.value; return pw.TableRow(children:[_cell('$i',false),_cell(x.productName,false),_cell(x.quantity.toStringAsFixed(2),false),if(invoice)_cell('Rs. ${x.unitPrice.toStringAsFixed(2)}',false),if(invoice)_cell('Rs. ${x.amount.toStringAsFixed(2)}',false)]); })]),
      if(invoice)...[pw.SizedBox(height:14),_pdfRow('Gross Amount',sale.grossAmount),_pdfRow('Commission',sale.commission),_pdfRow('Net Amount',sale.netAmount),_pdfRow('Payment Received',sale.paymentReceived),_pdfRow('Outstanding',sale.outstanding),pw.Text('Payment Account: ${sale.paymentAccount}')]
    ])); return doc.save(); }); } catch (e) { msg('Unable to generate document: $e'); }
  }
  pw.Widget _cell(String t,bool b)=>pw.Padding(padding:const pw.EdgeInsets.all(6),child:pw.Text(t,style:pw.TextStyle(fontSize:9,fontWeight:b?pw.FontWeight.bold:pw.FontWeight.normal)));
  pw.Widget _pdfRow(String l,double v)=>pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:3),child:pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[pw.Text(l),pw.Text('Rs. ${v.toStringAsFixed(2)}')]));

  @override
  Widget build(BuildContext context) {
    if (loadingProfile) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('Sales')), body: StreamBuilder<List<Map<String,dynamic>>>(
      stream: FirestoreService.instance.stream('retailShops'), builder: (context, shopSnap) {
        if (shopSnap.hasError) return Center(child: Text('Error loading shops: ${shopSnap.error}')); if (!shopSnap.hasData) return const Center(child:CircularProgressIndicator());
        final allShops=(shopSnap.data??[]).map((d)=>RetailShop.fromMap(d['id'].toString(),d)).where((s)=>s.active).toList()..sort((a,b)=>a.name.compareTo(b.name));
        final shops=retailUser&&assignedShopId!=null?allShops.where((s)=>s.id==assignedShopId).toList():allShops; if(selectedShopId!=null) selectedShop=shops.where((s)=>s.id==selectedShopId).firstOrNull;
        return StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('products'),builder:(context,productSnap){
          if(productSnap.hasError)return Center(child:Text('Error loading products: ${productSnap.error}'));if(!productSnap.hasData)return const Center(child:CircularProgressIndicator());
          final products=(productSnap.data??[]).map((d)=>Product.fromMap(d['id'].toString(),d)).where((p)=>p.active).toList()..sort((a,b)=>a.name.compareTo(b.name));
          if(shops.isEmpty||products.isEmpty)return Center(child:Text(shops.isEmpty?'Please add an active Retail Shop first.':'Please add an active Product first.'));
          return ListView(padding:const EdgeInsets.all(16),children:[
            Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
              const Align(alignment:Alignment.centerLeft,child:Text('Sales Details',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),const SizedBox(height:14),
              InkWell(onTap:pickDate,child:InputDecorator(decoration:const InputDecoration(labelText:'Date',border:OutlineInputBorder()),child:Text(fmt(selectedDate)))),const SizedBox(height:12),
              DropdownButtonFormField<String>(initialValue:selectedShopId,items:shops.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.name))).toList(),onChanged:(v)=>setState(()=>selectedShopId=v),decoration:const InputDecoration(labelText:'Retail Shop',border:OutlineInputBorder())),const SizedBox(height:14),
              ...List.generate(rows.length,(i)=>_rowWidget(i,products)),
              Align(alignment:Alignment.centerLeft,child:OutlinedButton.icon(onPressed:addRow,icon:const Icon(Icons.add),label:const Text('ADD ITEM'))),const SizedBox(height:12),
              TextField(controller:paymentController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Payment Received',prefixText:'Rs. ',border:OutlineInputBorder())),const SizedBox(height:10),
              DropdownButtonFormField<String>(initialValue:paymentAccount,items:const[DropdownMenuItem(value:'Cash',child:Text('Cash')),DropdownMenuItem(value:'Bank',child:Text('Bank'))],onChanged:(v){if(v!=null)setState(()=>paymentAccount=v);},decoration:const InputDecoration(labelText:'Payment Account',border:OutlineInputBorder())),const SizedBox(height:12),
              ValueListenableBuilder<int>(valueListenable:formVersion,builder:(context,_,__)=>Align(alignment:Alignment.centerLeft,child:Text('Gross: Rs. ${grossAmount.toStringAsFixed(2)}  •  Commission: Rs. ${commissionAmount.toStringAsFixed(2)}  •  Net: Rs. ${netAmount.toStringAsFixed(2)}  •  Outstanding: Rs. ${outstanding.toStringAsFixed(2)}'))),
              const SizedBox(height:14),SizedBox(height:50,width:double.infinity,child:FilledButton.icon(onPressed:saving?null:()=>save(shops,products),icon:const Icon(Icons.save),label:Text(saving?'SAVING...':editingSaleId==null?'SAVE SALES':'UPDATE SALES'))),
            ]))),const SizedBox(height:18),const Text('Sales History',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
            StreamBuilder<List<Sale>>(stream:SalesService.instance.watchSales(),builder:(context,h){if(h.hasError)return Text('Unable to load sales: ${h.error}');if(!h.hasData)return const CircularProgressIndicator();return Column(children:h.data!.map((s)=>Card(child:ListTile(title:Text('${s.shopName} • Rs. ${s.netAmount.toStringAsFixed(2)}'),subtitle:Text('${fmt(s.date)} • ${s.items.length} item(s) • ${s.paymentStatus}'),trailing:Wrap(children:[IconButton(onPressed:()=>edit(s,shops),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>delete(s),icon:const Icon(Icons.delete_outline))]))).toList());}),
          ]);
        });
      },
    ));
  }

  Widget _rowWidget(int i,List<Product> products){final r=rows[i];return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:r.productId,items:products.map((p)=>DropdownMenuItem(value:p.id,child:Text(p.name))).toList(),onChanged:(v){r.productId=v; notifyFormChanged(); setState(() {});},decoration:const InputDecoration(labelText:'Bakery Item',border:OutlineInputBorder()))),if(rows.length>1)IconButton(onPressed:()=>removeRow(i),icon:const Icon(Icons.delete_outline))]),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:r.quantityController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity',border:OutlineInputBorder()))),const SizedBox(width:10),Expanded(child:TextField(controller:r.rateController,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Rate',prefixText:'Rs. ',border:OutlineInputBorder()))),const SizedBox(width:10),ValueListenableBuilder<int>(valueListenable:formVersion,builder:(context,_,__)=>
      SizedBox(width:90,child:Text('Rs. ${r.amount.toStringAsFixed(2)}',textAlign:TextAlign.right)))])])));}
}
