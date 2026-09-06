import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../services/backup_restore_service.dart';
import 'change_requests_page.dart';

class AdminV2Page extends StatefulWidget {
  const AdminV2Page({super.key});
  @override State<AdminV2Page> createState()=>_AdminV2PageState();
}
class _AdminV2PageState extends State<AdminV2Page> {
  final db=FirebaseFirestore.instance;
  void msg(String x){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));}
  Future<void> createUser()async{
    final email=TextEditingController();final pass=TextEditingController();String role='user';
    await showDialog<void>(context:context,builder:(dialog)=>StatefulBuilder(builder:(c,setDialog)=>AlertDialog(
      title:const Text('Create User'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:email,decoration:const InputDecoration(labelText:'Email')),
        TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Temporary Password')),
        DropdownButtonFormField<String>(initialValue:role,items:const[DropdownMenuItem(value:'user',child:Text('Business User')),DropdownMenuItem(value:'retail_shop_user',child:Text('Retail Shop User'))],onChanged:(v)=>setDialog(()=>role=v??'user'),decoration:const InputDecoration(labelText:'Role')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c),child:const Text('CANCEL')),
        FilledButton(onPressed:()async{
          try{
            final app=await Firebase.initializeApp(name:'admin-${DateTime.now().microsecondsSinceEpoch}',options:DefaultFirebaseOptions.currentPlatform);
            final auth=FirebaseAuth.instanceFor(app:app);
            final cred=await auth.createUserWithEmailAndPassword(email:email.text.trim(),password:pass.text);
            await db.collection('users').doc(cred.user!.uid).set({'email':email.text.trim(),'role':role,'status':'pending','createdAt':FieldValue.serverTimestamp()});
            await app.delete();if(c.mounted)Navigator.pop(c);msg('User created and pending approval.');
          }catch(e){msg('Unable to create user: $e');}
        },child:const Text('CREATE')),
      ],
    )));
    email.dispose();pass.dispose();
  }
  Future<void> backup()async{try{final p=await BackupRestoreService.instance.saveBackup();msg(p==null?'Backup cancelled.':'Backup saved successfully.');}catch(e){msg('Backup failed: $e');}}
  Future<void> restore()async{
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Restore Backup'),content:const Text('Records with the same IDs will be overwritten. Continue?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('CANCEL')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('RESTORE'))]));
    if(ok!=true)return;try{final count=await BackupRestoreService.instance.restoreFromFile();msg(count==0?'Restore cancelled.':'$count records restored successfully.');}catch(e){msg('Restore failed: $e');}
  }
  Future<void> status(String id,String value)async{try{await db.collection('users').doc(id).update({'status':value});}catch(e){msg('Unable to update user: $e');}}
  @override Widget build(BuildContext context){
    return Scaffold(appBar:AppBar(title:const Text('Admin'),actions:[IconButton(onPressed:createUser,icon:const Icon(Icons.person_add))]),body:ListView(padding:const EdgeInsets.all(16),children:[
      Card(child:ListTile(leading:const Icon(Icons.approval),title:const Text('Change Approvals'),subtitle:const Text('Approve or reject non-admin edit/delete requests.'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const ChangeRequestsPage())))),
      const SizedBox(height:10),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:backup,icon:const Icon(Icons.backup),label:const Text('TAKE BACKUP'))),const SizedBox(width:10),Expanded(child:FilledButton.icon(onPressed:restore,icon:const Icon(Icons.restore),label:const Text('RESTORE BACKUP')))]),
      const SizedBox(height:18),const Text('User Management',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:db.collection('users').snapshots(),builder:(context,snap){
        if(snap.hasError)return Text('Unable to load users: ${snap.error}');if(!snap.hasData)return const CircularProgressIndicator();
        return Column(children:snap.data!.docs.map((doc){
          final x=doc.data();final st=x['status']?.toString()??'pending';final role=x['role']?.toString()??'user';final self=doc.id==FirebaseAuth.instance.currentUser?.uid;
          return Card(child:ListTile(title:Text(x['email']?.toString()??doc.id),subtitle:Text('Role: $role • Status: $st'),trailing:self?const Text('YOU'):PopupMenuButton<String>(onSelected:(v){if(v=='approve')status(doc.id,'approved');if(v=='disable')status(doc.id,'disabled');if(v=='reactivate')status(doc.id,'approved');},itemBuilder:(context)=>[
            if(st!='approved')const PopupMenuItem(value:'approve',child:Text('Approve')),
            if(st=='approved')const PopupMenuItem(value:'disable',child:Text('Deactivate')),
            if(st=='disabled')const PopupMenuItem(value:'reactivate',child:Text('Reactivate')),
          ])));
        }).toList());
      }),
    ]));
  }
}
