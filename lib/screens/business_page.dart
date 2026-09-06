import 'package:flutter/material.dart';
import 'business_history_page.dart';
import 'capital_page.dart';
import 'cash_management_page.dart';
import 'production_expenses_page.dart';
import 'production_history_page.dart';
import 'production_fixed_page.dart';
import 'salary_page.dart';
import 'sales_fixed_page.dart';
import 'stock_management_page.dart';
import 'transaction_history_page.dart';

class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});
  @override Widget build(BuildContext context) {
    final items=<_BusinessItem>[
      _BusinessItem('Sales','Record retail shop sales and commission',Icons.point_of_sale_outlined,const SalesFixedPage()),
      _BusinessItem('Production','Record daily bakery production',Icons.factory_outlined,const ProductionFixedPage()),
      _BusinessItem('Stock Management','Production stock, transfers and shop stock',Icons.inventory_outlined,const StockManagementPage()),
      _BusinessItem('Cash Management','Automatic Cash and Bank balances',Icons.account_balance_wallet_outlined,const CashManagementPage()),
      _BusinessItem('Production Expenses','Record production expenses',Icons.receipt_long_outlined,const ProductionExpensesPage()),
      _BusinessItem('Salary','Manage worker salary and advances',Icons.badge_outlined,const SalaryPage()),
      _BusinessItem('Capital','Track capital received and returned',Icons.account_balance_outlined,const CapitalPage()),
      _BusinessItem('Transaction History','View transactions and approval actions',Icons.history,const TransactionHistoryPage()),
      _BusinessItem('Production History','View production and approval actions',Icons.history_toggle_off,const ProductionHistoryPage()),
      _BusinessItem('Production Expense History','View expenses and approval actions',Icons.receipt_long,const BusinessHistoryPage(collection:'productionExpenses',title:'Production Expense')),
      _BusinessItem('Salary History','View salary and approval actions',Icons.payments_outlined,const BusinessHistoryPage(collection:'salary',title:'Salary')),
      _BusinessItem('Capital History','View capital and approval actions',Icons.account_balance_wallet_outlined,const BusinessHistoryPage(collection:'capital',title:'Capital')),
    ];
    return Scaffold(appBar:AppBar(title:const Text('Business')),body:ListView(padding:const EdgeInsets.all(16),children:[const Card(child:ListTile(leading:CircleAvatar(child:Icon(Icons.business_center_outlined)),title:Text('Business Operations'),subtitle:Text('Manage sales, production, stock, cash, expenses, salary, capital and history.'))),const SizedBox(height:18),...items.map((x)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Card(child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),leading:CircleAvatar(radius:24,child:Icon(x.icon)),title:Text(x.title,style:const TextStyle(fontWeight:FontWeight.w600)),subtitle:Text(x.subtitle),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>x.page)))))]));
  }
}
class _BusinessItem{final String title,subtitle;final IconData icon;final Widget page;const _BusinessItem(this.title,this.subtitle,this.icon,this.page);}
