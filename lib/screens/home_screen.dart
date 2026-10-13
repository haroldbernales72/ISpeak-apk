import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/incident_model.dart';
import '../services/auth_service.dart';
import '../services/incident_service.dart';

import 'report_incident_screen.dart';
import 'my_reports_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import 'user_profile_screen.dart';
import '../services/in_app_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final AuthService _authService =
  AuthService();

  final IncidentService _incidentService =
  IncidentService();

  // =========================
  // LOGOUT
  // =========================
  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) {
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/',
    );
  }

  // =========================
  // QUICK ALERT
  // =========================
  Future<void> _sendQuickAlert() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final incident = IncidentModel(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      reporterId: user.uid,
      category: 'Emergency',
      description:
      'Emergency Quick Alert was activated by the student.',
      location: 'School Campus',
      isAnonymous: false,
      status: 'New',
      mediaUrl: null,
      assignedStaffId: null,
      createdAt: DateTime.now(),
    );

    try {
      await _incidentService
          .createIncident(incident);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Emergency alert sent successfully.',
          ),
          backgroundColor:
          AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send emergency alert: $e',
          ),
          backgroundColor:
          AppColors.danger,
        ),
      );
    }
  }

  // =========================
  // SHOW QUICK ALERT DIALOG
  // =========================
  void _showQuickAlertDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: AppColors.danger,
              ),
              SizedBox(width: 10),
              Text('Emergency Alert'),
            ],
          ),
          content: const Text(
            'Use this button only when there is an immediate threat or emergency on campus.\n\n'
                'Your alert will be recorded and sent to the school safety staff.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                AppColors.danger,
                foregroundColor:
                Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _sendQuickAlert();
              },
              child: const Text(
                'SEND ALERT',
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // BOTTOM NAVIGATION
  // =========================

  void _onItemTapped(int index) {
    if (index == 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MyReportsScreen(),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MessagesScreen(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserProfileScreen(),
        ),
      );
    }
  }

  // =========================
  // ACTION CARD
  // =========================
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding:
          const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor
                      .withValues(alpha:0.12),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // HOME CONTENT
  // =========================
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding:
      const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [

          // =========================
          // WELCOME
          // =========================
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.umBlue,
              borderRadius:
              BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to ISpeak',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Your voice can help make our campus safer.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // =========================
          // EMERGENCY QUICK ALERT
          // =========================
          Card(
            elevation: 3,
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius:
              BorderRadius.circular(16),
              onTap:
              _showQuickAlertDialog,
              child: Padding(
                padding:
                const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration:
                      BoxDecoration(
                        color: AppColors.danger
                            .withValues(alpha:
                          0.12,
                        ),
                        shape:
                        BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons
                            .warning_rounded,
                        color:
                        AppColors.danger,
                        size: 30,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Emergency Quick Alert',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Tap only for an immediate emergency.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                              AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons
                          .arrow_forward_ios,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // =========================
          // QUICK ACTIONS TITLE
          // =========================
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          // =========================
          // ACTION CARDS
          // =========================
          Row(
            children: [

              // REPORT INCIDENT
              Expanded(
                child: _buildActionCard(
                  icon:
                  Icons.report_problem_outlined,
                  title:
                  'Report Incident',
                  subtitle:
                  'Report a safety concern',
                  iconColor:
                  AppColors.danger,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const ReportIncidentScreen(),
                      ),
                    );
                  },
                ),
              ),

              // MY REPORTS
              Expanded(
                child: _buildActionCard(
                  icon:
                  Icons.assignment_outlined,
                  title:
                  'My Reports',
                  subtitle:
                  'View your reports',
                  iconColor:
                  AppColors.umBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const MyReportsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [

              // =========================
              // MESSAGES
              // =========================
              Expanded(
                child: _buildActionCard(
                  icon:
                  Icons.message_outlined,
                  title:
                  'Messages',
                  subtitle:
                  'Contact assigned staff',
                  iconColor:
                  Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                        const MessagesScreen(),
                      ),
                    );
                  },
                ),
              ),

              // =========================
              // PROFILE
              // =========================

              Expanded(
                child: _buildActionCard(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  subtitle: 'Manage your account',
                  iconColor: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserProfileScreen(),
                      ),
                    );
                  },
                ),
              ),

            ],
          ),

          const SizedBox(height: 24),

          // =========================
          // SAFETY REMINDER
          // =========================
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color:
              AppColors.umLightBlue,
              borderRadius:
              BorderRadius.circular(16),
              border: Border.all(
                color:
                AppColors.umBlue
                    .withValues(alpha:0.15),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color:
                  AppColors.umBlue,
                  size: 28,
                ),

                SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Stay Safe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                          color:
                          AppColors.umDarkBlue,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'If you see something suspicious or unsafe, report it through ISpeak. Your report can help protect other students.',
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          AppColors.grey,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      AppColors.background,

      // =========================
      // APP BAR
      // =========================
      appBar: AppBar(
        backgroundColor:
        AppColors.umBlue,
        foregroundColor:
        Colors.white,
        elevation: 0,

        title: const Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: Colors.white,
            ),

            SizedBox(width: 8),

            Text(
              'ISpeak',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [

          // NOTIFICATION BUTTON

          StreamBuilder<int>(
            stream: InAppNotificationService().unreadCountStream(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;

              return IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationsScreen(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unreadCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),


          // LOGOUT MENU
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder:
                (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color:
                      AppColors.danger,
                    ),

                    SizedBox(width: 10),

                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // =========================
      // BODY
      // =========================
      body: _buildHomeContent(),

      // =========================
      // BOTTOM NAVIGATION
      // =========================
      bottomNavigationBar:
      BottomNavigationBar(
        currentIndex:
        _selectedIndex,

        selectedItemColor:
        AppColors.umBlue,

        unselectedItemColor:
        AppColors.grey,

        type:
        BottomNavigationBarType
            .fixed,

        onTap:
        _onItemTapped,

        items: const [
          BottomNavigationBarItem(
            icon:
            Icon(Icons.home_outlined),
            activeIcon:
            Icon(Icons.home),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.assignment_outlined,
            ),
            activeIcon: Icon(
              Icons.assignment,
            ),
            label: 'Reports',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.message_outlined,
            ),
            activeIcon: Icon(
              Icons.message,
            ),
            label: 'Messages',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
            ),
            activeIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}