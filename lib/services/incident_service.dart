import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/incident_model.dart';

class IncidentService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> createIncident(
      IncidentModel incident,
      ) async {
    await _firestore
        .collection('incidents')
        .doc(incident.id)
        .set(incident.toMap());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getUserIncidents(String userId) {
    return _firestore
        .collection('incidents')
        .where(
      'reporterId',
      isEqualTo: userId,
    )
        .snapshots();
  }
  Future<void> assignStaff({
    required String incidentId,
    required String staffId,
  }) async {
    await _firestore
        .collection('incidents')
        .doc(incidentId)
        .update({
      'assignedStaffId': staffId,
    });
  }
}