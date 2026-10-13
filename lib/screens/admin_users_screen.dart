
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'admin_user_profile_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _selectedRole = 'All';
  String _searchQuery = '';

  final List<String> _roles = [
    'All',
    'student',
    'security',
    'admin',
    'staff',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> user, String uid) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();

    final searchableText = [
      uid,
      user['name'] ?? '',
      user['email'] ?? '',
      user['studentId'] ?? '',
      user['campus'] ?? '',
      user['role'] ?? '',
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  bool _matchesRole(Map<String, dynamic> user) {
    if (_selectedRole == 'All') return true;

    final role = (user['role'] ?? 'student')
        .toString()
        .toLowerCase()
        .trim();

    return role == _selectedRole.toLowerCase();
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase().trim()) {
      case 'admin':
        return AppColors.danger;
      case 'security':
      case 'staff':
        return AppColors.warning;
      case 'student':
        return AppColors.umBlue;
      default:
        return AppColors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase().trim()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'security':
        return Icons.shield_outlined;
      case 'staff':
        return Icons.badge_outlined;
      case 'student':
        return Icons.school_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _roleLabel(String role) {
    if (role.trim().isEmpty) return 'Unknown';
    return role[0].toUpperCase() + role.substring(1);
  }

  void _openUserProfile(
      BuildContext context,
      Map<String, dynamic> user,
      String uid,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUserProfileScreen(
          userId: uid,
          user: user,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
      BuildContext context,
      Map<String, dynamic> user,
      String uid,
      ) {
    final name = (user['name'] ?? 'Unnamed User').toString();
    final email = (user['email'] ?? 'No email').toString();
    final studentId = (user['studentId'] ?? '').toString();
    final campus = (user['campus'] ?? '').toString();
    final role = (user['role'] ?? 'student').toString();

    final trimmedName = name.trim();
    final initial =
    trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';
    final roleColor = _roleColor(role);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openUserProfile(context, user, uid),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.umLightBlue,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.umBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.grey,
                      ),
                    ),
                    if (studentId.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      _buildInfoRow(
                        Icons.badge_outlined,
                        'ID: $studentId',
                      ),
                    ],
                    if (campus.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        campus,
                      ),
                    ],
                    const SizedBox(height: 11),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _roleIcon(role),
                            size: 14,
                            color: roleColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _roleLabel(role).toUpperCase(),
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 15,
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.grey),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_outline,
            size: 56,
            color: AppColors.grey,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildEmptyState(
                title: 'Unable to load users',
                message:
                'Check your internet connection and Firestore security rules.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.umBlue,
                ),
              );
            }

            final documents = snapshot.data?.docs ?? [];

            final allUsers = documents.map((doc) => doc.data()).toList();

            final studentCount = allUsers
                .where((user) =>
            (user['role'] ?? 'student')
                .toString()
                .toLowerCase() ==
                'student')
                .length;

            final securityCount = allUsers
                .where((user) =>
            (user['role'] ?? '')
                .toString()
                .toLowerCase() ==
                'security')
                .length;

            final adminCount = allUsers
                .where((user) =>
            (user['role'] ?? '')
                .toString()
                .toLowerCase() ==
                'admin')
                .length;

            final filteredUsers = documents.where((doc) {
              final user = doc.data();
              return _matchesSearch(user, doc.id) &&
                  _matchesRole(user);
            }).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;

                return ListView(
                  padding: EdgeInsets.all(wide ? 28 : 16),
                  children: [
                    // Page heading.
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.umLightBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.groups_outlined,
                            size: 27,
                            color: AppColors.umBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage Users',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View student accounts and authorized staff.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // User statistics.
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total Users',
                              count: documents.length,
                              icon: Icons.groups_outlined,
                              color: AppColors.umBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Students',
                              count: studentCount,
                              icon: Icons.school_outlined,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Security',
                              count: securityCount,
                              icon: Icons.shield_outlined,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Admins',
                              count: adminCount,
                              icon: Icons.admin_panel_settings_outlined,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Total Users',
                                  count: documents.length,
                                  icon: Icons.groups_outlined,
                                  color: AppColors.umBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Students',
                                  count: studentCount,
                                  icon: Icons.school_outlined,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Security',
                                  count: securityCount,
                                  icon: Icons.shield_outlined,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Admins',
                                  count: adminCount,
                                  icon: Icons.admin_panel_settings_outlined,
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Search and role filters.
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Directory',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${filteredUsers.length} of ${documents.length} user(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            decoration: InputDecoration(
                              hintText:
                              'Search name, email, ID, campus, or role',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                icon: const Icon(Icons.close),
                              )
                                  : null,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Filter by role',
                              prefixIcon: const Icon(Icons.filter_list),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding:
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            items: _roles.map((role) {
                              final label = role == 'All'
                                  ? 'All Users'
                                  : '${_roleLabel(role)}${role == 'security' || role == 'staff' ? ' Accounts' : 's'}';

                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (documents.isEmpty)
                      _buildEmptyState(
                        title: 'No users found',
                        message:
                        'Registered users will appear here when their profiles are saved in Firestore.',
                      )
                    else if (filteredUsers.isEmpty)
                      _buildEmptyState(
                        title: 'No matching users',
                        message:
                        'Try a different search term or role filter.',
                      )
                    else ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Accounts',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        ...filteredUsers.map(
                              (doc) => _buildUserCard(
                            context,
                            doc.data(),
                            doc.id,
                          ),
                        ),
                      ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
