import 'package:flutter/material.dart';
import 'sales_page.dart';

/// Stable entry point for the production Sales screen.
/// The full SalesPage contains multi-item sales, payment account selection,
/// edit/delete approval routing and invoice/delivery-challan generation.
class SalesFixedPage extends StatelessWidget {
  const SalesFixedPage({super.key});

  @override
  Widget build(BuildContext context) => const SalesPage();
}
