import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'approval_service.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _root => _db.collection('sharedData').doc('dailyHisab');
  CollectionReference<Map<String, dynamic>> collection(String name) => _root.collection(name);

  Future<Map<String,dynamic>> _profile() async {
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null)return {};
    final s=await _db.collection('users').doc(uid).get();
    return s.data()??{};
  }
  Future<bool> isAdmin() async { final p=await _profile(); return p['role']=='admin'; }
  Future<Map<String,dynamic>> currentProfile()=>_profile();

  Future<Map<String,dynamic>> _withUser(Map<String,dynamic> data) async {
    final u=FirebaseAuth.instance.currentUser;
    final p=await _profile();
    final out=<String,dynamic>{...data,
      'createdBy':data['createdBy']??u?.uid,
      'createdByEmail':data['createdByEmail']??u?.email,
      'deletionRequested':data['deletionRequested']??false,
      'updatedBy':u?.uid,
      'updatedByEmail':u?.email,
      'updatedAt':FieldValue.serverTimestamp(),
    };
    if(p['role']=='retail_shop_user' && (out['shopId']==null || '${out['shopId']}'.isEmpty)) {
      final sid=p['shopId']?.toString();
      if(sid!=null && sid.isNotEmpty) out['shopId']=sid;
    }
    return out;
  }

  Stream<List<Map<String,dynamic>>> stream(String name){
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null)return const Stream.empty();
    final scoped={'sales','transactions','stockTransfers','stockOtherReceived'};
    if(name=='retailShops'){
      return Stream.fromFuture(_db.collection('users').doc(uid).get()).asyncExpand((p){
        final d=p.data()??{};
        if(d['role']=='retail_shop_user'&&d['shopId']!=null) {
          return collection(name).doc(d['shopId'].toString()).snapshots().map((x)=>x.exists?[{'id':x.id,...x.data()!}]:<Map<String,dynamic>>[]);
        }
        return collection(name).snapshots().map((s)=>s.docs.map((d)=>{'id':d.id,...d.data()}).toList());
      });
    }
    if(scoped.contains(name)){
      return Stream.fromFuture(_db.collection('users').doc(uid).get()).asyncExpand((p){
        final d=p.data()??{};
        if(d['role']=='retail_shop_user'&&d['shopId']!=null) {
          return collection(name).where('shopId',isEqualTo:d['shopId'].toString()).snapshots().map((s)=>s.docs.map((x)=>{'id':x.id,...x.data()}).toList());
        }
        return collection(name).snapshots().map((s)=>s.docs.map((x)=>{'id':x.id,...x.data()}).toList());
      });
    }
    return collection(name).snapshots().map((s)=>s.docs.map((d)=>{'id':d.id,...d.data()}).toList());
  }

  Future<String> add(String name,Map<String,dynamic> data) async {
    final d=await collection(name).add(await _withUser({...data,'createdAt':FieldValue.serverTimestamp()}));
    return d.id;
  }
  Future<void> update(String name,String id,Map<String,dynamic> data) async {
    final r=collection(name).doc(id);final s=await r.get();if(!s.exists)throw StateError('Record not found.');
    final old=s.data()??{};
    if(await isAdmin()) { await r.update({...data,'createdBy':old['createdBy'],'createdByEmail':old['createdByEmail'],'deletionRequested':old['deletionRequested']??false,'updatedBy':FirebaseAuth.instance.currentUser?.uid,'updatedByEmail':FirebaseAuth.instance.currentUser?.email,'updatedAt':FieldValue.serverTimestamp()});return; }
    await ApprovalService.instance.requestEdit(collection:name,recordId:id,currentData:old,proposedData:data);
  }
  Future<void> delete(String name,String id) async { final r=collection(name).doc(id);final s=await r.get();if(!s.exists)return;if(await isAdmin()){await r.delete();return;}await ApprovalService.instance.requestDelete(collection:name,recordId:id,currentData:s.data()??{}); }
  Stream<QuerySnapshot<Map<String,dynamic>>> query(String name)=>collection(name).snapshots();
}
