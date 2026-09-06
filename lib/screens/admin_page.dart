import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../services/backup_restore_service.dart';
import 'change_requests_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final db = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>> get _users => db.collection('users').snapshots();

  Future<List<Map<String, dynamic>>> _shops() async {
    final snap = await db.collection('sharedData').doc('dailyHisab').collection('retailShops').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).where((x) => x['active'] != false).toList();
  }

  Future<void> _createUser() async {
    final email = TextEditingController();
    final password = TextEditingController();
    String role = 'user';
    String? shopId;
    String? shopName;
    final shops = await _shops();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary Password')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'Role'), items: const [
                DropdownMenuItem(value: 'user', child: Text('Business User')),
                DropdownMenuItem(value: 'retail_shop_user', child: Text('Retail Shop User')),
              ], onChanged: (v) => setDialog(() {
                role = v ?? 'user';
                if (role != 'retail_shop_user') { shopId = null; shopName = null; }
              })),
              if (role == 'retail_shop_user') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(initialValue: shopId, decoration: const InputDecoration(labelText: 'Assigned Retail Shop'), items: shops.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text(s['name']?.toString() ?? 'Shop'))).toList(), onChanged: (v) {
                  Map<String, dynamic>? found;
                  for (final s in shops) { if (s['id'].toString() == v) { found = s; break; } }
                  setDialog(() { shopId = v; shopName = found?['name']?.toString(); });
                }),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            FilledButton(onPressed: () async {
              final e = email.text.trim();
              if (!e.contains('@') || password.text.length < 6) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter valid email and password of at least 6 characters.')));
                return;
              }
              if (role == 'retail_shop_user' && shopId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Select the retail shop.')));
                return;
              }
              try {
                final app = await Firebase.initializeApp(name: 'admin-create-${DateTime.now().microsecondsSinceEpoch}', options: DefaultFirebaseOptions.currentPlatform);
                final auth = FirebaseAuth.instanceFor(app: app);
                final cred = await auth.createUserWithEmailAndPassword(email: e, password: password.text);
                await db.collection('users').doc(cred.user!.uid).set({
                  'email': e, 'role': role, 'status': 'pending',
                  if (shopId != null) 'shopId': shopId,
                  if (shopName != null) 'shopName': shopName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                await app.delete();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created and sent for approval.')));
              } on FirebaseAuthException catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message ?? e.code)));
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Unable to create user: $e')));
              }
            }, child: const Text('CREATE')),
          ],
        ),
      ),
    );
    email.dispose();
    password.dispose();
  }

  Future<void> _editUser(String uid, Map<String, dynamic> current) async {
    String role = current['role']?.toString() ?? 'user';
    String? shopId = current['shopId']?.toString();
    String? shopName = current['shopName']?.toString();
    final shops = await _shops();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Edit User Access'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'Role'), items: const [
              DropdownMenuItem(value: 'user', child: Text('Business User')),
              DropdownMenuItem(value: 'retail_shop_user', child: Text('Retail Shop User')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ], onChanged: (v) => setDialog(() {
              role = v ?? 'user';
              if (role != 'retail_shop_user') { shopId = null; shopName = null; }
            })),
            if (role == 'retail_shop_user') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(initialValue: shops.any((s) => s['id'].toString() == shopId) ? shopId : null, decoration: const InputDecoration(labelText: 'Assigned Retail Shop'), items: shops.map((s) => DropdownMenuItem<String>(value: s['id'].toString(), child: Text(s['name']?.toString() ?? 'Shop'))).toList(), onChanged: (v) {
                Map<String, dynamic>? found;
                for (final s in shops) { if (s['id'].toString() == v) { found = s; break; } }
                setDialog(() { shopId = v; shopName = found?['name']?.toString(); });
              }),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            FilledButton(onPressed: () async {
              await db.collection('users').doc(uid).update({'role': role, 'shopId': shopId, 'shopName': shopName});
              if (ctx.mounted) Navigator.pop(ctx);
            }, child: const Text('SAVE')),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(String uid, String status) => db.collection('users').doc(uid).update({'status': status});

  Future<void> _backup() async {
    try {
      final path = await BackupRestoreService.instance.saveBackup();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? 'Backup cancelled.' : 'Backup saved successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin'), actions: [IconButton(onPressed: _createUser, icon: const Icon(Icons.person_add_alt_1), tooltip: 'Create User')]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.admin_panel_settings)), title: Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Create users, assign retail shops, approve and deactivate access.'))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeRequestsPage())), icon: const Icon(Icons.approval), label: const Text('CHANGE APPROVALS'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: _backup, icon: const Icon(Icons.backup_outlined), label: const Text('TAKE BACKUP'))),
      ]),
      const SizedBox(height: 18),
      const Text('Users', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _users,
        builder: (context, snap) {
          if (snap.hasError) return Text('Unable to load users: ${snap.error}');
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('No users found.'));
          return Column(children: docs.map((doc) {
            final p = doc.data();
            final role = p['role']?.toString() ?? 'user';
            final status = p['status']?.toString() ?? 'pending';
            final self = doc.id == FirebaseAuth.instance.currentUser?.uid;
            final shopText = p['shopName'] == null ? '' : '\nShop: ${p['shopName']}';
            return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              leading: CircleAvatar(child: Icon(role == 'retail_shop_user' ? Icons.store : role == 'admin' ? Icons.admin_panel_settings : Icons.person)),
              title: Text(p['email']?.toString() ?? doc.id, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Role: $role\nStatus: $status$shopText'), isThreeLine: true,
              trailing: self ? const Text('YOU') : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editUser(doc.id, p);
                  if (v == 'approve') _setStatus(doc.id, 'approved');
                  if (v == 'disable') _setStatus(doc.id, 'disabled');
                  if (v == 'reactivate') _setStatus(doc.id, 'approved');
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Access')),
                  if (status != 'approved') const PopupMenuItem(value: 'approve', child: Text('Approve')),
                  if (status == 'approved') const PopupMenuItem(value: 'disable', child: Text('Deactivate')),
                  if (status == 'disabled') const PopupMenuItem(value: 'reactivate', child: Text('Reactivate')),
                ],
              ),
            ));
          }).toList());
        },
      ),
    ]),
  );
}
