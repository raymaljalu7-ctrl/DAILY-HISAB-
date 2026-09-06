import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _root =>
      _db.collection('sharedData').doc('dailyHisab');

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _root.collection(name);

  Map<String, dynamic> _withUser(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;

    return {
      ...data,
      'createdBy': data['createdBy'] ?? user?.uid,
      'createdByEmail': data['createdByEmail'] ?? user?.email,
      'deletionRequested': data['deletionRequested'] ?? false,
      'updatedBy': user?.uid,
      'updatedByEmail': user?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Stream<List<Map<String, dynamic>>> stream(String name) {
    return collection(name).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  Future<String> add(
    String name,
    Map<String, dynamic> data,
  ) async {
    final doc = await collection(name).add(
      _withUser({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );

    return doc.id;
  }

  Future<void> update(
    String name,
    String id,
    Map<String, dynamic> data,
  ) async {
    final reference = collection(name).doc(id);
    final snapshot = await reference.get();
    final existing = snapshot.data() ?? {};

    await reference.update({
      ...data,
      'createdBy': existing['createdBy'],
      'createdByEmail': existing['createdByEmail'],
      'deletionRequested':
          existing['deletionRequested'] ?? false,
      'deletionRequestedBy':
          existing['deletionRequestedBy'],
      'deletionRequestedByEmail':
          existing['deletionRequestedByEmail'],
      'updatedBy':
          FirebaseAuth.instance.currentUser?.uid,
      'updatedByEmail':
          FirebaseAuth.instance.currentUser?.email,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(
    String name,
    String id,
  ) async {
    await collection(name).doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> query(
    String name,
  ) {
    return collection(name).snapshots();
  }
}
