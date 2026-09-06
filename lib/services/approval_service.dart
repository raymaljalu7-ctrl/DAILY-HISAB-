import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApprovalService {
  ApprovalService._();
  static final ApprovalService instance = ApprovalService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('changeRequests');

  Future<String> requestEdit({
    required String collection,
    required String recordId,
    required Map<String, dynamic> currentData,
    required Map<String, dynamic> proposedData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final doc = await _requests.add({
      'action': 'edit',
      'collection': collection,
      'recordId': recordId,
      'currentData': currentData,
      'proposedData': proposedData,
      'requestedBy': user.uid,
      'requestedByEmail': user.email,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<String> requestDelete({
    required String collection,
    required String recordId,
    required Map<String, dynamic> currentData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('User is not signed in.');

    final doc = await _requests.add({
      'action': 'delete',
      'collection': collection,
      'recordId': recordId,
      'currentData': currentData,
      'proposedData': <String, dynamic>{},
      'requestedBy': user.uid,
      'requestedByEmail': user.email,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
