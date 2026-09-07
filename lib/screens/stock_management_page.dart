import 'package:flutter/material.dart';
import 'production_stock_page.dart';
import 'retail_stock_page.dart';

class StockManagementPage extends StatelessWidget {
  const StockManagementPage({super.key});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Stock Management')),body:ListView(padding:const EdgeInsets.all(16),children:[const Text('Select Stock Location',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),const Text('Choose whether you want to view Production Unit stock or Retail Shop stock.'),const SizedBox(height:20),Card(child:ListTile(minVerticalPadding:20,leading:const CircleAvatar(child:Icon(Icons.factory_outlined)),title:const Text('Production Unit',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Production minus quantities transferred to retail shops.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProductionStockPage())))),const SizedBox(height:12),Card(child:ListTile(minVerticalPadding:20,leading:const CircleAvatar(child:Icon(Icons.store_outlined)),title:const Text('Retail Shop',style:TextStyle(fontWeight:FontWeight.bold)),subtitle:const Text('Select a particular retail shop and view its item-wise stock.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const RetailStockPage()))))]));
}
