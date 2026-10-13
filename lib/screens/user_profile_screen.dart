
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  Future<Map<String, dynamic>?> _loadProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return null;
    }

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    return document.data();
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      return '${date.year}-$month-$day';
    }

    return 'Not available';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.umBlue,
        foregroundColor: Colors.white,
      ),
      body: currentUser == null
          ? const Center(
        child: Text('Please log in to view your profile.'),
      )
          : FutureBuilder<Map<String, dynamic>?>(
        future: _loadProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.umBlue,
              ),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load your profile.'),
            );
          }

          final profile = snapshot.data;

          if (profile == null) {
            return const Center(
              child: Text('Profile information not found.'),
            );
          }

          final name =
          (profile['name'] ?? 'Student').toString();
          final email = (profile['email'] ??
              currentUser.email ??
              'No email')
              .toString();
          final studentId =
          (profile['studentId'] ?? 'Not provided')
              .toString();
          final campus =
          (profile['campus'] ?? 'Not provided').toString();
          final role =
          (profile['role'] ?? 'student').toString();
          final registered =
          _formatDate(profile['createdAt']);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: AppColors.umLightBlue,
                        child: Text(
                          name.trim().isNotEmpty
                              ? name.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: AppColors.umBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.umLightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.umBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoTile(
                      Icons.badge_outlined,
                      'Student ID',
                      studentId,
                    ),
                    const Divider(height: 1),
                    _infoTile(
                      Icons.school_outlined,
                      'Campus',
                      campus,
                    ),
                    const Divider(height: 1),
                    _infoTile(
                      Icons.calendar_today_outlined,
                      'Date Registered',
                      registered,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final shouldLogout =
                    await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Log Out'),
                          content: const Text(
                            'Are you sure you want to log out?',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(
                                    dialogContext,
                                    false,
                                  ),
                              child: const Text('Cancel'),
                            ),

                            SizedBox(height: 10),

                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(
                                    dialogContext,
                                    true,
                                  ),
                              child: const Text('Log Out'),
                            ),
                          ],
                        );
                      },
                    );

                    if (shouldLogout != true ||
                        !context.mounted) {
                      return;
                    }

                    final authService = AuthService();
                    await authService.logout();

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                          (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(
      IconData icon,
      String title,
      String value,
      ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.umBlue),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.grey,
        ),
      ),
      subtitle: SelectableText(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.black,
        ),
      ),
    );
  }
}
