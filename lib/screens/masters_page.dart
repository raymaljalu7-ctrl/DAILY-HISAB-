import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'change_requests_page.dart';
import 'parties_page.dart';
import 'products_page.dart';
import 'retail_shops_page.dart';
import 'workers_page.dart';

class MastersPage extends StatelessWidget {
  const MastersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final masters = <_MasterItem>[
      _MasterItem(
        title: 'Retail Shops',
        subtitle: 'Manage shops and commission per box',
        icon: Icons.store_outlined,
        page: const RetailShopsPage(),
      ),
      _MasterItem(
        title: 'Products',
        subtitle: 'Manage bakery products and MRP',
        icon: Icons.inventory_2_outlined,
        page: const ProductsPage(),
      ),
      _MasterItem(
        title: 'Parties',
        subtitle: 'Manage parties and opening balances',
        icon: Icons.people_outline,
        page: const PartiesPage(),
      ),
      _MasterItem(
        title: 'Workers',
        subtitle: 'Manage workers and monthly salary',
        icon: Icons.badge_outlined,
        page: const WorkersPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Masters')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.settings_outlined, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business Masters',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set up and manage the basic information used throughout Daily Hisab.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Manage', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...masters.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(radius: 24, child: Icon(item.icon)),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(item.subtitle)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
            builder: (context, snapshot) {
              final profile = snapshot.data?.data() ?? {};
              if (profile['role'] != 'admin') return const SizedBox.shrink();

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  title: const Text(
                    'Change Approvals',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Approve or reject user edit and delete requests.'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangeRequestsPage()),
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

class _MasterItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _MasterItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });
}
