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

class _SalesRow {
  String? productId;
  final quantityController = TextEditingController();
  final rateController = TextEditingController();

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0;
  double get rate => double.tryParse(rateController.text.trim()) ?? 0;
  double get amount => quantity * rate;

  void clear() {
    productId = null;
    quantityController.clear();
    rateController.clear();
  }

  void dispose() {
    quantityController.dispose();
    rateController.dispose();
  }
}

class _SalesPageState extends State<SalesPage> {
  final rows = <_SalesRow>[_SalesRow()];
  final paymentController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String? selectedShopId;
  RetailShop? selectedShop;
  String paymentAccount = 'Cash';
  String? assignedShopId;
  bool retailUser = false;
  bool loadingProfile = true;
  bool saving = false;
  String? editingSaleId;

  double get grossAmount => rows.fold(0, (sum, row) => sum + row.amount);
  double get commissionAmount => rows.fold(0, (sum, row) => sum + row.quantity) * (selectedShop?.commissionPerBox ?? 0);
  double get netAmount => (grossAmount - commissionAmount).clamp(0, double.infinity).toDouble();
  double get paymentReceived => (double.tryParse(paymentController.text.trim()) ?? 0).clamp(0, double.infinity).toDouble();
  double get outstanding => (netAmount - paymentReceived).clamp(0, double.infinity).toDouble();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final row in rows) row.dispose();
    paymentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => loadingProfile = false);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    final data = doc.data() ?? <String, dynamic>{};
    final role = data['role']?.toString() ?? '';
    final shopId = data['shopId']?.toString();
    setState(() {
      retailUser = role == 'retail_shop_user';
      assignedShopId = shopId;
      selectedShopId = retailUser ? shopId : null;
      loadingProfile = false;
    });
  }

  String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => selectedDate = picked);
  }

  void _addRow() => setState(() => rows.add(_SalesRow()));

  void _removeRow(int index) {
    if (rows.length == 1) return;
    final row = rows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  void _resetForm() {
    for (final row in rows) row.dispose();
    rows
      ..clear()
      ..add(_SalesRow());
    paymentController.clear();
    editingSaleId = null;
    selectedDate = DateTime.now();
    paymentAccount = 'Cash';
    selectedShopId = retailUser ? assignedShopId : null;
    selectedShop = null;
  }

  Future<void> _save(List<Product> products) async {
    if (selectedShop == null) {
      _message('Please select a retail shop.');
      return;
    }
    if (retailUser && selectedShop!.id != assignedShopId) {
      _message('You can only enter sales for your assigned shop.');
      return;
    }

    final items = <SaleItem>[];
    for (final row in rows) {
      if (row.productId == null) continue;
      if (row.quantity <= 0) {
        _message('Quantity must be greater than zero.');
        return;
      }
      if (row.rate < 0) {
        _message('Rate cannot be negative.');
        return;
      }
      final product = products.where((p) => p.id == row.productId).firstOrNull;
      if (product == null) continue;
      items.add(SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: row.quantity,
        unitPrice: row.rate,
        amount: row.amount,
      ));
    }
    if (items.isEmpty) {
      _message('Add at least one product.');
      return;
    }

    final gross = SalesService.instance.calculateGross(items);
    final commission = SalesService.instance.calculateCommission(items, selectedShop!.commissionPerBox);
    final net = SalesService.instance.calculateNet(gross, commission);
    final paid = paymentReceived;
    if (paid > net) {
      _message('Payment received cannot exceed the net amount.');
      return;
    }

    final sale = Sale(
      id: editingSaleId ?? '',
      date: selectedDate,
      shopId: selectedShop!.id,
      shopName: selectedShop!.name,
      items: items,
      grossAmount: gross,
      commission: commission,
      netAmount: net,
      paymentReceived: paid,
      outstanding: SalesService.instance.calculateOutstanding(net, paid),
      paymentStatus: SalesService.instance.paymentStatus(net, paid),
      paymentAccount: paymentAccount,
    );

    setState(() => saving = true);
    try {
      final editing = editingSaleId != null;
      if (editing) {
        final admin = await FirestoreService.instance.isAdmin();
        if (!mounted) return;
        await SalesService.instance.updateSale(sale);
        if (!mounted) return;
        _message(admin ? 'Sales transaction updated successfully.' : 'Edit request sent to Admin for approval.');
        _resetForm();
        setState(() => saving = false);
        return;
      }

      final id = await SalesService.instance.addSale(sale);
      if (!mounted) return;
      final saved = Sale(
        id: id,
        date: sale.date,
        shopId: sale.shopId,
        shopName: sale.shopName,
        items: sale.items,
        grossAmount: sale.grossAmount,
        commission: sale.commission,
        netAmount: sale.netAmount,
        paymentReceived: sale.paymentReceived,
        outstanding: sale.outstanding,
        paymentStatus: sale.paymentStatus,
        paymentAccount: sale.paymentAccount,
      );
      _message('Sales transaction saved successfully.');
      _resetForm();
      setState(() => saving = false);
      await _documentChoice(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _message('Unable to save sale: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _edit(Sale sale, List<RetailShop> shops) {
    for (final row in rows) row.dispose();
    rows.clear();
    for (final item in sale.items) {
      final row = _SalesRow()
        ..productId = item.productId
        ..quantityController.text = item.quantity.toString()
        ..rateController.text = item.unitPrice.toStringAsFixed(2);
      rows.add(row);
    }
    if (rows.isEmpty) rows.add(_SalesRow());
    selectedDate = sale.date;
    selectedShopId = sale.shopId;
    selectedShop = shops.where((s) => s.id == sale.shopId).firstOrNull;
    paymentController.text = sale.paymentReceived.toStringAsFixed(2);
    paymentAccount = sale.paymentAccount.isEmpty ? 'Cash' : sale.paymentAccount;
    editingSaleId = sale.id;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, alignment: 0.0);
    });
  }

  Future<void> _delete(Sale sale) async {
    try {
      final admin = await FirestoreService.instance.isAdmin();
      if (!mounted) return;
      await SalesService.instance.deleteSale(sale.id);
      if (!mounted) return;
      _message(admin ? 'Sales transaction deleted.' : 'Delete request sent to Admin for approval.');
    } catch (e) {
      if (mounted) _message('Unable to delete sale: $e');
    }
  }

  Future<void> _documentChoice(Sale sale) async {
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sale Saved Successfully'),
        content: const Text('Generate a sales document?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'skip'), child: const Text('Skip')),
          OutlinedButton(onPressed: () => Navigator.pop(context, 'challan'), child: const Text('Delivery Challan')),
          FilledButton(onPressed: () => Navigator.pop(context, 'invoice'), child: const Text('Sales Invoice')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'skip') return;
    await _printDocument(sale, invoice: choice == 'invoice');
  }

  Future<void> _printDocument(Sale sale, {required bool invoice}) async {
    try {
      await Printing.layoutPdf(onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('BAKERY', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text(invoice ? 'SALES INVOICE' : 'DELIVERY CHALLAN', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 16),
            pw.Text('Date: ${_date(sale.date)}'),
            pw.Text('Retail Shop: ${sale.shopName}'),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(children: [
                  _cell('#', true), _cell('Product', true), _cell('Qty', true),
                  if (invoice) _cell('Rate', true), if (invoice) _cell('Amount', true),
                ]),
                ...sale.items.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(children: [
                    _cell('$i', false), _cell(item.productName, false), _cell(item.quantity.toStringAsFixed(2), false),
                    if (invoice) _cell('Rs. ${item.unitPrice.toStringAsFixed(2)}', false),
                    if (invoice) _cell('Rs. ${item.amount.toStringAsFixed(2)}', false),
                  ]);
                }),
              ],
            ),
            if (invoice) ...[
              pw.SizedBox(height: 16),
              _pdfRow('Gross Amount', sale.grossAmount),
              _pdfRow('Commission', sale.commission),
              _pdfRow('Net Amount', sale.netAmount),
              _pdfRow('Payment Received', sale.paymentReceived),
              _pdfRow('Outstanding', sale.outstanding),
              pw.Text('Payment Account: ${sale.paymentAccount}'),
            ],
          ],
        ));
        return doc.save();
      });
    } catch (e) {
      _message('Unable to generate document: $e');
    }
  }

  pw.Widget _cell(String text, bool bold) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
  );

  pw.Widget _pdfRow(String label, double value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(label), pw.Text('Rs. ${value.toStringAsFixed(2)}')]),
  );

  @override
  Widget build(BuildContext context) {
    if (loadingProfile) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirestoreService.instance.stream('retailShops'),
        builder: (context, shopSnap) {
          if (shopSnap.hasError) return Center(child: Text('Error loading shops: ${shopSnap.error}'));
          if (shopSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final allShops = (shopSnap.data ?? [])
              .map((d) => RetailShop.fromMap(d['id'].toString(), d))
              .where((s) => s.active)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final shops = retailUser && assignedShopId != null
              ? allShops.where((s) => s.id == assignedShopId).toList()
              : allShops;
          if (selectedShopId != null) selectedShop = shops.where((s) => s.id == selectedShopId).firstOrNull;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirestoreService.instance.stream('products'),
            builder: (context, productSnap) {
              if (productSnap.hasError) return Center(child: Text('Error loading products: ${productSnap.error}'));
              if (productSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final products = (productSnap.data ?? [])
                  .map((d) => Product.fromMap(d['id'].toString(), d))
                  .where((p) => p.active)
                  .toList()
                ..sort((a, b) => a.name.compareTo(b.name));
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _form(shops, products),
                  const SizedBox(height: 20),
                  _history(shops),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _form(List<RetailShop> shops, List<Product> products) {
    if (shops.isEmpty || products.isEmpty) {
      return Card(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(shops.isEmpty ? 'Please add an active Retail Shop first.' : 'Please add an active Product first.'),
      ));
    }
    return Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Sales Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 14),
        InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), child: Text(_date(selectedDate)))),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedShopId,
          items: shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
          onChanged: retailUser ? null : (value) {
            final shop = shops.where((s) => s.id == value).firstOrNull;
            setState(() { selectedShopId = value; selectedShop = shop; });
          },
          decoration: InputDecoration(labelText: 'Retail Shop', border: const OutlineInputBorder(), helperText: retailUser ? 'Assigned shop' : null),
        ),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [const Expanded(child: Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FilledButton.tonalIcon(onPressed: _addRow, icon: const Icon(Icons.add), label: const Text('Add Item'))]),
        const SizedBox(height: 12),
        ...List.generate(rows.length, (i) => _row(i, products)),
      ]))),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _summary('Gross Sales', grossAmount),
        _summary('Commission', commissionAmount),
        _summary('Net Amount', netAmount, bold: true),
        const SizedBox(height: 12),
        TextField(controller: paymentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Payment Received', prefixText: 'Rs. ', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: paymentAccount, items: const [DropdownMenuItem(value: 'Cash', child: Text('Cash')), DropdownMenuItem(value: 'Bank', child: Text('Bank'))], onChanged: (v) { if (v != null) setState(() => paymentAccount = v); }, decoration: const InputDecoration(labelText: 'Payment Account', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        _summary('Outstanding', outstanding, bold: true),
        Text('Status: ${SalesService.instance.paymentStatus(netAmount, paymentReceived)}'),
      ]))),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: saving ? null : () => _save(products), icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(saving ? 'SAVING...' : (editingSaleId == null ? 'SAVE SALES' : 'UPDATE SALES')))),
    ]);
  }

  Widget _row(int index, List<Product> products) {
    final row = rows[index];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
      Row(children: [Expanded(child: DropdownButtonFormField<String>(initialValue: row.productId, items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { setState(() => row.productId = v); }, decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()))), if (rows.length > 1) IconButton(onPressed: () => _removeRow(index), icon: const Icon(Icons.delete_outline))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: TextField(controller: row.quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: row.rateController, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Rate', prefixText: 'Rs. ', border: OutlineInputBorder())))]),
      const SizedBox(height: 6),
      Align(alignment: Alignment.centerRight, child: Text('Amount: Rs. ${row.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
    ])));
  }

  Widget _summary(String title, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)), Text('Rs. ${value.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))]));

  Widget _history(List<RetailShop> shops) => StreamBuilder<List<Sale>>(
    stream: SalesService.instance.watchSales(),
    builder: (context, snap) {
      if (snap.hasError) return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error loading sales: ${snap.error}')));
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final sales = snap.data ?? [];
      if (sales.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No sales transactions found.')));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sales Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...sales.map((sale) => Card(child: ListTile(
          title: Text(sale.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${_date(sale.date)}\nNet: Rs. ${sale.netAmount.toStringAsFixed(2)} | Paid: Rs. ${sale.paymentReceived.toStringAsFixed(2)} | Outstanding: Rs. ${sale.outstanding.toStringAsFixed(2)}'),
          isThreeLine: true,
          trailing: Wrap(children: [IconButton(onPressed: saving ? null : () => _edit(sale, shops), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: saving ? null : () => _delete(sale), icon: const Icon(Icons.delete_outline))]),
        ))),
      ]);
    },
  );
}
