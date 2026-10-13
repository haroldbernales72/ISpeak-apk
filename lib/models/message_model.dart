import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String incidentId;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime? createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.incidentId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incidentId': incidentId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }

  factory MessageModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return MessageModel(
      id: map['id'] ?? '',
      incidentId: map['incidentId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      isRead: map['isRead'] ?? false,
    );
  }
}