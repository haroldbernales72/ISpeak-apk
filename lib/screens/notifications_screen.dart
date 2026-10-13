import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/in_app_notification_service.dart';
import 'incident_details_screen.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  final InAppNotificationService _notificationService =
  InAppNotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.umBlue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationService.myNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Could not load notifications. Check Firestore rules.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data?.docs.toList() ?? [];

          docs.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;

            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) =>
            const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final isRead = data['isRead'] == true;
              final title =
              (data['title'] ?? 'Notification').toString();
              final message =
              (data['message'] ?? '').toString();
              final status =
              (data['status'] ?? '').toString();

              final timestamp = data['createdAt'] as Timestamp?;
              final date = timestamp?.toDate();

              return Card(
                elevation: 0,
                color: isRead ? Colors.white : AppColors.umLightBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppColors.borderGrey,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: isRead
                        ? AppColors.lightGrey
                        : AppColors.umBlue,
                    child: Icon(
                      isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: isRead
                          ? AppColors.grey
                          : Colors.white,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(message),
                        if (status.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Status: $status',
                            style: const TextStyle(
                              color: AppColors.umBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (date != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            date.toLocal().toString().substring(0, 16),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: isRead
                      ? const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  )
                      : const Icon(
                    Icons.circle,
                    size: 12,
                    color: AppColors.umBlue,
                  ),
                  onTap: () async {
                    final notificationId = doc.id;

                    // Mark this notification as read.
                    if (data['isRead'] != true) {
                      try {
                        await InAppNotificationService()
                            .markAsRead(notificationId);
                      } catch (e) {
                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not mark notification as read.'),
                          ),
                        );
                        return;
                      }
                    }

                    if (!context.mounted) return;

                    final incidentId = (data['incidentId'] ?? '').toString();

                    // Open the linked report if it has an incident ID.
                    if (incidentId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IncidentDetailsScreen(
                            incidentId: incidentId,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No incident is linked to this notification.'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
