import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangeRequestsPage extends StatelessWidget {
  const ChangeRequestsPage({super.key});

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('changeRequests');

  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  bool _sameVersion(dynamic requestVersion, dynamic recordVersion) {
    if (requestVersion == null && recordVersion == null) return true;
    if (requestVersion is Timestamp && recordVersion is Timestamp) {
      return requestVersion.seconds == recordVersion.seconds && requestVersion.nanoseconds == recordVersion.nanoseconds;
    }
    return requestVersion?.toString() == recordVersion?.toString();
  }

  Future<void> _approve(BuildContext context, DocumentSnapshot<Map<String, dynamic>> request) async {
    final data = request.data() ?? {};
    final action = data['action']?.toString() ?? '';
    final collection = data['collection']?.toString() ?? '';
    final recordId = data['recordId']?.toString() ?? '';
    if (action != 'edit' && action != 'delete') return;
    if (collection.isEmpty || recordId.isEmpty) return;

    final recordRef = _db.collection('sharedData').doc('dailyHisab').collection(collection).doc(recordId);
    final requestRef = request.reference;
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;

    try {
      await _db.runTransaction((tx) async {
        final requestSnap = await tx.get(requestRef);
        if (!requestSnap.exists) throw StateError('Change request no longer exists.');
        final requestData = requestSnap.data() ?? {};
        if (requestData['status']?.toString() != 'pending') throw StateError('This request has already been processed.');

        final recordSnap = await tx.get(recordRef);
        final baseVersion = requestData['baseUpdatedAt'];
        final currentRecord = recordSnap.data() ?? {};

        if (action == 'delete') {
          if (!recordSnap.exists) throw StateError('Record was already deleted.');
          if (!_sameVersion(baseVersion, currentRecord['updatedAt'])) {
            throw StateError('Record changed after this request was submitted. Reject it and submit a new request.');
          }
          tx.delete(recordRef);
        } else {
          if (!recordSnap.exists) throw StateError('Record no longer exists.');
          if (!_sameVersion(baseVersion, currentRecord['updatedAt'])) {
            throw StateError('Record changed after this request was submitted. Reject it and submit a new request.');
          }
          final proposed = _map(requestData['proposedData']);
          proposed.remove('id');
          proposed.remove('createdAt');
          proposed.remove('createdBy');
          proposed.remove('createdByEmail');
          proposed.remove('deletionRequested');
          proposed.remove('deletionRequestedBy');
          proposed.remove('deletionRequestedByEmail');
          proposed['updatedBy'] = admin.uid;
          proposed['updatedByEmail'] = admin.email;
          proposed['updatedAt'] = FieldValue.serverTimestamp();
          tx.update(recordRef, proposed);
        }

        // Processed requests are removed from the approval queue so they cannot
        // remain visible after approval/rejection.
        tx.delete(requestRef);
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'delete' ? 'Delete request approved.' : 'Edit request approved.')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
    }
  }

  Future<void> _reject(BuildContext context, DocumentSnapshot<Map<String, dynamic>> request) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;
    try {
      // A rejected request is no longer actionable, so remove it from the queue.
      await request.reference.delete();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejection failed: $e')));
    }
  }

  String _label(Map<String, dynamic> data) {
    final action = data['action']?.toString() ?? 'request';
    final collection = data['collection']?.toString() ?? '';
    return '${action.toUpperCase()} • $collection';
  }

  String _details(Map<String, dynamic> data) {
    final recordId = data['recordId']?.toString() ?? '';
    final email = data['requestedByEmail']?.toString() ?? '';
    return 'Record: $recordId\nRequested by: $email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Approvals')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests.where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load requests:\n${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, size: 64),
                  SizedBox(height: 12),
                  Text('No pending change requests.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('All edit and delete requests have been processed.'),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isDelete = data['action'] == 'delete';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  isThreeLine: true,
                  leading: CircleAvatar(child: Icon(isDelete ? Icons.delete_outline : Icons.edit_outlined)),
                  title: Text(_label(data), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_details(data)),
                  trailing: Wrap(spacing: 2, children: [
                    IconButton(tooltip: 'Approve', onPressed: () => _approve(context, doc), icon: const Icon(Icons.check_circle, color: Colors.green)),
                    IconButton(tooltip: 'Reject', onPressed: () => _reject(context, doc), icon: const Icon(Icons.cancel_outlined, color: Colors.red)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
