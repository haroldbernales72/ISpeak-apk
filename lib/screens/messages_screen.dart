import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/incident_service.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in first.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Messages',
        ),
        backgroundColor:
        AppColors.umBlue,
        foregroundColor:
        AppColors.white,
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: IncidentService()
            .getUserIncidents(
          user.uid,
        ),

        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
              ),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons
                        .chat_bubble_outline,
                    size: 60,
                    color:
                    AppColors.grey,
                  ),

                  SizedBox(height: 12),

                  Text(
                    'No messages yet.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Messages related to your reports will appear here.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      color:
                      AppColors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding:
            const EdgeInsets.all(16),

            itemCount:
            documents.length,

            itemBuilder:
                (context, index) {
              final data =
              documents[index].data();

              final incidentId =
                  data['id'] ?? '';

              final category =
                  data['category'] ?? '';

              final location =
                  data['location'] ?? '';

              final status =
                  data['status'] ?? 'New';

              final createdAt =
              data['createdAt']
              as Timestamp?;

              return Card(
                margin:
                const EdgeInsets.only(
                  bottom: 12,
                ),

                elevation: 1,

                child: ListTile(
                  contentPadding:
                  const EdgeInsets.all(
                    16,
                  ),

                  leading: CircleAvatar(
                    backgroundColor:
                    AppColors.umLightBlue,

                    child: const Icon(
                      Icons
                          .chat_bubble_outline,
                      color:
                      AppColors.umBlue,
                    ),
                  ),

                  title: Text(
                    category,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  subtitle:
                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        location,
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        'Status: $status',
                        style:
                        TextStyle(
                          color:
                          _statusColor(
                            status,
                          ),
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),

                      if (createdAt !=
                          null)
                        Text(
                          _formatDate(
                            createdAt
                                .toDate(),
                          ),
                          style:
                          const TextStyle(
                            fontSize:
                            12,
                            color:
                            AppColors
                                .grey,
                          ),
                        ),
                    ],
                  ),

                  trailing:
                  const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 16,
                  ),

                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                            ChatScreen(
                              incidentId:
                              incidentId,
                              category:
                              category,
                              isAdmin:
                              false,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Color _statusColor(
      String status,
      ) {
    switch (status) {
      case 'Resolved':
        return AppColors.success;

      case 'Under Investigation':
        return AppColors.warning;

      default:
        return AppColors.info;
    }
  }

  static String _formatDate(
      DateTime date,
      ) {
    return '${date.month}/${date.day}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}