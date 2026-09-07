import 'package:flutter/material.dart';
import 'retail_stock_page.dart';

/// Stock Management entry point. The dedicated Retail Stock screen remains
/// available and uses the live Firestore stock data.
class StockManagementPage extends StatelessWidget {
  const StockManagementPage({super.key});

  @override
  Widget build(BuildContext context) => const RetailStockPage();
}
