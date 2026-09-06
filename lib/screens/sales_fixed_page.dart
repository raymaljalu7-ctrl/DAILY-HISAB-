import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/sales.dart';
import '../services/sales_service.dart';

class SalesFixedPage extends StatefulWidget {
  const SalesFixedPage({super.key});
  @override State<SalesFixedPage> createState() => _SalesFixedPageState();
}
class _SalesFixedPageState extends State<SalesFixedPage> {
  final qty=TextEditingController(); final rate=TextEditingController(); final paid=TextEditingController();
  final db=FirebaseFirestore.instance;
  String? shopId, productId, editingId; String account='Cash'; DateTime date=DateTime.now(); bool saving=false;
  double numv(dynamic v)=>v is num?v.toDouble():double.tryParse('$v')??0;
  String fmt(DateTime d)=>'${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';
  @override void dispose(){qty.dispose();rate.dispose();paid.dispose();super.dispose();}
  Future<bool> admin() async {final u=FirebaseAuth.instance.currentUser;if(u==null)return false;final d=await db.collection('users').doc(u.uid).get();return d.data()?['role']=='admin' && d.data()?['status']=='approved';}
  void msg(String x){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));}
  void clear(){qty.clear();rate.clear();paid.clear();editingId=null;productId=null;date=DateTime.now();account='Cash';}
  Future<void> save(List<Map<String,dynamic>> shops,List<Map<String,dynamic>> products) async {
    if(shopId==null||productId==null){msg('Select retail shop and product.');return;}
    final q=numv(qty.text), r=numv(rate.text), p=numv(paid.text);
    if(q<=0||r<0){msg('Enter valid quantity and rate.');return;}
    final shop=shops.firstWhere((x)=>x['id'].toString()==shopId);
    final prod=products.firstWhere((x)=>x['id'].toString()==productId);
    final gross=q*r, commission=q*numv(shop['commissionPerBox']), net=(gross-commission).clamp(0,double.infinity).toDouble();
    if(p>net){msg('Payment cannot exceed net amount.');return;}
    final sale=Sale(id:editingId??'',date:date,shopId:shopId!,shopName:shop['name']?.toString()??'',items:[SaleItem(productId:productId!,productName:prod['name']?.toString()??'',quantity:q,unitPrice:r,amount:gross)],grossAmount:gross,commission:commission,netAmount:net,paymentReceived:p,outstanding:net-p,paymentStatus:p<=0?'Pending':p>=net?'Paid':'Partial',paymentAccount:account);
    setState(()=>saving=true);
    try{
      if(editingId!=null){final isAdmin=await admin();await SalesService.instance.updateSale(sale);msg(isAdmin?'Sales updated.':'Edit request sent to Admin for approval.');}
      else{await SalesService.instance.addSale(sale);msg('Sales saved successfully.');}
      clear(); if(mounted)setState(()=>saving=false);
    }catch(e){if(mounted)setState(()=>saving=false);msg('Unable to save sale: $e');}
  }
  Future<void> editSale(Sale s) async {if(s.items.isEmpty)return;final i=s.items.first;setState((){editingId=s.id;date=s.date;shopId=s.shopId;productId=i.productId;qty.text=i.quantity.toString();rate.text=i.unitPrice.toStringAsFixed(2);paid.text=s.paymentReceived.toStringAsFixed(2);account=s.paymentAccount;});}
  Future<void> deleteSale(Sale s) async {try{final isAdmin=await admin();await SalesService.instance.deleteSale(s.id);msg(isAdmin?'Sales deleted.':'Delete request sent to Admin for approval.');}catch(e){msg('Unable to delete sale: $e');}}

  @override
  Widget build(BuildContext context){
    final root=db.collection('sharedData').doc('dailyHisab');
    return Scaffold(
      appBar:AppBar(title:const Text('Sales')),
      body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:root.collection('retailShops').snapshots(),
        builder:(context,shopSnap){
          if(shopSnap.hasError)return Center(child:Text('Unable to load shops: ${shopSnap.error}'));
          if(!shopSnap.hasData)return const Center(child:CircularProgressIndicator());
          final shops=shopSnap.data!.docs.map((d)=>{'id':d.id,...d.data()}).where((x)=>x['active']!=false).toList();
          return StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream:root.collection('products').snapshots(),
            builder:(context,productSnap){
              if(productSnap.hasError)return Center(child:Text('Unable to load products: ${productSnap.error}'));
              if(!productSnap.hasData)return const Center(child:CircularProgressIndicator());
              final products=productSnap.data!.docs.map((d)=>{'id':d.id,...d.data()}).where((x)=>x['active']!=false).toList();
              return ListView(padding:const EdgeInsets.all(16),children:[
                InkWell(onTap:()async{final x=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(x!=null&&mounted)setState(()=>date=x);},child:InputDecorator(decoration:const InputDecoration(labelText:'Date',border:OutlineInputBorder()),child:Text(fmt(date)))),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(initialValue:shopId,items:shops.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name']?.toString()??''))).toList(),onChanged:(v)=>setState(()=>shopId=v),decoration:const InputDecoration(labelText:'Retail Shop',border:OutlineInputBorder())),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(initialValue:productId,items:products.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name']?.toString()??''))).toList(),onChanged:(v)=>setState(()=>productId=v),decoration:const InputDecoration(labelText:'Product',border:OutlineInputBorder())),
                const SizedBox(height:10),
                Row(children:[Expanded(child:TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity',border:OutlineInputBorder()))),const SizedBox(width:10),Expanded(child:TextField(controller:rate,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Rate',prefixText:'Rs. ',border:OutlineInputBorder())))]),
                const SizedBox(height:10),
                TextField(controller:paid,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Payment Received',prefixText:'Rs. ',border:OutlineInputBorder())),
                const SizedBox(height:10),
                DropdownButtonFormField<String>(initialValue:account,items:const[DropdownMenuItem(value:'Cash',child:Text('Cash')),DropdownMenuItem(value:'Bank',child:Text('Bank'))],onChanged:(v){if(v!=null)setState(()=>account=v);},decoration:const InputDecoration(labelText:'Payment Account',border:OutlineInputBorder())),
                const SizedBox(height:14),
                SizedBox(height:50,child:FilledButton.icon(onPressed:saving?null:()=>save(shops,products),icon:const Icon(Icons.save),label:Text(saving?'SAVING...':editingId==null?'SAVE SALES':'UPDATE SALES'))),
                const SizedBox(height:20),
                const Text('Sales History',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
                StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
                  stream:root.collection('sales').orderBy('date',descending:true).snapshots(),
                  builder:(context,h){
                    if(h.hasError)return Text('Unable to load sales: ${h.error}');
                    if(!h.hasData)return const CircularProgressIndicator();
                    return Column(children:h.data!.docs.map((d){final s=Sale.fromMap(d.id,d.data());return Card(child:ListTile(title:Text('${s.shopName} • Rs. ${s.netAmount.toStringAsFixed(2)}'),subtitle:Text('${fmt(s.date)} • ${s.paymentStatus}'),trailing:Wrap(children:[IconButton(onPressed:()=>editSale(s),icon:const Icon(Icons.edit_outlined)),IconButton(onPressed:()=>deleteSale(s),icon:const Icon(Icons.delete_outline))])));}).toList());
                  },
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}
