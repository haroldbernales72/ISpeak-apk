
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/incident_history_service.dart';

class IncidentTimelineScreen extends StatelessWidget {
  final String incidentId;

  IncidentTimelineScreen({
    super.key,
    required this.incidentId,
  });

  final IncidentHistoryService _historyService =
  IncidentHistoryService();

  @override
  Widget build(BuildContext context) {
    final incidentRef = FirebaseFirestore.instance
        .collection('incidents')
        .doc(incidentId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Report Timeline'),
        backgroundColor: AppColors.umBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: incidentRef.get(),
        builder: (context, incidentSnapshot) {
          if (incidentSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (incidentSnapshot.hasError) {
            return const Center(
              child: Text('Unable to load this report.'),
            );
          }

          if (!incidentSnapshot.hasData ||
              !incidentSnapshot.data!.exists) {
            return const Center(
              child: Text('Incident report not found.'),
            );
          }

          final incident = incidentSnapshot.data!.data()!;
          final category =
          (incident['category'] ?? 'Incident').toString();
          final currentStatus =
          (incident['status'] ?? 'New').toString();
          final createdAt = incident['createdAt'];

          DateTime? submittedAt;
          if (createdAt is Timestamp) {
            submittedAt = createdAt.toDate();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Incident Category',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: AppColors.umDarkBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(currentStatus),
                        backgroundColor:
                        _statusColor(currentStatus).withValues(
                          alpha: 0.15,
                        ),
                        labelStyle: TextStyle(
                          color: _statusColor(currentStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Status History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.umDarkBlue,
                ),
              ),
              const SizedBox(height: 12),
              if (submittedAt != null)
                _timelineItem(
                  title: 'Report Submitted',
                  description: 'Your report was received.',
                  date: submittedAt,
                  color: AppColors.success,
                  isLast: false,
                ),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _historyService.getHistory(incidentId),
                builder: (context, historySnapshot) {
                  if (historySnapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Unable to load status history. '
                            'Please check Firestore rules.',
                      ),
                    );
                  }

                  if (historySnapshot.connectionState ==
                      ConnectionState.waiting &&
                      !historySnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final records =
                      historySnapshot.data?.docs.toList() ?? [];

                  if (records.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No status changes recorded yet. '
                            'New changes will appear here.',
                      ),
                    );
                  }

                  return Column(
                    children: records.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value.data();
                      final status =
                      (data['status'] ?? 'Status updated')
                          .toString();
                      final changedAt = data['changedAt'];

                      DateTime? changedDate;
                      if (changedAt is Timestamp) {
                        changedDate = changedAt.toDate();
                      }

                      return _timelineItem(
                        title: status,
                        description: _statusDescription(status),
                        date: changedDate,
                        color: _statusColor(status),
                        isLast: index == records.length - 1,
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _timelineItem({
    required String title,
    required String description,
    required DateTime? date,
    required Color color,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 22,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.borderGrey,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 8,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.grey,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      date.toLocal().toString().substring(0, 16),
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'New':
        return 'The report is awaiting review.';
      case 'Under Investigation':
        return 'Staff are reviewing the report.';
      case 'Resolved':
        return 'The report has been marked as resolved.';
      default:
        return 'The report status was updated.';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Resolved':
        return AppColors.success;
      case 'Under Investigation':
        return AppColors.warning;
      case 'New':
      default:
        return AppColors.info;
    }
  }
}
