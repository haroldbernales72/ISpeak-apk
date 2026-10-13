import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InAppNotificationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  /// Creates a notification for the student who submitted the report.
  Future<void> createStatusNotification({
    required String incidentId,
    required String reporterId,
    required String category,
    required String status,
  }) async {
    // Do not notify an empty or invalid recipient.
    if (reporterId.isEmpty) return;

    String message;

    switch (status) {
      case 'Under Investigation':
        message =
        'Your $category report is now under investigation.';
        break;
      case 'Resolved':
        message = 'Your $category report has been resolved.';
        break;
      case 'New':
        message = 'Your $category report is marked as new.';
        break;
      default:
        message =
        'Your $category report status changed to $status.';
    }

    await _firestore.collection('notifications').add({
      'userId': reporterId,
      'incidentId': incidentId,
      'title': 'Incident Report Update',
      'message': message,
      'status': status,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns notifications belonging to the currently signed-in user.
  Stream<QuerySnapshot<Map<String, dynamic>>> myNotifications() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }

  /// Marks a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Stream<int> unreadCountStream() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream<int>.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
