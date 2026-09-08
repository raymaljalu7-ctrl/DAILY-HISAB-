import 'package:flutter/material.dart';

import '../models/party.dart';
import '../services/firestore_service.dart';
import '../services/retail_cash_service.dart';

class RetailTransactionsPage extends StatefulWidget {
  const RetailTransactionsPage({super.key});
  @override State<RetailTransactionsPage> createState() => _RetailTransactionsPageState();
}

class _RetailTransactionsPageState extends State<RetailTransactionsPage> {
  String type = 'Receipt';
  String paymentFor = 'Party';
  String account = 'Cash';
  String partyMode = 'none'; // none, existing, new
  String? partyId;
  Party? party;
  final amount = TextEditingController();
  final description = TextEditingController();
  bool saving = false;

  @override void dispose() { amount.dispose(); description.dispose(); super.dispose(); }

  Future<void> _addNewParty(List<Party> parties) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    try {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Add New Party'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Party Name')),
          const SizedBox(height: 10), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
          const SizedBox(height: 10), TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (optional)')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('CANCEL')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ADD'))],
      ));
      if (ok != true || name.text.trim().isEmpty) { if (ok == true) _message('Enter a party name.'); return; }
      final existing = parties.where((p) => p.name.trim().toLowerCase() == name.text.trim().toLowerCase()).firstOrNull;
      if (existing != null) { setState(() { partyMode = 'existing'; partyId = existing.id; party = existing; }); _message('Existing party selected.'); return; }
      final id = await FirestoreService.instance.add('parties', {
        'name': name.text.trim(), 'phone': phone.text.trim(), 'address': address.text.trim(),
        'openingBalance': 0, 'openingType': 'Receivable', 'active': true,
        'partyType': 'customer',
      });
      if (mounted) { setState(() { partyMode = 'existing'; partyId = id; party = Party(id: id, name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim()); }); _message('New party added and selected.'); }
    } catch (e) { _message('Unable to add party: $e'); }
    name.dispose(); phone.dispose(); address.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) { _message('Enter an amount greater than zero.'); return; }
    if (type == 'Payment' && paymentFor == 'Expense' && description.text.trim().isEmpty) { _message('Please enter the expense details.'); return; }
    setState(() => saving = true);
    try {
      await FirestoreService.instance.add('transactions', {
        'date': DateTime.now(), 'type': type, 'amount': value, 'account': account,
        'partyId': partyMode == 'existing' ? (party?.id ?? '') : '',
        'partyName': partyMode == 'existing' ? (party?.name ?? '') : '',
        'description': description.text.trim(), if (type == 'Payment') 'subType': paymentFor,
      });
      if (!mounted) return;
      amount.clear(); description.clear(); setState(() { saving = false; partyMode = 'none'; partyId = null; party = null; });
      _message('Transaction saved successfully.');
    } catch (e) { if (mounted) { setState(() => saving = false); _message('Unable to save transaction:\n$e'); } }
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  Widget _partySelector(List<Party> parties) {
    return Column(children: [
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: partyMode,
        items: const [
          DropdownMenuItem(value: 'none', child: Text('None')),
          DropdownMenuItem(value: 'existing', child: Text('Select Existing Party')),
          DropdownMenuItem(value: 'new', child: Text('Add New Party')),
        ],
        onChanged: saving ? null : (v) async {
          if (v == null) return;
          if (v == 'new') { await _addNewParty(parties); return; }
          setState(() { partyMode = v; if (v == 'none') { partyId = null; party = null; } });
        },
        decoration: const InputDecoration(labelText: 'Party', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
      ),
      if (partyMode == 'existing') ...[
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: partyId,
          isExpanded: true,
          items: parties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
          onChanged: saving ? null : (id) { final p = parties.where((x) => x.id == id).firstOrNull; setState(() { partyId = id; party = p; }); },
          decoration: const InputDecoration(labelText: 'Existing Party', border: OutlineInputBorder()),
        ),
      ],
      if (partyMode == 'new') const SizedBox(height: 8),
    ]);
  }

  Widget _form(List<Party> parties) {
    final showParty = type == 'Receipt' || paymentFor == 'Party';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Retail Transaction Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(initialValue: type, items: const [DropdownMenuItem(value: 'Receipt', child: Text('Receipt')), DropdownMenuItem(value: 'Payment', child: Text('Payment'))], onChanged: saving ? null : (v) { if (v != null) setState(() { type = v; if (v == 'Receipt') paymentFor = 'Party'; }); }, decoration: const InputDecoration(labelText: 'Transaction', prefixIcon: Icon(Icons.swap_horiz), border: OutlineInputBorder())),
      if (type == 'Payment') ...[
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(initialValue: paymentFor, items: const [DropdownMenuItem(value: 'Party', child: Text('Party Payment')), DropdownMenuItem(value: 'Expense', child: Text('Expense'))], onChanged: saving ? null : (v) { if (v != null) setState(() { paymentFor = v; if (v == 'Expense') { partyMode = 'none'; party = null; partyId = null; } }); }, decoration: const InputDecoration(labelText: 'Payment For', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder())),
      ],
      if (showParty) _partySelector(parties),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(initialValue: account, items: const [DropdownMenuItem(value: 'Cash', child: Text('Cash')), DropdownMenuItem(value: 'Bank', child: Text('Bank'))], onChanged: saving ? null : (v) => setState(() => account = v ?? 'Cash'), decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder())),
      const SizedBox(height: 14),
      TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee), border: OutlineInputBorder())),
      const SizedBox(height: 14),
      TextField(controller: description, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: InputDecoration(labelText: type == 'Payment' && paymentFor == 'Expense' ? 'Expense Details' : 'Description', prefixIcon: const Icon(Icons.notes_outlined), border: const OutlineInputBorder())),
      const SizedBox(height: 14),
      SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save), label: Text(saving ? 'SAVING...' : 'SAVE TRANSACTION'))),
    ]));
  }

  Widget _balance() => FutureBuilder<Map<String,double>>(future: RetailCashService.instance.balances(), builder: (context, s) {
    if (!s.hasData) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
    final d=s.data!; final cash=d['Cash']??0, bank=d['Bank']??0;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('End-of-Day Cash / Bank Balance', style: TextStyle(fontSize:18,fontWeight:FontWeight.bold)), const SizedBox(height:12), Row(children:[Expanded(child: _tile('CASH IN HAND',cash,Icons.payments_outlined)),const SizedBox(width:10),Expanded(child:_tile('BANK BALANCE',bank,Icons.account_balance_outlined))]), const SizedBox(height:8), Text('Total available: ₹${(cash+bank).toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold))])));
  });
  Widget _tile(String t,double n,IconData i)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant)),child:Column(children:[Icon(i),const SizedBox(height:4),Text(t,textAlign:TextAlign.center,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),Text('₹${n.toStringAsFixed(2)}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))]));

  Widget _history(List<Map<String,dynamic>> rows)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Recent Transactions',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),...rows.reversed.take(30).map((r){final t=r['type']?.toString()??'Transaction',p=r['partyName']?.toString()??'',a=(r['amount'] as num?)?.toDouble()??0,ac=r['account']?.toString()??'Cash',d=r['description']?.toString()??'';return ListTile(contentPadding:EdgeInsets.zero,leading:Icon(t=='Receipt'?Icons.arrow_downward:Icons.arrow_upward),title:Text('$t • ₹${a.toStringAsFixed(2)}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text([if(p.isNotEmpty)p,ac,if(d.isNotEmpty)d].join(' • ')));})])));

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Retail Cash & Bank')),body:StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('parties'),builder:(context,ps){if(ps.hasError)return Center(child:Text('Unable to load parties:\n${ps.error}'));if(!ps.hasData)return const Center(child:CircularProgressIndicator());final parties=(ps.data??[]).map((d)=>Party.fromMap(d['id'].toString(),d)).where((p)=>p.active).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));return StreamBuilder<List<Map<String,dynamic>>>(stream:FirestoreService.instance.stream('transactions'),builder:(context,ts){if(ts.hasError)return Center(child:Text('Unable to load transactions:\n${ts.error}'));if(!ts.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(12),children:[_balance(),const SizedBox(height:12),_form(parties),const SizedBox(height:12),_history(ts.data??[])]);});}));
}
