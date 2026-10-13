import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> sendMessage(
      MessageModel message,
      ) async {
    await _firestore
        .collection('messages')
        .doc(message.id)
        .set(
      message.toMap(),
    );
  }

  // =========================================================
  // GET MESSAGES FOR AN INCIDENT
  // =========================================================

  Stream<List<MessageModel>>
  getMessagesForIncident(
      String incidentId,
      ) {
    return _firestore
        .collection('messages')
        .where(
      'incidentId',
      isEqualTo: incidentId,
    )
        .orderBy(
      'createdAt',
      descending: false,
    )
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs.map(
              (document) {
            return MessageModel
                .fromMap(
              document.data(),
            );
          },
        ).toList();
      },
    );
  }

  // =========================================================
  // MARK MESSAGE AS READ
  // =========================================================

  Future<void> markMessageAsRead(
      String messageId,
      ) async {
    await _firestore
        .collection('messages')
        .doc(messageId)
        .update({
      'isRead': true,
    });
  }
}