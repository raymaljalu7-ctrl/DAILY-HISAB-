import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangeApprovalsPage extends StatelessWidget {
  const ChangeApprovalsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('changeRequests');

  CollectionReference<Map<String, dynamic>> get _root => FirebaseFirestore.instance
      .collection('sharedData').doc('dailyHisab').collection('_dummy');

  Future<void> _approveEdit(BuildContext context, DocumentSnapshot<Map<String, dynamic>> request) async {
    final d = request.data() ?? {};
    final collection = d['collection']?.toString() ?? '';
    final recordId = d['recordId']?.toString() ?? '';
    final proposed = Map<String, dynamic>.from(d['proposedData'] ?? {});
    if (collection.isEmpty || recordId.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('sharedData').doc('dailyHisab')
          .collection(collection).doc(recordId);
      final target = await ref.get();
      if (!target.exists) {
        await request.reference.update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
          'decisionNote': 'Original record no longer exists.',
        });
        return;
      }
      proposed.remove('id');
      proposed.remove('createdAt');
      proposed.remove('createdBy');
      proposed.remove('createdByEmail');
      proposed.remove('deletionRequested');
      proposed.remove('deletionRequestedBy');
      proposed.remove('deletionRequestedByEmail');
      await ref.update({
        ...proposed,
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedByEmail': FirebaseAuth.instance.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await request.reference.update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (context.mounted) _snack(context, 'Edit approved and record updated.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Approval failed: $e');
    }
  }

  Future<void> _reject(BuildContext context, DocumentSnapshot<Map<String, dynamic>> request) async {
    try {
      await request.reference.update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (context.mounted) _snack(context, 'Request rejected.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Unable to reject request: $e');
    }
  }

  Future<void> _approveDelete(BuildContext context, DocumentSnapshot<Map<String, dynamic>> request) async {
    final d = request.data() ?? {};
    final collection = d['collection']?.toString() ?? '';
    final recordId = d['recordId']?.toString() ?? '';
    if (collection.isEmpty || recordId.isEmpty) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('sharedData').doc('dailyHisab')
          .collection(collection).doc(recordId);
      await ref.delete();
      await request.reference.update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });
      if (context.mounted) _snack(context, 'Delete approved. Record removed.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Delete approval failed: $e');
    }
  }

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _label(Map<String, dynamic> d) {
    final collection = d['collection']?.toString() ?? 'record';
    final action = d['action']?.toString() ?? 'edit';
    final email = d['requestedByEmail']?.toString() ?? '';
    return '${action.toUpperCase()} • $collection • $email';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Approvals')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _requests.where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Unable to load requests.\n${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified_outlined, size: 64), SizedBox(height: 12), Text('No pending change requests.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), SizedBox(height: 6), Text('All edit and delete requests are up to date.', textAlign: TextAlign.center)])));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              final action = d['action']?.toString() ?? 'edit';
              final isEdit = action == 'edit';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(isEdit ? Icons.edit : Icons.delete_outline)),
                  title: Text(_label(d), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Record ID: ${d['recordId'] ?? ''}'),
                  isThreeLine: true,
                  trailing: Wrap(spacing: 2, children: [
                    IconButton(tooltip: isEdit ? 'Approve edit' : 'Approve delete', onPressed: () => isEdit ? _approveEdit(context, doc) : _approveDelete(context, doc), icon: Icon(isEdit ? Icons.check_circle : Icons.delete_forever, color: Colors.green)),
                    IconButton(tooltip: 'Reject', onPressed: () => _reject(context, doc), icon: const Icon(Icons.cancel, color: Colors.red)),
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
