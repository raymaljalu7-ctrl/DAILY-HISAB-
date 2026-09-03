import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DailyHisabApp());
}

const purple = Color(0xFF6C4AB6);
const teal = Color(0xFF00A896);
const orange = Color(0xFFFF8C42);
const blue = Color(0xFF3A86FF);
const red = Color(0xFFE85D75);

String money(dynamic value) {
  final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  final negative = n < 0;
  final text = n.abs().toStringAsFixed(2);
  final parts = text.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last';
  }
  return '${negative ? '-' : ''}₹$whole.${parts[1]}';
}

double numValue(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

String dateText(dynamic value) {
  final d = asDate(value);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTimeRange periodRange(String period) {
  final n = DateTime.now();
  if (period == 'Daily') {
    return DateTimeRange(
      start: DateTime(n.year, n.month, n.day),
      end: DateTime(n.year, n.month, n.day, 23, 59, 59),
    );
  }
  if (period == 'Quarterly') {
    final m = ((n.month - 1) ~/ 3) * 3 + 1;
    return DateTimeRange(
      start: DateTime(n.year, m),
      end: DateTime(n.year, m + 3, 0, 23, 59, 59),
    );
  }
  if (period == '6 Monthly') {
    final m = n.month <= 6 ? 1 : 7;
    return DateTimeRange(
      start: DateTime(n.year, m),
      end: DateTime(n.year, m + 6, 0, 23, 59, 59),
    );
  }
  if (period == 'Yearly') {
    return DateTimeRange(
      start: DateTime(n.year),
      end: DateTime(n.year + 1, 1, 0, 23, 59, 59),
    );
  }
  return DateTimeRange(
    start: DateTime(n.year, n.month),
    end: DateTime(n.year, n.month + 1, 0, 23, 59, 59),
  );
}

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
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero),
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Splash();
        return snapshot.hasData ? const HomePage() : const LoginPage();
      },
    );
  }
}

class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class Repo {
  static final root = FirebaseFirestore.instance
      .collection('sharedData')
      .doc('dailyHisab');
  static CollectionReference<Map<String, dynamic>> collection(String name) =>
      root.collection(name);

  static Map<String, dynamic> withUser(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    return {
      ...data,
      'createdBy': data['createdBy'] ?? user?.uid,
      'createdByEmail': data['createdByEmail'] ?? user?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Stream<List<Map<String, dynamic>>> stream(String name) {
    return collection(name).snapshots().map((snapshot) {
      final list = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) => asDate(b['date']).compareTo(asDate(a['date'])));
      return list;
    });
  }

  static Future<void> add(String name, Map<String, dynamic> data) async {
    await collection(name)
        .add(withUser({...data, 'createdAt': FieldValue.serverTimestamp()}));
  }

  static Future<void> update(
    String name,
    String id,
    Map<String, dynamic> data,
  ) async {
    await collection(name).doc(id).update(withUser(data));
  }

  static Future<void> delete(String name, String id) =>
      collection(name).doc(id).delete();
}

void snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool create = false, busy = false, showPassword = false;

  Future<void> submit() async {
    if (!email.text.contains('@') || password.text.length < 6) {
      snack(
        context,
        'Enter a valid email and password of at least 6 characters.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (create) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) snack(context, e.message ?? e.code);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF432371), Color(0xFF7B4BB7), Color(0xFF00A896)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [purple, teal]),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Daily Hisab',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Text('Shared business accounting'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: !showPassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: busy ? null : submit,
                          child: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(create ? 'CREATE ACCOUNT' : 'LOGIN'),
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => create = !create),
                        child: Text(
                          create
                              ? 'Already have an account? Login'
                              : 'New user? Create account',
                        ),
                      ),
                      const Text(
                        'All authorized users see the same live business data.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  final pages = const [
    DashboardPage(),
    TransactionsPage(),
    PartiesPage(),
    ProductionPage(),
    ReportsPage(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Parties',
          ),
          NavigationDestination(
            icon: Icon(Icons.factory_outlined),
            label: 'Production',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class PageTitle extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const PageTitle(this.title, {super.key, this.actions});
  @override
  Size get preferredSize => const Size.fromHeight(68);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    actions: actions,
    backgroundColor: Colors.transparent,
    elevation: 0,
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String period = 'Monthly';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageTitle(
        'Daily Hisab',
        actions: [
          IconButton(
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'Daily Hisab',
              applicationVersion: '1.0',
            ),
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Repo.stream('transactions'),
        builder: (context, txSnap) {
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: Repo.stream('parties'),
            builder: (context, partySnap) {
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: Repo.stream('production'),
                builder: (context, prodSnap) {
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Repo.stream('productionExpenses'),
                    builder: (context, expSnap) => _body(
                      context,
                      txSnap.data ?? [],
                      partySnap.data ?? [],
                      prodSnap.data ?? [],
                      expSnap.data ?? [],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<Map<String, dynamic>> tx,
    List<Map<String, dynamic>> parties,
    List<Map<String, dynamic>> production,
    List<Map<String, dynamic>> expenses,
  ) {
    final range = periodRange(period);
    final filtered = tx
        .where(
          (x) =>
              !asDate(x['date']).isBefore(range.start) &&
              !asDate(x['date']).isAfter(range.end),
        )
        .toList();
    final receipts = filtered
        .where((x) => x['type'] == 'Receipt')
        .fold<double>(0, (s, x) => s + numValue(x['amount']));
    final payments = filtered
        .where((x) => x['type'] == 'Payment')
        .fold<double>(0, (s, x) => s + numValue(x['amount']));
    final cash = filtered
        .where((x) => x['account'] == 'Cash')
        .fold<double>(
          0,
          (s, x) =>
              s +
              (x['type'] == 'Receipt'
                  ? numValue(x['amount'])
                  : -numValue(x['amount'])),
        );
    final bank = filtered
        .where((x) => x['account'] == 'Bank')
        .fold<double>(
          0,
          (s, x) =>
              s +
              (x['type'] == 'Receipt'
                  ? numValue(x['amount'])
                  : -numValue(x['amount'])),
        );
    final receivable = parties
        .where((x) => x['openingType'] == 'Receivable')
        .fold<double>(0, (s, x) => s + numValue(x['opening']));
    final payable = parties
        .where((x) => x['openingType'] == 'Payable')
        .fold<double>(0, (s, x) => s + numValue(x['opening']));
    final productionQty = production
        .where(
          (x) =>
              !asDate(x['date']).isBefore(range.start) &&
              !asDate(x['date']).isAfter(range.end),
        )
        .fold<double>(0, (s, x) => s + numValue(x['quantity']));
    final productionExpense = expenses
        .where(
          (x) =>
              !asDate(x['date']).isBefore(range.start) &&
              !asDate(x['date']).isAfter(range.end),
        )
        .fold<double>(0, (s, x) => s + numValue(x['amount']));

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [purple, teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Live shared data • ${FirebaseAuth.instance.currentUser?.email ?? ''}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: period,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(
                    labelText: 'Dashboard Period',
                    fillColor: Colors.white,
                  ),
                  items:
                      const [
                            'Daily',
                            'Monthly',
                            'Quarterly',
                            '6 Monthly',
                            'Yearly',
                          ]
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                  onChanged: (x) => setState(() => period = x!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: [
              MetricCard(
                'Receipts',
                money(receipts),
                Icons.arrow_downward,
                teal,
              ),
              MetricCard('Payments', money(payments), Icons.arrow_upward, red),
              MetricCard(
                'Net Balance',
                money(receipts - payments),
                Icons.account_balance_wallet,
                purple,
              ),
              MetricCard('Cash', money(cash), Icons.payments, orange),
              MetricCard('Bank', money(bank), Icons.account_balance, blue),
              MetricCard(
                'Receivable',
                money(receivable),
                Icons.call_received,
                teal,
              ),
              MetricCard('Payable', money(payable), Icons.call_made, red),
              MetricCard(
                'Production',
                '${productionQty.toStringAsFixed(2)} units',
                Icons.factory,
                purple,
              ),
              MetricCard(
                'Prod. Expenses',
                money(productionExpense),
                Icons.receipt_long,
                orange,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            const EmptyState(
              'No transactions yet',
              'Add a receipt or payment from Transactions.',
            )
          else
            ...filtered
                .take(5)
                .map(
                  (x) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: x['type'] == 'Receipt'
                            ? teal.withValues(alpha: .12)
                            : red.withValues(alpha: .12),
                        child: Icon(
                          x['type'] == 'Receipt'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: x['type'] == 'Receipt' ? teal : red,
                        ),
                      ),
                      title: Text('${x['type']} • ${money(x['amount'])}'),
                      subtitle: Text(
                        '${dateText(x['date'])} • ${x['party'] ?? 'No party'}',
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const MetricCard(this.title, this.value, this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: 19),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.black54)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageTitle(
        'Transactions',
        actions: [
          IconButton(
            onPressed: () => transactionDialog(context),
            icon: const Icon(Icons.add_circle),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Repo.stream('transactions'),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final q = search.toLowerCase();
          final list = all.where((x) {
            return q.isEmpty ||
                '${x['party'] ?? ''} ${x['note'] ?? ''} ${x['type']}'
                    .toLowerCase()
                    .contains(q);
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search transactions',
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        'No transactions',
                        'Tap + to add your first receipt or payment.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final x = list[i];
                          final receipt = x['type'] == 'Receipt';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (receipt ? teal : red)
                                    .withValues(alpha: .12),
                                child: Icon(
                                  receipt
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: receipt ? teal : red,
                                ),
                              ),
                              title: Text(
                                '${x['type']} • ${money(x['amount'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${dateText(x['date'])} • ${x['account']} • ${x['party'] ?? 'No party'}\n${x['note'] ?? ''}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    transactionDialog(context, existing: x);
                                  }
                                  if (v == 'delete') {
                                    confirmDelete(
                                      context,
                                      'transactions',
                                      x['id'],
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> transactionDialog(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final date = TextEditingController(text: isoDate(asDate(existing?['date'])));
  final amount = TextEditingController(
    text: existing == null ? '' : '${existing['amount']}',
  );
  final party = TextEditingController(
    text: existing?['party']?.toString() ?? '',
  );
  final note = TextEditingController(text: existing?['note']?.toString() ?? '');
  String type = existing?['type']?.toString() ?? 'Receipt';
  String account = existing?['account']?.toString() ?? 'Cash';

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Add Transaction' : 'Edit Transaction',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const ['Receipt', 'Payment']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (x) => set(() => type = x!),
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: account,
                    items: const ['Cash', 'Bank']
                        .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                        .toList(),
                    onChanged: (x) => set(() => account = x!),
                    decoration: const InputDecoration(labelText: 'Account'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: party,
                    decoration: const InputDecoration(
                      labelText: 'Party (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Description / Note',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: date,
                    decoration: const InputDecoration(
                      labelText: 'Date (YYYY-MM-DD)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final d = DateTime.tryParse(date.text) ?? DateTime.now();
                  final a = numValue(amount.text);
                  if (a <= 0) {
                    snack(ctx, 'Enter an amount greater than zero.');
                    return;
                  }
                  final data = {
                    'date': Timestamp.fromDate(d),
                    'type': type,
                    'amount': a,
                    'account': account,
                    'party': party.text.trim(),
                    'note': note.text.trim(),
                  };
                  if (existing == null) {
                    await Repo.add('transactions', data);
                  } else {
                    await Repo.update('transactions', existing['id'], data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'SAVE' : 'UPDATE'),
              ),
            ],
          );
        },
      );
    },
  );
}

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageTitle(
        'Parties',
        actions: [
          IconButton(
            onPressed: () => partyDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Repo.stream('parties'),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final list = all.where((x) {
            final text = '${x['name']} ${x['phone'] ?? ''}'.toLowerCase();
            return search.isEmpty || text.contains(search.toLowerCase());
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (v) => setState(() => search = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search party',
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        'No parties',
                        'Add customers, suppliers or other parties.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final x = list[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: purple.withValues(alpha: .12),
                                child: const Icon(Icons.person, color: purple),
                              ),
                              title: Text(
                                x['name'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${x['phone'] ?? ''}\nOpening: ${money(x['opening'])} ${x['openingType']}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    partyDialog(context, existing: x);
                                  } else if (v == 'delete') {
                                    confirmDelete(context, 'parties', x['id']);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> partyDialog(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final name = TextEditingController(text: existing?['name']?.toString() ?? '');
  final phone = TextEditingController(
    text: existing?['phone']?.toString() ?? '',
  );
  final opening = TextEditingController(
    text: existing == null ? '0' : '${existing['opening']}',
  );
  String openingType = existing?['openingType']?.toString() ?? 'Receivable';

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(existing == null ? 'Add Party' : 'Edit Party'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Party Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: opening,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Opening Balance'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: openingType,
                items: const ['Receivable', 'Payable']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                    .toList(),
                onChanged: (x) => set(() => openingType = x!),
                decoration: const InputDecoration(labelText: 'Opening Type'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                snack(ctx, 'Enter party name.');
                return;
              }
              final data = {
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'opening': numValue(opening.text),
                'openingType': openingType,
              };
              if (existing == null) {
                await Repo.add('parties', data);
              } else {
                await Repo.update('parties', existing['id'], data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'SAVE' : 'UPDATE'),
          ),
        ],
      ),
    ),
  );
}

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});
  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  int section = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PageTitle(
      'Production',
      actions: [
        IconButton(
          onPressed: () => section == 0
              ? productionDialog(context)
              : productionExpenseDialog(context),
          icon: const Icon(Icons.add_circle),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Production'),
                icon: Icon(Icons.factory),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Production Expenses'),
                icon: Icon(Icons.receipt_long),
              ),
            ],
            selected: {section},
            onSelectionChanged: (s) => setState(() => section = s.first),
          ),
        ),
        Expanded(
          child: section == 0
              ? const ProductionList()
              : const ProductionExpenseList(),
        ),
      ],
    ),
  );
}

class ProductionList extends StatelessWidget {
  const ProductionList({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: Repo.stream('production'),
    builder: (context, snap) {
      final list = snap.data ?? [];
      if (list.isEmpty)
        return const EmptyState(
          'No production records',
          'Add your production quantity and unit.',
        );
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, i) {
          final x = list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.factory)),
              title: Text(
                '${x['product']} • ${numValue(x['quantity']).toStringAsFixed(2)} ${x['unit']}',
              ),
              subtitle: Text(dateText(x['date'])),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') productionDialog(context, existing: x);
                  if (v == 'delete')
                    confirmDelete(context, 'production', x['id']);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> productionDialog(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final product = TextEditingController(
    text: existing?['product']?.toString() ?? '',
  );
  final quantity = TextEditingController(
    text: existing == null ? '' : '${existing['quantity']}',
  );
  final unit = TextEditingController(
    text: existing?['unit']?.toString() ?? 'kg',
  );
  final date = TextEditingController(text: isoDate(asDate(existing?['date'])));

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Add Production' : 'Edit Production'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: product,
              decoration: const InputDecoration(labelText: 'Product'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: unit,
              decoration: const InputDecoration(labelText: 'Unit'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final data = {
              'product': product.text.trim(),
              'quantity': numValue(quantity.text),
              'unit': unit.text.trim(),
              'date': Timestamp.fromDate(
                DateTime.tryParse(date.text) ?? DateTime.now(),
              ),
            };
            if (existing == null) {
              await Repo.add('production', data);
            } else {
              await Repo.update('production', existing['id'], data);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(existing == null ? 'SAVE' : 'UPDATE'),
        ),
      ],
    ),
  );
}

class ProductionExpenseList extends StatelessWidget {
  const ProductionExpenseList({super.key});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: Repo.stream('productionExpenses'),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty)
            return const EmptyState(
              'No production expenses',
              'Add expenses connected with production.',
            );
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final x = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                  title: Text('${x['name']} • ${money(x['amount'])}'),
                  subtitle: Text(
                    '${dateText(x['date'])}\n${x['description'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit')
                        productionExpenseDialog(context, existing: x);
                      if (v == 'delete')
                        confirmDelete(context, 'productionExpenses', x['id']);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
}

Future<void> productionExpenseDialog(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final name = TextEditingController(text: existing?['name']?.toString() ?? '');
  final amount = TextEditingController(
    text: existing == null ? '' : '${existing['amount']}',
  );
  final date = TextEditingController(text: isoDate(asDate(existing?['date'])));
  final description = TextEditingController(
    text: existing?['description']?.toString() ?? '',
  );

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        existing == null ? 'Production Expense' : 'Edit Production Expense',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Expense Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: date,
              decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final data = {
              'name': name.text.trim(),
              'amount': numValue(amount.text),
              'date': Timestamp.fromDate(
                DateTime.tryParse(date.text) ?? DateTime.now(),
              ),
              'description': description.text.trim(),
            };
            if (existing == null) {
              await Repo.add('productionExpenses', data);
            } else {
              await Repo.update('productionExpenses', existing['id'], data);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(existing == null ? 'SAVE' : 'UPDATE'),
        ),
      ],
    ),
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String report = 'Summary';
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  String? party;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: const PageTitle('Reports'),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: Repo.stream('transactions'),
      builder: (context, tx) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: Repo.stream('parties'),
        builder: (context, parties) =>
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: Repo.stream('production'),
              builder: (context, production) =>
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: Repo.stream('productionExpenses'),
                    builder: (context, expenses) => _view(
                      context,
                      tx.data ?? [],
                      parties.data ?? [],
                      production.data ?? [],
                      expenses.data ?? [],
                    ),
                  ),
            ),
      ),
    ),
  );

  Widget _view(
    BuildContext context,
    List<Map<String, dynamic>> tx,
    List<Map<String, dynamic>> parties,
    List<Map<String, dynamic>> production,
    List<Map<String, dynamic>> expenses,
  ) {
    final list = tx.where((x) {
      final d = asDate(x['date']);
      return !d.isBefore(DateTime(from.year, from.month, from.day)) &&
          !d.isAfter(DateTime(to.year, to.month, to.day, 23, 59, 59));
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: report,
          items: const [
            'Summary',
            'Transactions',
            'Party-wise',
            'Party Statement',
            'Outstanding',
            'Production',
            'Production Expenses',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (x) => setState(() => report = x!),
          decoration: const InputDecoration(labelText: 'Report Type'),
        ),
        const SizedBox(height: 12),
        _dateRow(context, 'From', from, (d) => setState(() => from = d)),
        _dateRow(context, 'To', to, (d) => setState(() => to = d)),
        if (report == 'Party Statement') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: party,
            items: parties
                .map(
                  (x) => DropdownMenuItem(
                    value: x['name'].toString(),
                    child: Text(x['name'].toString()),
                  ),
                )
                .toList(),
            onChanged: (x) => setState(() => party = x),
            decoration: const InputDecoration(labelText: 'Party'),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('GENERATE'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: () => createPdf(report, list),
              icon: const Icon(Icons.picture_as_pdf),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _reportBody(list, parties, production, expenses),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => copyReport(report, list),
          icon: const Icon(Icons.copy),
          label: const Text('COPY REPORT'),
        ),
      ],
    );
  }

  Widget _dateRow(
    BuildContext context,
    String label,
    DateTime value,
    void Function(DateTime) change,
  ) => Row(
    children: [
      Expanded(child: Text('$label: ${dateText(value)}')),
      TextButton(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            initialDate: value,
          );
          if (d != null) change(d);
        },
        child: const Text('Change'),
      ),
    ],
  );

  Widget _reportBody(
    List<Map<String, dynamic>> tx,
    List<Map<String, dynamic>> parties,
    List<Map<String, dynamic>> production,
    List<Map<String, dynamic>> expenses,
  ) {
    final receipts = tx
        .where((x) => x['type'] == 'Receipt')
        .fold<double>(0, (s, x) => s + numValue(x['amount']));
    final payments = tx
        .where((x) => x['type'] == 'Payment')
        .fold<double>(0, (s, x) => s + numValue(x['amount']));
    if (report == 'Summary')
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Summary',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Receipts: ${money(receipts)}'),
          Text('Payments: ${money(payments)}'),
          Text('Net: ${money(receipts - payments)}'),
          Text('Transactions: ${tx.length}'),
        ],
      );
    if (report == 'Transactions')
      return _lines(
        tx
            .map(
              (x) =>
                  '${dateText(x['date'])} • ${x['type']} • ${money(x['amount'])} • ${x['party'] ?? ''}',
            )
            .toList(),
      );
    if (report == 'Party-wise') {
      final names = <String>{
        ...parties.map((x) => x['name'].toString()),
        ...tx.map((x) => x['party']?.toString() ?? ''),
      }..remove('');
      return _lines(
        names.map((name) {
          final rows = tx.where((x) => x['party'] == name);
          final r = rows
              .where((x) => x['type'] == 'Receipt')
              .fold<double>(0, (s, x) => s + numValue(x['amount']));
          final p = rows
              .where((x) => x['type'] == 'Payment')
              .fold<double>(0, (s, x) => s + numValue(x['amount']));
          return '$name  |  Receipt ${money(r)}  |  Payment ${money(p)}  |  Net ${money(r - p)}';
        }).toList(),
      );
    }
    if (report == 'Outstanding')
      return _lines(
        parties
            .map(
              (x) =>
                  '${x['name']} • ${x['openingType']} • ${money(x['opening'])}',
            )
            .toList(),
      );
    if (report == 'Production')
      return _lines(
        production
            .where(
              (x) =>
                  !asDate(x['date']).isBefore(from) &&
                  !asDate(x['date']).isAfter(to.add(const Duration(days: 1))),
            )
            .map(
              (x) =>
                  '${dateText(x['date'])} • ${x['product']} • ${x['quantity']} ${x['unit']}',
            )
            .toList(),
      );
    if (report == 'Production Expenses')
      return _lines(
        expenses
            .where(
              (x) =>
                  !asDate(x['date']).isBefore(from) &&
                  !asDate(x['date']).isAfter(to.add(const Duration(days: 1))),
            )
            .map(
              (x) =>
                  '${dateText(x['date'])} • ${x['name']} • ${money(x['amount'])}',
            )
            .toList(),
      );
    if (party == null) return const Text('Select a party for its statement.');
    final rows = tx.where((x) => x['party'] == party).toList();
    final opening = parties.firstWhere(
      (x) => x['name'] == party,
      orElse: () => {'opening': 0},
    )['opening'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Party: $party',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text('Opening: ${money(opening)}'),
        const SizedBox(height: 8),
        ...rows.map(
          (x) => Text(
            '${dateText(x['date'])} • ${x['type']} • ${money(x['amount'])}',
          ),
        ),
      ],
    );
  }

  Widget _lines(List<String> lines) => lines.isEmpty
      ? const Text('No records for this report.')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map(
                (x) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(x),
                ),
              )
              .toList(),
        );
}

Future<void> copyReport(String type, List<Map<String, dynamic>> tx) async {
  final buffer = StringBuffer('Daily Hisab - $type\n');
  for (final x in tx) {
    buffer.writeln(
      '${dateText(x['date'])} • ${x['type']} • ${money(x['amount'])} • ${x['party'] ?? ''}',
    );
  }
  await Clipboard.setData(ClipboardData(text: buffer.toString()));
}

Future<void> createPdf(String type, List<Map<String, dynamic>> tx) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, text: 'Daily Hisab - $type'),
        pw.Paragraph(text: 'Generated ${dateText(DateTime.now())}'),
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Type', 'Party', 'Amount'],
          data: tx
              .map(
                (x) => [
                  dateText(x['date']),
                  '${x['type']}',
                  '${x['party'] ?? ''}',
                  money(x['amount']),
                ],
              )
              .toList(),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => doc.save(),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  const EmptyState(this.title, this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

Future<void> confirmDelete(
  BuildContext context,
  String collection,
  String id,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete record?'),
      content: const Text(
        'This record will be removed for all authorized users.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok == true) await Repo.delete(collection, id);
}
