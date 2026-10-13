import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentModel {
  final String id;
  final String reporterId;
  final String category;
  final String description;
  final String location;
  final bool isAnonymous;
  final String status;
  final String? mediaUrl;
  final String? assignedStaffId;
  final DateTime? createdAt;

  IncidentModel({
    required this.id,
    required this.reporterId,
    required this.category,
    required this.description,
    required this.location,
    required this.isAnonymous,
    required this.status,
    this.mediaUrl,
    this.assignedStaffId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporterId': reporterId,
      'category': category,
      'description': description,
      'location': location,
      'isAnonymous': isAnonymous,
      'status': status,
      'mediaUrl': mediaUrl,
      'assignedStaffId':
      assignedStaffId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(
        createdAt!,
      )
          : FieldValue.serverTimestamp(),
    };
  }

  factory IncidentModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return IncidentModel(
      id: map['id'] ?? '',
      reporterId:
      map['reporterId'] ?? '',
      category:
      map['category'] ?? '',
      description:
      map['description'] ?? '',
      location:
      map['location'] ?? '',
      isAnonymous:
      map['isAnonymous'] ?? true,
      status:
      map['status'] ?? 'New',
      mediaUrl:
      map['mediaUrl'],
      assignedStaffId:
      map['assignedStaffId'],
      createdAt:
      map['createdAt'] is Timestamp
          ? (map['createdAt']
      as Timestamp)
          .toDate()
          : null,
    );
  }
}