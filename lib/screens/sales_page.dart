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

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  DateTime selectedDate = DateTime.now();
  String? selectedShopId;
  RetailShop? selectedShop;
  final List<_SalesRow> rows = [];
  final TextEditingController paymentController = TextEditingController();
  bool saving = false;
  String? editingSaleId;
  double editingPaymentReceived = 0;
  String paymentAccount = 'Cash';
  String? assignedShopId;
  bool retailUser = false;

  @override
  void initState() {
    super.initState();
    rows.add(_SalesRow());
    _loadUserProfile();
  }

  @override
  void dispose() {
    for (final row in rows) row.dispose();
    paymentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? <String, dynamic>{};
    final role = data['role']?.toString();
    final shopId = data['shopId']?.toString();
    setState(() {
      retailUser = role == 'retail_shop_user';
      assignedShopId = shopId;
      if (retailUser && shopId != null && shopId.isNotEmpty) {
        selectedShopId = shopId;
      }
    });
  }

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  double get grossAmount => rows.fold<double>(0, (total, row) => total + row.amount);
  double get commissionAmount => rows.fold<double>(0, (total, row) => total + row.quantity) * (selectedShop?.commissionPerBox ?? 0);
  double get netAmount {
    final value = grossAmount - commissionAmount;
    return value < 0 ? 0 : value;
  }
  double get paymentReceived {
    final value = double.tryParse(paymentController.text.trim());
    return value == null || value < 0 ? 0 : value;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => selectedDate = picked);
  }

  void _addRow() => setState(() => rows.add(_SalesRow()));
  void _removeRow(int index) {
    if (rows.length == 1) return;
    rows.removeAt(index).dispose();
    setState(() {});
  }
  void _update() => setState(() {});

  Future<void> _saveSale(List<Product> products) async {
    if (selectedShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a retail shop.')));
      return;
    }
    if (retailUser && assignedShopId != null && selectedShop!.id != assignedShopId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only enter sales for your assigned shop.')));
      return;
    }

    final saleItems = <SaleItem>[];
    for (final row in rows) {
      if (row.productId == null) continue;
      if (row.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantity must be greater than zero.')));
        return;
      }
      if (row.unitPrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit price cannot be negative.')));
        return;
      }
      Product? product;
      for (final item in products) {
        if (item.id == row.productId) { product = item; break; }
      }
      if (product == null) continue;
      saleItems.add(SaleItem(productId: product.id, productName: product.name, quantity: row.quantity, unitPrice: row.unitPrice, amount: row.amount));
    }
    if (saleItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one product to the sale.')));
      return;
    }

    final gross = saleItems.fold<double>(0, (total, item) => total + item.amount);
    final commission = SalesService.instance.calculateCommission(saleItems, selectedShop!.commissionPerBox);
    final net = SalesService.instance.calculateNet(gross, commission);
    final paid = paymentReceived;
    if (paid > net) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment received cannot exceed the net amount.')));
      return;
    }
    final outstanding = SalesService.instance.calculateOutstanding(net, paid);
    final sale = Sale(
      id: editingSaleId ?? '', date: selectedDate, shopId: selectedShop!.id, shopName: selectedShop!.name,
      items: saleItems, grossAmount: gross, commission: commission, netAmount: net,
      paymentReceived: paid, outstanding: outstanding,
      paymentStatus: SalesService.instance.paymentStatus(net, paid), paymentAccount: paymentAccount,
    );

    setState(() => saving = true);
    try {
      final wasEditing = editingSaleId != null;
      final savedSaleId = wasEditing ? editingSaleId! : await SalesService.instance.addSale(sale);
      if (wasEditing) await SalesService.instance.updateSale(sale);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wasEditing ? 'Sales transaction updated successfully.' : 'Sales transaction saved successfully.')));
      final documentSale = sale.copyWith();
      editingSaleId = null;
      editingPaymentReceived = 0;
      paymentController.clear();
      for (final row in rows) row.clear();
      setState(() { selectedShopId = retailUser ? assignedShopId : null; selectedShop = null; selectedDate = DateTime.now(); paymentAccount = 'Cash'; saving = false; });
      await _showDocumentChoice(documentSale.copyWith());
      if (savedSaleId.isEmpty) return;
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save sale:\n$error')));
    }
  }

  Future<void> _showDocumentChoice(Sale sale) async {
    if (!mounted) return;
    final choice = await showDialog<String>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      title: const Text('Sale Saved Successfully'),
      content: const Text('Would you like to generate a sales document?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, 'skip'), child: const Text('Skip')),
        OutlinedButton.icon(onPressed: () => Navigator.pop(context, 'challan'), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Delivery Challan')),
        FilledButton.icon(onPressed: () => Navigator.pop(context, 'invoice'), icon: const Icon(Icons.receipt_long_outlined), label: const Text('Sales Invoice')),
      ],
    ));
    if (!mounted || choice == null || choice == 'skip') return;
    await _generateSalesDocument(sale, invoice: choice == 'invoice');
  }

  Future<void> _generateSalesDocument(Sale sale, {required bool invoice}) async {
    final documentTitle = invoice ? 'SALES INVOICE' : 'DELIVERY CHALLAN';
    try {
      await Printing.layoutPdf(onLayout: (format) async {
        final pdf = pw.Document();
        pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (context) => [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Bakery', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 4), pw.Text('Surat', style: const pw.TextStyle(fontSize: 11))]),
            pw.Text(documentTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 20), pw.Divider(), pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Date: ${_formatDate(sale.date)}', style: const pw.TextStyle(fontSize: 11)), pw.Text('Document No: ${sale.id.substring(0, sale.id.length > 8 ? 8 : sale.id.length).toUpperCase()}', style: const pw.TextStyle(fontSize: 11))]),
          pw.SizedBox(height: 8), pw.Text('Retail Shop: ${sale.shopName}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 18),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), columnWidths: invoice ? {0: const pw.FlexColumnWidth(.6),1: const pw.FlexColumnWidth(3),2: const pw.FlexColumnWidth(1),3: const pw.FlexColumnWidth(1.3),4: const pw.FlexColumnWidth(1.5)} : {0: const pw.FlexColumnWidth(.7),1: const pw.FlexColumnWidth(4),2: const pw.FlexColumnWidth(1.5)}, children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey200), children: invoice ? [_pdfCell('#', bold: true),_pdfCell('Product', bold: true),_pdfCell('Qty', bold: true),_pdfCell('Rate', bold: true),_pdfCell('Amount', bold: true)] : [_pdfCell('#', bold: true),_pdfCell('Product', bold: true),_pdfCell('Quantity', bold: true)]),
            ...sale.items.asMap().entries.map((entry) { final item = entry.value; final index = entry.key + 1; return pw.TableRow(children: invoice ? [_pdfCell('$index'),_pdfCell(item.productName),_pdfCell(item.quantity.toStringAsFixed(2)),_pdfCell('Rs. ${item.unitPrice.toStringAsFixed(2)}'),_pdfCell('Rs. ${item.amount.toStringAsFixed(2)}')] : [_pdfCell('$index'),_pdfCell(item.productName),_pdfCell(item.quantity.toStringAsFixed(2))]); }),
          ]),
          pw.SizedBox(height: 18),
          if (invoice) pw.Align(alignment: pw.Alignment.centerRight, child: pw.SizedBox(width: 240, child: pw.Column(children: [_pdfSummaryRow('Gross Amount', sale.grossAmount),_pdfSummaryRow('Commission', sale.commission),_pdfSummaryRow('Net Amount', sale.netAmount, bold: true),_pdfSummaryRow('Payment Received', sale.paymentReceived),_pdfSummaryRow('Outstanding', sale.outstanding, bold: true),pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text('Payment Account: ${sale.paymentAccount}', style: const pw.TextStyle(fontSize: 10)))]))),
          pw.SizedBox(height: 45), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()),pw.Text('Received By')]),pw.Column(children: [pw.SizedBox(width: 150, child: pw.Divider()),pw.Text('Authorized Signature')])]),
        ]));
        return pdf.save();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to generate document:\n$error')));
    }
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) => pw.Padding(padding: const pw.EdgeInsets.all(7), child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
  pw.Widget _pdfSummaryRow(String title, double amount, {bool bold = false}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))]));

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Sales')), body: StreamBuilder<List<Map<String, dynamic>>>(stream: FirestoreService.instance.stream('retailShops'), builder: (context, shopSnapshot) {
      if (shopSnapshot.hasError) return Center(child: Text('Error loading shops:\n${shopSnapshot.error}', textAlign: TextAlign.center));
      if (shopSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final allShops = (shopSnapshot.data ?? []).map((data) => RetailShop.fromMap(data['id'].toString(), data)).where((shop) => shop.active).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final shops = retailUser && assignedShopId != null ? allShops.where((shop) => shop.id == assignedShopId).toList() : allShops;
      return StreamBuilder<List<Map<String, dynamic>>>(stream: FirestoreService.instance.stream('products'), builder: (context, productSnapshot) {
        if (productSnapshot.hasError) return Center(child: Text('Error loading products:\n${productSnapshot.error}', textAlign: TextAlign.center));
        if (productSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final products = (productSnapshot.data ?? []).map((data) => Product.fromMap(data['id'].toString(), data)).where((product)=>product.active).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return ListView(padding: const EdgeInsets.all(16), children: [_buildSalesForm(shops, products), const SizedBox(height: 8), _buildSalesHistory(products, shops)]);
      });
    }));
  }

  Widget _buildSalesForm(List<RetailShop> shops, List<Product> products) {
    if (shops.isEmpty || products.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.point_of_sale_outlined,size:56),const SizedBox(height:12),const Text('Sales setup incomplete',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(shops.isEmpty ? 'Please add at least one active Retail Shop.' : 'Please add at least one active Product.',textAlign:TextAlign.center)])));
    if (selectedShopId != null) { final found = shops.where((shop)=>shop.id==selectedShopId).firstOrNull; if (found == null) { if (!retailUser) selectedShopId=null; selectedShop=null; } else selectedShop=found; }
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [const Text('Sales Details',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:16),InkWell(onTap:_selectDate,borderRadius:BorderRadius.circular(8),child:InputDecorator(decoration:const InputDecoration(labelText:'Date',prefixIcon:Icon(Icons.calendar_month),border:OutlineInputBorder()),child:Text(_formatDate(selectedDate)))),const SizedBox(height:16),
        DropdownButtonFormField<String>(initialValue:selectedShopId,items:shops.map((shop)=>DropdownMenuItem<String>(value:shop.id,child:Text(shop.name))).toList(),onChanged: retailUser ? null : (value){final shop=shops.where((item)=>item.id==value).firstOrNull;setState(()=>{selectedShopId=value;selectedShop=shop;for(final row in rows){row.updateAmount();}});},decoration:InputDecoration(labelText:'Retail Shop',prefixIcon:const Icon(Icons.storefront),border:const OutlineInputBorder(),helperText: retailUser ? 'Assigned shop' : null)),
        if(selectedShop!=null)...[const SizedBox(height:10),Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(borderRadius:BorderRadius.circular(8),color:Theme.of(context).colorScheme.surfaceContainerHighest),child:Text('Commission: Rs. ${selectedShop!.commissionPerBox.toStringAsFixed(2)} / Box',style:const TextStyle(fontWeight:FontWeight.w600)))],
      ]))),
      const SizedBox(height:12), Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('Products',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),FilledButton.tonalIcon(onPressed:_addRow,icon:const Icon(Icons.add),label:const Text('Add Item'))]),const SizedBox(height:12),...List.generate(rows.length,(index)=>_buildProductRow(index,products))]))),
      const SizedBox(height:12), Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[_summaryRow('Gross Sales',grossAmount),const Divider(),_summaryRow('Commission',commissionAmount),const Divider(),_summaryRow('Net Amount',netAmount,bold:true),const SizedBox(height:14),TextField(controller:paymentController,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_)=>_update(),decoration:const InputDecoration(labelText:'Payment Received',prefixText:'Rs. ',border:OutlineInputBorder())),const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:paymentAccount,items:const [DropdownMenuItem(value:'Cash',child:Text('Cash')),DropdownMenuItem(value:'Bank',child:Text('Bank'))],onChanged:(value){if(value!=null)setState(()=>paymentAccount=value);},decoration:const InputDecoration(labelText:'Payment Account',border:OutlineInputBorder(),prefixIcon:Icon(Icons.account_balance_wallet_outlined))),const SizedBox(height:10),_summaryRow('Outstanding',netAmount-paymentReceived<0?0:netAmount-paymentReceived,bold:true),Text('Payment status: ${SalesService.instance.paymentStatus(netAmount,paymentReceived)}',style:const TextStyle(fontSize:12)),const SizedBox(height:8),const Text('Payment is also reflected in Cash/Bank according to the selected account.',style:TextStyle(fontSize:12))]))),
      const SizedBox(height:16),SizedBox(height:52,child:FilledButton.icon(onPressed:saving?null:()=>_saveSale(products),icon:saving?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save),label:Text(saving?'SAVING...':'SAVE SALES'))),const SizedBox(height:24)]);
  }

  Widget _buildSalesHistory(List<Product> products,List<RetailShop> shops)=>StreamBuilder<List<Sale>>(stream:SalesService.instance.watchSales(),builder:(context,snapshot){if(snapshot.hasError)return Card(child:Padding(padding:const EdgeInsets.all(16),child:Text('Error loading sales:\n${snapshot.error}')));if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());final sales=snapshot.data??[];if(sales.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('No sales transactions found.')));return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Sales Transactions',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),...sales.map((sale)=>Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(sale.shopName,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),Text(_formatDate(sale.date),style:const TextStyle(fontSize:12))]),const SizedBox(height:8),Text('${sale.items.length} item(s)  •  Net: Rs. ${sale.netAmount.toStringAsFixed(2)}  •  Paid: Rs. ${sale.paymentReceived.toStringAsFixed(2)}  •  Outstanding: Rs. ${sale.outstanding.toStringAsFixed(2)}'),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.end,children:[OutlinedButton.icon(onPressed:saving?null:()=>_startEditingSale(sale,products,shops),icon:const Icon(Icons.edit_outlined),label:const Text('Edit')),const SizedBox(width:8),OutlinedButton.icon(onPressed:saving?null:()=>_deleteSale(sale),icon:const Icon(Icons.delete_outline),label:const Text('Delete'))])])))]);});

  void _startEditingSale(Sale sale,List<Product> products,List<RetailShop> shops){for(final row in rows)row.dispose();rows.clear();for(final item in sale.items){final row=_SalesRow();row.productId=item.productId;row.quantityController.text=item.quantity.toString();row.unitPriceController.text=item.unitPrice.toStringAsFixed(2);row.updateAmount();rows.add(row);}if(rows.isEmpty)rows.add(_SalesRow());final shop=shops.where((item)=>item.id==sale.shopId).firstOrNull;paymentController.text=sale.paymentReceived.toStringAsFixed(2);setState(()=>{editingSaleId=sale.id,editingPaymentReceived=sale.paymentReceived,selectedDate=sale.date,selectedShopId=sale.shopId,selectedShop=shop,paymentAccount=sale.paymentAccount.isEmpty?'Cash':sale.paymentAccount});}

  Future<void> _deleteSale(Sale sale) async {final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Delete Sale?'),content:Text('Delete the sales transaction for ${sale.shopName} dated ${_formatDate(sale.date)}?'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('CANCEL')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('DELETE'))]));if(confirmed!=true)return;try{await SalesService.instance.deleteSale(sale.id);if(!mounted)return;final admin=await FirestoreService.instance.isAdmin();if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(admin?'Sales transaction deleted successfully.':'Delete request sent to Admin for approval.')));}catch(error){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Unable to delete sale:\n$error')));}}

  Widget _buildProductRow(int index,List<Product> products){final row=rows[index];return Container(margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(12),decoration:BoxDecoration(border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),borderRadius:BorderRadius.circular(10)),child:Column(children:[Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:row.productId,items:products.map((product)=>DropdownMenuItem<String>(value:product.id,child:Text(product.name))).toList(),onChanged:(value){final product=products.where((item)=>item.id==value).firstOrNull;row.productId=value;if(product!=null&&row.unitPriceController.text.trim().isEmpty&&product.defaultMrp>0)row.unitPriceController.text=product.defaultMrp.toStringAsFixed(2);row.updateAmount();_update();},decoration:const InputDecoration(labelText:'Bakery Item',prefixIcon:Icon(Icons.inventory_2_outlined),border:OutlineInputBorder()))),if(rows.length>1) ...[const SizedBox(width:8),IconButton(tooltip:'Remove Item',onPressed:()=>_removeRow(index),icon:const Icon(Icons.delete_outline))]]),const SizedBox(height:12),Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:TextField(controller:row.quantityController,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_){row.updateAmount();_update();},decoration:const InputDecoration(labelText:'Quantity',suffixText:'Box',border:OutlineInputBorder()))),const SizedBox(width:10),Expanded(child:TextField(controller:row.unitPriceController,keyboardType:const TextInputType.numberWithOptions(decimal:true),onChanged:(_){row.updateAmount();_update();},decoration:const InputDecoration(labelText:'MRP / Unit Price',prefixText:'Rs. ',border:OutlineInputBorder())))]),const SizedBox(height:10),Align(alignment:Alignment.centerRight,child:Text('Amount: Rs. ${row.amount.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)))]);}
  Widget _summaryRow(String label,double amount,{bool bold=false})=>Row(children:[Expanded(child:Text(label,style:TextStyle(fontWeight:bold?FontWeight.bold:FontWeight.normal))),Text('Rs. ${amount.toStringAsFixed(2)}',style:TextStyle(fontSize:bold?18:16,fontWeight:bold?FontWeight.bold:FontWeight.w600))]);
}

class _SalesRow { String? productId; final TextEditingController quantityController=TextEditingController(); final TextEditingController unitPriceController=TextEditingController(); double amount=0; double get quantity=>double.tryParse(quantityController.text.trim())??0; double get unitPrice=>double.tryParse(unitPriceController.text.trim())??0; void updateAmount()=>amount=quantity*unitPrice; void clear(){productId=null;quantityController.clear();unitPriceController.clear();amount=0;} void dispose(){quantityController.dispose();unitPriceController.dispose();} }
