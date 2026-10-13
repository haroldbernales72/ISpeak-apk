
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncidentHistoryService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> recordStatusChange({
    required String incidentId,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to record status history.');
    }

    await _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('status_history')
        .add({
      'status': status,
      'changedAt': FieldValue.serverTimestamp(),
      'changedBy': user.uid,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getHistory(
      String incidentId,
      ) {
    return _firestore
        .collection('incidents')
        .doc(incidentId)
        .collection('status_history')
        .orderBy('changedAt')
        .snapshots();
  }
}
