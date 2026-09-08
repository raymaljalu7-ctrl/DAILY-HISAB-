import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/retail_shop.dart';
import '../models/sales.dart';
import '../services/firestore_service.dart';
import '../services/sales_service.dart';

class SalesFixedPage extends StatefulWidget {
  const SalesFixedPage({super.key});
  @override State<SalesFixedPage> createState() => _SalesFixedPageState();
}

class _Row {
  String? productId;
  final qty = TextEditingController();
  final rate = TextEditingController();
  void dispose() { qty.dispose(); rate.dispose(); }
}

class _SalesFixedPageState extends State<SalesFixedPage> {
  final rows = <_Row>[_Row()];
  final paid = TextEditingController();
  String? shopId;
  String? assignedShopId;
  String account = 'Cash';
  DateTime date = DateTime.now();
  bool retailUser = false, loading = true, saving = false;
  String? editingId;

  @override void initState() { super.initState(); _profile(); }
  @override void dispose() { for (final r in rows) r.dispose(); paid.dispose(); super.dispose(); }

  Future<void> _profile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => loading = false); return; }
    final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = d.data() ?? {};
    if (!mounted) return;
    setState(() {
      retailUser = data['role']?.toString() == 'retail_shop_user';
      assignedShopId = data['shopId']?.toString();
      shopId = retailUser ? assignedShopId : null;
      loading = false;
    });
  }

  double _n(String s) => double.tryParse(s.trim()) ?? 0;
  double _gross() => rows.fold(0, (t, r) => t + _n(r.qty.text) * _n(r.rate.text));
  void _reset() {
    for (final r in rows) r.dispose();
    rows..clear()..add(_Row());
    paid.clear(); editingId = null; account = 'Cash'; date = DateTime.now(); shopId = retailUser ? assignedShopId : null;
  }
  void _msg(String s) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s))); }

  Future<void> _save(List<Product> products, List<RetailShop> shops) async {
    final shop = shops.where((x) => x.id == shopId).firstOrNull;
    if (shop == null) { _msg('Please select a retail shop.'); return; }
    final items = <SaleItem>[];
    for (final r in rows) {
      if (r.productId == null) continue;
      final p = products.where((x) => x.id == r.productId).firstOrNull;
      final q = _n(r.qty.text), rate = _n(r.rate.text);
      if (p == null) continue;
      if (q <= 0) { _msg('Quantity must be greater than zero.'); return; }
      if (rate < 0) { _msg('Rate cannot be negative.'); return; }
      items.add(SaleItem(productId: p.id, productName: p.name, quantity: q, unitPrice: rate, amount: q * rate));
    }
    if (items.isEmpty) { _msg('Add at least one product.'); return; }
    final gross = SalesService.instance.calculateGross(items);
    final commission = SalesService.instance.calculateCommission(items, shop.commissionPerBox);
    final net = SalesService.instance.calculateNet(gross, commission);
    final payment = _n(paid.text);
    if (payment > net) { _msg('Payment received cannot exceed the net amount.'); return; }
    final sale = Sale(id: editingId ?? '', date: date, shopId: shop.id, shopName: shop.name, items: items, grossAmount: gross, commission: commission, netAmount: net, paymentReceived: payment, outstanding: SalesService.instance.calculateOutstanding(net, payment), paymentStatus: SalesService.instance.paymentStatus(net, payment), paymentAccount: account);
    setState(() => saving = true);
    try {
      if (editingId == null) {
        await SalesService.instance.addSale(sale);
        _msg('Sales transaction saved successfully.');
      } else {
        final admin = await FirestoreService.instance.isAdmin();
        await SalesService.instance.updateSale(sale);
        _msg(admin ? 'Sales transaction updated successfully.' : 'Edit request sent to Admin for approval.');
      }
      if (mounted) { _reset(); setState(() => saving = false); }
    } catch (e) { if (mounted) { setState(() => saving = false); _msg('Unable to save sale: $e'); } }
  }

  void _edit(Sale s) {
    for (final r in rows) r.dispose();
    rows.clear();
    for (final i in s.items) { rows.add(_Row()..productId = i.productId..qty.text = i.quantity.toString()..rate.text = i.unitPrice.toStringAsFixed(2)); }
    if (rows.isEmpty) rows.add(_Row());
    setState(() { editingId = s.id; date = s.date; shopId = s.shopId; paid.text = s.paymentReceived.toStringAsFixed(2); account = s.paymentAccount.isEmpty ? 'Cash' : s.paymentAccount; });
  }

  Future<void> _delete(Sale s) async {
    try { final admin = await FirestoreService.instance.isAdmin(); await SalesService.instance.deleteSale(s.id); _msg(admin ? 'Sales transaction deleted.' : 'Delete request sent to Admin for approval.'); }
    catch (e) { _msg('Unable to delete sale: $e'); }
  }

  Widget _summary(List<RetailShop> shops) {
    return AnimatedBuilder(
      animation: Listenable.merge([...rows.expand((r) => [r.qty, r.rate]), paid]),
      builder: (_, __) {
        final shop = shops.where((x) => x.id == shopId).firstOrNull;
        final gross = _gross();
        final qty = rows.fold(0.0, (t, r) => t + _n(r.qty.text));
        final commission = qty * (shop?.commissionPerBox ?? 0);
        final net = (gross - commission).clamp(0, double.infinity).toDouble();
        final p = _n(paid.text);
        final out = (net - p).clamp(0, double.infinity).toDouble();
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _line('Gross Sales', gross), _line('Commission', commission), _line('Net Amount', net, bold: true),
          const SizedBox(height: 10),
          TextField(controller: paid, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment Received', prefixText: '₹ ', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: account, items: const [DropdownMenuItem(value: 'Cash', child: Text('Cash')), DropdownMenuItem(value: 'Bank', child: Text('Bank'))], onChanged: saving ? null : (v) { if (v != null) setState(() => account = v); }, decoration: const InputDecoration(labelText: 'Payment Account', border: OutlineInputBorder())),
          const SizedBox(height: 8), _line('Outstanding', out, bold: true),
          Text('Status: ${SalesService.instance.paymentStatus(net, p)}'),
        ])));
      },
    );
  }
  Widget _line(String a, double b, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: TextStyle(fontWeight: bold ? FontWeight.bold : null)), Text('₹${b.toStringAsFixed(2)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : null))]));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(appBar: AppBar(title: const Text('Sales')), body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.instance.stream('retailShops'), builder: (context, ss) {
        if (ss.hasError) return Center(child: Text('Error loading shops: ${ss.error}'));
        if (!ss.hasData) return const Center(child: CircularProgressIndicator());
        final shops = (ss.data ?? []).map((d) => RetailShop.fromMap(d['id'].toString(), d)).where((x) => x.active && (!retailUser || x.id == assignedShopId)).toList();
        if (shopId != null && shops.every((x) => x.id != shopId)) shopId = null;
        return StreamBuilder<List<Map<String, dynamic>>>(stream: FirestoreService.instance.stream('products'), builder: (context, ps) {
          if (ps.hasError) return Center(child: Text('Error loading products: ${ps.error}'));
          if (!ps.hasData) return const Center(child: CircularProgressIndicator());
          final products = (ps.data ?? []).map((d) => Product.fromMap(d['id'].toString(), d)).where((x) => x.active).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Sales Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null && mounted) setState(() => date = d); }, child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), child: Text('${date.day.toString().padLeft(2,'0')}-${date.month.toString().padLeft(2,'0')}-${date.year}'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: shopId, items: shops.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(), onChanged: retailUser || saving ? null : (v) => setState(() => shopId = v), decoration: InputDecoration(labelText: 'Retail Shop', border: const OutlineInputBorder(), helperText: retailUser ? 'Assigned shop' : null)),
            ]))),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              Row(children: [const Expanded(child: Text('Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FilledButton.tonalIcon(onPressed: saving ? null : () => setState(() => rows.add(_Row())), icon: const Icon(Icons.add), label: const Text('Add Item'))]),
              const SizedBox(height: 10),
              ...List.generate(rows.length, (i) { final r = rows[i]; return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [DropdownButtonFormField<String>(initialValue: r.productId, items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: saving ? null : (v) => setState(() => r.productId = v), decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder())), const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: r.qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: r.rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate', prefixText: '₹ ', border: OutlineInputBorder()))), if (rows.length > 1) IconButton(onPressed: saving ? null : () { final x = rows.removeAt(i); x.dispose(); setState(() {}); }, icon: const Icon(Icons.delete_outline))]), const SizedBox(height: 5), Align(alignment: Alignment.centerRight, child: Text('Amount: ₹${(_n(r.qty.text) * _n(r.rate.text)).toStringAsFixed(2)}'))])); }),
            ]))),
            _summary(shops),
            const SizedBox(height: 12),
            SizedBox(height: 50, child: FilledButton.icon(onPressed: saving ? null : () => _save(products, shops), icon: saving ? const SizedBox(width: 18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save), label: Text(saving ? 'SAVING...' : (editingId == null ? 'SAVE SALES' : 'UPDATE SALES')))),
            const SizedBox(height: 20),
            const Text('Sales Transactions', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            StreamBuilder<List<Sale>>(stream: SalesService.instance.watchSales(), builder: (context, hs) {
              if (hs.hasError) return Text('Error loading sales: ${hs.error}');
              if (!hs.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
              final sales = hs.data ?? [];
              if (sales.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No sales transactions found.'));
              return Column(children: sales.map((s) => Card(child: ListTile(title: Text(s.shopName, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Net ₹${s.netAmount.toStringAsFixed(2)} • Paid ₹${s.paymentReceived.toStringAsFixed(2)} • Outstanding ₹${s.outstanding.toStringAsFixed(2)}'), trailing: Wrap(children: [IconButton(onPressed: saving ? null : () => _edit(s), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: saving ? null : () => _delete(s), icon: const Icon(Icons.delete_outline))]))).toList());
            }),
          ]);
        });
      },
    ));
  }
}
