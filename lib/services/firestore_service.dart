import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'approval_service.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _root => _db.collection('sharedData').doc('dailyHisab');
  CollectionReference<Map<String, dynamic>> collection(String name) => _root.collection(name);

  Future<Map<String, dynamic>> _profile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data() ?? {};
  }

  Future<bool> isAdmin() async {
    final p = await _profile();
    return p['status'] == 'approved' && p['role'] == 'admin';
  }

  Future<Map<String, dynamic>> currentProfile() => _profile();

  Map<String, dynamic> _withUser(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    return {...data, 'createdBy': data['createdBy'] ?? user?.uid, 'createdByEmail': data['createdByEmail'] ?? user?.email, 'deletionRequested': data['deletionRequested'] ?? false, 'updatedBy': user?.uid, 'updatedByEmail': user?.email, 'updatedAt': FieldValue.serverTimestamp()};
  }

  Stream<List<Map<String, dynamic>>> stream(String name) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    if (name == 'retailShops') {
      return Stream.fromFuture(_db.collection('users').doc(uid).get()).asyncExpand((profile) {
        final data = profile.data() ?? {};
        if (data['role'] == 'retail_shop_user' && data['shopId'] != null) {
          return collection(name).doc(data['shopId'].toString()).snapshots().map((doc) => doc.exists ? [{'id': doc.id, ...doc.data()!}] : <Map<String, dynamic>>[]);
        }
        return collection(name).snapshots().map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
      });
    }
    return collection(name).snapshots().map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<String> add(String name, Map<String, dynamic> data) async {
    final doc = await collection(name).add(_withUser({...data, 'createdAt': FieldValue.serverTimestamp()}));
    return doc.id;
  }

  Future<void> update(String name, String id, Map<String, dynamic> data) async {
    final reference = collection(name).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('Record not found.');
    final existing = snapshot.data() ?? {};
    if (await isAdmin()) {
      await reference.update({...data, 'createdBy': existing['createdBy'], 'createdByEmail': existing['createdByEmail'], 'deletionRequested': existing['deletionRequested'] ?? false, 'updatedBy': FirebaseAuth.instance.currentUser?.uid, 'updatedByEmail': FirebaseAuth.instance.currentUser?.email, 'updatedAt': FieldValue.serverTimestamp()});
      return;
    }
    await ApprovalService.instance.requestEdit(collection: name, recordId: id, currentData: existing, proposedData: data);
  }

  Future<void> delete(String name, String id) async {
    final reference = collection(name).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) return;
    if (await isAdmin()) { await reference.delete(); return; }
    await ApprovalService.instance.requestDelete(collection: name, recordId: id, currentData: snapshot.data() ?? {});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> query(String name) => collection(name).snapshots();
}
