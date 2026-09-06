import 'package:flutter/material.dart';

import 'business_history_page.dart';
import 'capital_page.dart';
import 'production_expenses_page.dart';
import 'production_history_page.dart';
import 'production_page.dart';
import 'salary_page.dart';
import 'sales_page.dart';
import 'transaction_history_page.dart';

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});
  @override
  Widget build(BuildContext context) {
    final businessItems = <_BusinessItem>[
      _BusinessItem(title:'Sales',subtitle:'Record retail shop sales and calculate commission',icon:Icons.point_of_sale_outlined,page:const SalesPage()),
      _BusinessItem(title:'Production',subtitle:'Record daily bakery production',icon:Icons.factory_outlined,page:const ProductionPage()),
      _BusinessItem(title:'Production Expenses',subtitle:'Record raw material, transport and other expenses',icon:Icons.receipt_long_outlined,page:const ProductionExpensesPage()),
      _BusinessItem(title:'Salary',subtitle:'Manage worker salary and advance payments',icon:Icons.badge_outlined,page:const SalaryPage()),
      _BusinessItem(title:'Capital',subtitle:'Track capital received and returned to owner',icon:Icons.account_balance_outlined,page:const CapitalPage()),
      _BusinessItem(title:'Transaction History',subtitle:'View transactions and request edit or delete approval',icon:Icons.history,page:const TransactionHistoryPage()),
      _BusinessItem(title:'Production History',subtitle:'View production and request edit or delete approval',icon:Icons.history_toggle_off,page:const ProductionHistoryPage()),
      _BusinessItem(title:'Production Expense History',subtitle:'View expenses and request edit or delete approval',icon:Icons.receipt_long,page:const BusinessHistoryPage(collection:'productionExpenses',title:'Production Expense')),
      _BusinessItem(title:'Salary History',subtitle:'View salary and advance records with approval actions',icon:Icons.payments_outlined,page:const BusinessHistoryPage(collection:'salary',title:'Salary')),
      _BusinessItem(title:'Capital History',subtitle:'View capital records with approval actions',icon:Icons.account_balance_wallet_outlined,page:const BusinessHistoryPage(collection:'capital',title:'Capital')),
    ];
    return Scaffold(
      appBar:AppBar(title:const Text('Business')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[const CircleAvatar(radius:25,child:Icon(Icons.business_center_outlined,size:26)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Business Operations',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:4),Text('Manage sales, production, expenses, salary, capital and history.',style:TextStyle(color:Colors.black54))]))]))),
        const SizedBox(height:18),const Text('Operations',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:10),
        ...businessItems.map((item)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),leading:CircleAvatar(radius:24,child:Icon(item.icon)),title:Text(item.title,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:16)),subtitle:Padding(padding:const EdgeInsets.only(top:4),child:Text(item.subtitle)),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>item.page))))),
      ]),
    );
  }
}
class _BusinessItem { final String title; final String subtitle; final IconData icon; final Widget page; const _BusinessItem({required this.title,required this.subtitle,required this.icon,required this.page}); }
