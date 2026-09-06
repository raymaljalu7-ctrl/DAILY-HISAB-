import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'firebase_options.dart';
import 'screens/business_page.dart';
import 'screens/dashboard_page.dart' as v2_dashboard;
import 'screens/transactions_page.dart' as v2_transactions;
import 'screens/reports_page.dart' as v2_reports;
import 'screens/cash_management_page.dart';
import 'services/backup_restore_service.dart';
import 'screens/masters_page.dart';

void main() async {
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
    while (rest.length > 2) { groups.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last';
  }
  return '${negative ? '-' : ''}₹$whole.${parts[1]}';
}

double numValue(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
DateTime asDate(dynamic value) { if (value is Timestamp) return value.toDate(); if (value is DateTime) return value; if (value is String) return DateTime.tryParse(value) ?? DateTime.now(); return DateTime.now(); }
String dateText(dynamic value) { final d = asDate(value); return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'; }
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTimeRange periodRange(String period) { final n = DateTime.now(); if (period == 'Daily') return DateTimeRange(start: DateTime(n.year,n.month,n.day),end: DateTime(n.year,n.month,n.day,23,59,59)); if(period=='Quarterly'){final m=((n.month-1)~/3)*3+1;return DateTimeRange(start:DateTime(n.year,m),end:DateTime(n.year,m+3,0,23,59,59));} if(period=='6 Monthly'){final m=n.month<=6?1:7;return DateTimeRange(start:DateTime(n.year,m),end:DateTime(n.year,m+6,0,23,59,59));} if(period=='Yearly') return DateTimeRange(start:DateTime(n.year),end:DateTime(n.year+1,1,0,23,59,59)); return DateTimeRange(start:DateTime(n.year,n.month),end:DateTime(n.year,n.month+1,0,23,59,59)); }

class DailyHisabApp extends StatelessWidget { const DailyHisabApp({super.key}); @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'Daily Hisab',theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:purple),scaffoldBackgroundColor:const Color(0xFFF7F5FC),inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(),filled:true,fillColor:Colors.white),cardTheme:const CardThemeData(elevation:1,margin:EdgeInsets.zero)),home:const AuthGate()); }

class AuthGate extends StatelessWidget { const AuthGate({super.key}); @override Widget build(BuildContext context) => StreamBuilder<User?>(stream:FirebaseAuth.instance.authStateChanges(),builder:(context,snapshot){if(snapshot.connectionState==ConnectionState.waiting)return const Splash();final user=snapshot.data;if(user==null)return const LoginPage();return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),builder:(context,profile){if(profile.connectionState==ConnectionState.waiting)return const Splash();if(!profile.hasData||!profile.data!.exists)return const AccountPendingPage(message:'Your account is waiting for Admin setup/approval.');final data=profile.data!.data()??{};final status=data['status']?.toString()??'pending';if(status!='approved')return AccountPendingPage(message:status=='disabled'?'Your account has been disabled by Admin.':'Your account is waiting for Admin approval.');return WelcomePage(profile:data);});}); }

class WelcomePage extends StatelessWidget {
  final Map<String,dynamic> profile;
  const WelcomePage({super.key,required this.profile});
  @override Widget build(BuildContext context){
    final retail=profile['role']=='retail_shop_user';
    final shop=profile['shopName']?.toString()??'';
    if(retail) return _RetailWelcome(shop:shop);
    final items=<NavBox>[
      NavBox('DASHBOARD','Business overview',Icons.dashboard_outlined,purple,()=>const v2_dashboard.DashboardPage()),
      NavBox('TRANSACTION','Receipts & payments',Icons.swap_horiz,teal,()=>const v2_transactions.TransactionsPage()),
      NavBox('STOCK MANAGEMENT','Production & shop stock',Icons.inventory_2_outlined,orange,()=>const StockManagementPage()),
      NavBox('CASH MANAGEMENT','Cash & bank',Icons.account_balance_wallet_outlined,blue,()=>const CashManagementPage()),
      NavBox('BUSINESS','Sales, production & expenses',Icons.business_center_outlined,red,()=>const BusinessPage()),
      NavBox('MASTER','Parties, products & workers',Icons.settings_outlined,purple,()=>const MastersPage()),
      NavBox('REPORT','Reports & PDF',Icons.assessment_outlined,teal,()=>const v2_reports.ReportsPage()),
    ];
    if(profile['role']=='admin') items.add(NavBox('ADMIN','Users & approvals',Icons.admin_panel_settings_outlined,orange,()=>const AdminPage()));
    return Scaffold(appBar:AppBar(title:const Text('Daily Hisab'),centerTitle:true,actions:[IconButton(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout),tooltip:'Sign out')]),body:ListView(padding:const EdgeInsets.all(18),children:[const SizedBox(height:8),const Text('Welcome to Daily Hisab',textAlign:TextAlign.center,style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('Select a section to continue',textAlign:TextAlign.center,style:TextStyle(color:Colors.black54)),const SizedBox(height:22),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:items.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.12),itemBuilder:(context,i)=>_navCard(context,items[i]))]));
  }
  Widget _navCard(BuildContext context,NavBox item)=>Card(color:item.color.withValues(alpha:.10),child:InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>item.page())),child:Padding(padding:const EdgeInsets.all(14),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[CircleAvatar(radius:27,backgroundColor:item.color,child:Icon(item.icon,color:Colors.white,size:28)),const SizedBox(height:10),Text(item.title,textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,color:item.color,fontSize:15)),const SizedBox(height:4),Text(item.subtitle,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Colors.black54))]))));
}

class _RetailWelcome extends StatelessWidget { final String shop; const _RetailWelcome({required this.shop}); @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(shop.isEmpty?'Retail Shop':'$shop Shop'),actions:[IconButton(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout))]),body:ListView(padding:const EdgeInsets.all(18),children:[const Text('Retail Operations',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:6),const Text('Only your assigned shop is available.'),const SizedBox(height:20),_RetailCard(title:'RETAIL SALES',icon:Icons.point_of_sale,sub:'Enter customer sales',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SalesPage()))),const SizedBox(height:12),_RetailCard(title:'RETAIL STOCK',icon:Icons.inventory_2,sub:'View and manage your shop stock',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const StockManagementPage()))),const SizedBox(height:12),_RetailCard(title:'REPORTS',icon:Icons.assessment,sub:'View your shop reports',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const v2_reports.ReportsPage()))) ])); }
}
class NavBox { final String title,subtitle; final IconData icon; final Color color; final Widget Function() page; NavBox(this.title,this.subtitle,this.icon,this.color,this.page); }
class _RetailCard extends StatelessWidget { final String title,sub; final IconData icon; final VoidCallback onTap; const _RetailCard({required this.title,required this.icon,required this.sub,required this.onTap}); @override Widget build(BuildContext context)=>Card(child:ListTile(minVerticalPadding:18,leading:CircleAvatar(child:Icon(icon)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(sub),trailing:const Icon(Icons.chevron_right),onTap:onTap)); }

class AccountPendingPage extends StatelessWidget { final String message; const AccountPendingPage({super.key,required this.message}); @override Widget build(BuildContext context)=>Scaffold(body:Center(child:Card(margin:const EdgeInsets.all(24),child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.hourglass_top,size:64,color:orange),const SizedBox(height:16),const Text('Approval Required',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:10),Text(message,textAlign:TextAlign.center),const SizedBox(height:20),FilledButton.icon(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout),label:const Text('SIGN OUT'))])))); }
class Splash extends StatelessWidget { const Splash({super.key}); @override Widget build(BuildContext context)=>const Scaffold(body:Center(child:CircularProgressIndicator())); }

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> { int index=0; @override Widget build(BuildContext context){final uid=FirebaseAuth.instance.currentUser!.uid;return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),builder:(context,snap){final p=snap.data?.data()??{};final admin=p['role']=='admin';final pages=<Widget>[const v2_dashboard.DashboardPage(),const v2_transactions.TransactionsPage(),const BusinessPage(),const MastersPage(),const v2_reports.ReportsPage(),if(admin)const AdminPage()];final destinations=<NavigationDestination>[const NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Dashboard'),const NavigationDestination(icon:Icon(Icons.swap_horiz),label:'Transactions'),const NavigationDestination(icon:Icon(Icons.business_center_outlined),label:'Business'),const NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Masters'),const NavigationDestination(icon:Icon(Icons.assessment_outlined),label:'Reports'),if(admin)const NavigationDestination(icon:Icon(Icons.admin_panel_settings_outlined),selectedIcon:Icon(Icons.admin_panel_settings),label:'Admin')];if(index>=pages.length)index=0;return Scaffold(body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:destinations));});} }

class Repo { static final root=FirebaseFirestore.instance.collection('sharedData').doc('dailyHisab'); static CollectionReference<Map<String,dynamic>> collection(String name)=>root.collection(name); }
