import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangeRequestsPage extends StatelessWidget {
  const ChangeRequestsPage({super.key});

  CollectionReference<Map<String, dynamic>> get _requests =>
      FirebaseFirestore.instance.collection('changeRequests');

  Future<void> _approve(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    final data = request.data() ?? {};
    final action = data['action']?.toString() ?? '';
    final collection = data['collection']?.toString() ?? '';
    final recordId = data['recordId']?.toString() ?? '';

    if (collection.isEmpty || recordId.isEmpty) return;

    try {
      final record = FirebaseFirestore.instance
          .collection('sharedData')
          .doc('dailyHisab')
          .collection(collection)
          .doc(recordId);

      if (action == 'delete') {
        await record.delete();
      } else if (action == 'edit') {
        final proposed = Map<String, dynamic>.from(
          (data['proposedData'] as Map?) ?? const {},
        );
        proposed.remove('id');
        proposed.remove('createdBy');
        proposed.remove('createdByEmail');
        proposed['updatedBy'] = FirebaseAuth.instance.currentUser?.uid;
        proposed['updatedByEmail'] = FirebaseAuth.instance.currentUser?.email;
        proposed['updatedAt'] = FieldValue.serverTimestamp();
        await record.update(proposed);
      } else {
        throw StateError('Unknown request type.');
      }

      await request.reference.update({
        'status': 'approved',
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        'approvedByEmail': FirebaseAuth.instance.currentUser?.email,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'delete'
                  ? 'Delete request approved.'
                  : 'Edit request approved.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> request,
  ) async {
    try {
      await request.reference.update({
        'status': 'rejected',
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
        'rejectedByEmail': FirebaseAuth.instance.currentUser?.email,
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e')),
        );
      }
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
        stream: _requests
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load requests:\n${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'No pending change requests.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text('All edit and delete requests have been processed.'),
                  ],
                ),
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
                  leading: CircleAvatar(
                    child: Icon(isDelete ? Icons.delete_outline : Icons.edit_outlined),
                  ),
                  title: Text(
                    _label(data),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_details(data)),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        onPressed: () => _approve(context, doc),
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        onPressed: () => _reject(context, doc),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
