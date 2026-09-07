import 'package:flutter/material.dart';
import 'retail_stock_page.dart';

/// Stock Management entry point.
/// Delegates to the dedicated Retail Stock screen so the project remains
/// compile-safe while preserving live Firestore stock functionality.
class StockManagementPage extends StatelessWidget {
  const StockManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RetailStockPage();
  }
}
