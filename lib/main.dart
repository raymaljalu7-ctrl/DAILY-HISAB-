import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/admin_v2_page.dart';
import 'screens/business_page.dart';
import 'screens/cash_management_page.dart';
import 'screens/dashboard_page.dart' as dashboard;
import 'screens/login_page.dart';
import 'screens/masters_page.dart';
import 'screens/reports_v2_page.dart' as reports;
import 'screens/retail_stock_page.dart';
import 'screens/retail_transactions_page.dart';
import 'screens/sales_fixed_page.dart';
import 'screens/stock_management_page.dart';
import 'screens/transactions_page.dart' as transactions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signOut();
  runApp(const DailyHisabApp());
}

const purple = Color(0xFF6C4AB6);
const teal = Color(0xFF00A896);
const orange = Color(0xFFFF8C42);
const blue = Color(0xFF3A86FF);
const red = Color(0xFFE85D75);

class DailyHisabApp extends StatelessWidget {
  const DailyHisabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Hisab',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        scaffoldBackgroundColor: const Color(0xFFF7F5FC),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const Splash();
        }
        final user = auth.data;
        if (user == null) return const LoginPage();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, profile) {
            if (profile.connectionState == ConnectionState.waiting) {
              return const Splash();
            }
            if (!profile.hasData || !profile.data!.exists) {
              return const AccountPendingPage(
                message: 'Your account is waiting for Admin setup/approval.',
              );
            }
            final data = profile.data!.data() ?? <String, dynamic>{};
            final status = data['status']?.toString() ?? 'pending';
            if (status != 'approved') {
              return AccountPendingPage(
                message: status == 'disabled'
                    ? 'Your account has been disabled by Admin.'
                    : 'Your account is waiting for Admin approval.',
              );
            }
            return WelcomePage(profile: data);
          },
        );
      },
    );
  }
}

class WelcomePage extends StatelessWidget {
  final Map<String, dynamic> profile;

  const WelcomePage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile['role'] == 'retail_shop_user') {
      return _RetailWelcome(
        shop: profile['shopName']?.toString() ?? 'Retail Shop',
      );
    }

    final items = <NavBox>[
      const NavBox('DASHBOARD', 'Business overview', Icons.dashboard_outlined, purple, dashboard.DashboardPage()),
      const NavBox('TRANSACTION', 'Receipts & payments', Icons.swap_horiz, teal, transactions.TransactionsPage()),
      const NavBox('STOCK MANAGEMENT', 'Production & shop stock', Icons.inventory_2_outlined, orange, StockManagementPage()),
      const NavBox('CASH MANAGEMENT', 'Cash & bank', Icons.account_balance_wallet_outlined, blue, CashManagementPage()),
      const NavBox('BUSINESS', 'Sales, production & expenses', Icons.business_center_outlined, red, BusinessPage()),
      const NavBox('MASTER', 'Parties, products & workers', Icons.settings_outlined, purple, MastersPage()),
      const NavBox('REPORT', 'Reports & PDF', Icons.assessment_outlined, teal, reports.ReportsV2Page()),
    ];
    if (profile['role'] == 'admin') {
      items.add(const NavBox('ADMIN', 'Users & approvals', Icons.admin_panel_settings_outlined, orange, AdminV2Page()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Hisab'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Welcome to Daily Hisab',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select a section to continue',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.12,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                color: item.color.withValues(alpha: 0.07),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: item.color.withValues(alpha: 0.14)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => item.page),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: item.color.withValues(alpha: 0.16),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RetailWelcome extends StatelessWidget {
  final String shop;

  const _RetailWelcome({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shop),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('Retail Operations', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Only your assigned shop is available.'),
          const SizedBox(height: 20),
          _RetailCard(
            title: 'RETAIL SALES',
            sub: 'Enter customer sales',
            icon: Icons.point_of_sale,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesFixedPage())),
          ),
          const SizedBox(height: 12),
          _RetailCard(
            title: 'RETAIL STOCK',
            sub: 'View your assigned shop stock',
            icon: Icons.inventory_2,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailStockPage())),
          ),
          const SizedBox(height: 12),
          _RetailCard(
            title: 'CASH & BANK',
            sub: 'Receipt, payment, expense and end-of-day tally',
            icon: Icons.account_balance_wallet,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailTransactionsPage())),
          ),
          const SizedBox(height: 12),
          _RetailCard(
            title: 'REPORTS',
            sub: 'View your shop reports',
            icon: Icons.assessment,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const reports.ReportsV2Page())),
          ),
        ],
      ),
    );
  }
}

class NavBox {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  const NavBox(this.title, this.subtitle, this.icon, this.color, this.page);
}

class _RetailCard extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  const _RetailCard({
    required this.title,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 18,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class AccountPendingPage extends StatelessWidget {
  final String message;

  const AccountPendingPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top, size: 64, color: orange),
                const SizedBox(height: 16),
                const Text('Approval Required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('SIGN OUT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
