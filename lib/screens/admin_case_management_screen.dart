
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../services/incident_history_service.dart';
import '../services/in_app_notification_service.dart';
import 'chat_screen.dart';

class AdminCaseManagementScreen extends StatefulWidget {
  const AdminCaseManagementScreen({super.key});

  @override
  State<AdminCaseManagementScreen> createState() =>
      _AdminCaseManagementScreenState();
}

class _AdminCaseManagementScreenState
    extends State<AdminCaseManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = [
    'All',
    'New',
    'Under Investigation',
    'Resolved',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(
      BuildContext context,
      String incidentId,
      String status,
      ) async {
    try {
      final incidentRef =
      _firestore.collection('incidents').doc(incidentId);

      final incidentSnapshot = await incidentRef.get();

      if (!incidentSnapshot.exists) {
        throw Exception('Incident not found.');
      }

      final data = incidentSnapshot.data()!;
      final oldStatus = (data['status'] ?? 'New').toString();

      if (oldStatus == status) return;

      await incidentRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await IncidentHistoryService().recordStatusChange(
        incidentId: incidentId,
        status: status,
      );

      final reporterId = (data['reporterId'] ?? '').toString();

      if (reporterId.isNotEmpty) {
        await InAppNotificationService().createStatusNotification(
          incidentId: incidentId,
          reporterId: reporterId,
          category: (data['category'] ?? 'Incident').toString(),
          status: status,
        );
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident status updated to $status.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update status: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _assignStaff(
      BuildContext context,
      String incidentId,
      String staffId,
      String staffName,
      ) async {
    try {
      await _firestore.collection('incidents').doc(incidentId).update({
        'assignedStaffId': staffId,
        'assignedStaffName': staffName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident assigned to $staffName.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not assign staff: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showAssignmentDialog(
      BuildContext context,
      String incidentId,
      ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppColors.umBlue),
              SizedBox(width: 10),
              Expanded(child: Text('Assign Incident')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Could not load staff accounts. '
                        'Check your Firestore security rules.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final staff = snapshot.data?.docs.where((doc) {
                  final role = (doc.data()['role'] ?? '')
                      .toString()
                      .toLowerCase();

                  return role == 'security' || role == 'admin';
                }).toList() ??
                    [];

                if (staff.isEmpty) {
                  return const Text(
                    'No admin or security accounts were found.',
                  );
                }

                return SizedBox(
                  height: 300,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: staff.length,
                    separatorBuilder: (_, _) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final doc = staff[index];
                      final data = doc.data();

                      final name =
                      (data['name'] ?? data['email'] ?? 'Staff')
                          .toString();
                      final email = (data['email'] ?? '').toString();
                      final role = (data['role'] ?? 'security')
                          .toString();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.umLightBlue,
                          child: Icon(
                            Icons.shield_outlined,
                            color: AppColors.umBlue,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text('$email\n$role'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          Navigator.pop(dialogContext);

                          await _assignStaff(
                            context,
                            incidentId,
                            doc.id,
                            name,
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Under Investigation':
        return AppColors.warning;
      case 'Resolved':
        return AppColors.success;
      case 'New':
        return AppColors.info;
      default:
        return AppColors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Under Investigation':
        return Icons.manage_search;
      case 'Resolved':
        return Icons.check_circle_outline;
      case 'New':
        return Icons.fiber_new_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');

      return '${date.year}-$month-$day';
    }

    return 'Date unavailable';
  }

  bool _matchesSearch(Map<String, dynamic> data, String id) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();

    final searchableText = [
      id,
      data['category'] ?? '',
      data['description'] ?? '',
      data['location'] ?? '',
      data['status'] ?? '',
      data['assignedStaffName'] ?? '',
      data['reporterId'] ?? '',
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 24,
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(
      BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final category =
    (data['category'] ?? 'Uncategorized').toString();
    final description =
    (data['description'] ?? 'No description provided.').toString();
    final location =
    (data['location'] ?? 'Location not provided').toString();
    final status = (data['status'] ?? 'New').toString();
    final assignedStaffName =
    (data['assignedStaffName'] ?? '').toString();
    final assignedStaffId =
    (data['assignedStaffId'] ?? '').toString();
    final reporterId = (data['reporterId'] ?? '').toString();
    final mediaUrl = (data['mediaUrl'] ?? '').toString();


    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isAssignedStaff =
        assignedStaffId.isNotEmpty && assignedStaffId == currentUserId;

    final statusColor = _statusColor(status);
    final date = _formatDate(data['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.umLightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.umBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Case ID: ${doc.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusIcon(status),
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on_outlined, location),
            _buildInfoRow(Icons.calendar_today_outlined, date),
            _buildInfoRow(
              Icons.person_outline,
              assignedStaffName.isEmpty
                  ? 'Not assigned to staff'
                  : 'Assigned to: $assignedStaffName',
            ),
            if (mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Incident Evidence',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              AdminEvidenceViewer(
                storagePath: mediaUrl,
              ),
            ],
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderGrey),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 600;

                final assignButton = OutlinedButton.icon(
                  onPressed: () =>
                      _showAssignmentDialog(context, doc.id),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(
                    assignedStaffId.isEmpty
                        ? 'Assign Staff'
                        : 'Reassign Staff',
                  ),
                );

                final messageButton = OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          incidentId: doc.id,
                          category: category,
                          isAdmin: true,
                          studentId: reporterId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Message Student'),
                );

                final statusDropdown = SizedBox(
                  width: compact ? double.infinity : 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: [
                      'New',
                      'Under Investigation',
                      'Resolved',
                    ].contains(status)
                        ? status
                        : 'New',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Update Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'New',
                        child: Text('New'),
                      ),
                      DropdownMenuItem(
                        value: 'Under Investigation',
                        child: Text('Under Investigation'),
                      ),
                      DropdownMenuItem(
                        value: 'Resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && value != status) {
                        _updateStatus(context, doc.id, value);
                      }
                    },
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      assignButton,
                      if (isAssignedStaff && reporterId.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: messageButton,
                        ),
                      const SizedBox(height: 10),
                      statusDropdown,
                    ],
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    assignButton,
                    if (isAssignedStaff && reporterId.isNotEmpty)
                      messageButton,
                    statusDropdown,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.grey),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('incidents').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Unable to load cases',
              message:
              'Check your internet connection and Firestore security rules.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final incidents = snapshot.data?.docs.toList() ?? [];

          incidents.sort((a, b) {
            final aDate = a.data()['createdAt'];
            final bDate = b.data()['createdAt'];

            final aMillis =
            aDate is Timestamp ? aDate.millisecondsSinceEpoch : 0;
            final bMillis =
            bDate is Timestamp ? bDate.millisecondsSinceEpoch : 0;

            return bMillis.compareTo(aMillis);
          });

          final allCount = incidents.length;
          final newCount = incidents
              .where((doc) => (doc.data()['status'] ?? 'New') == 'New')
              .length;
          final investigatingCount = incidents
              .where((doc) =>
          (doc.data()['status'] ?? 'New') ==
              'Under Investigation')
              .length;
          final resolvedCount = incidents
              .where((doc) => doc.data()['status'] == 'Resolved')
              .length;

          final filteredIncidents = incidents.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? 'New').toString();

            final matchesStatus = _selectedFilter == 'All' ||
                status == _selectedFilter;

            return matchesStatus && _matchesSearch(data, doc.id);
          }).toList();

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;

                return ListView(
                  padding: EdgeInsets.all(wide ? 28 : 16),
                  children: [
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
                            Icons.folder_open_outlined,
                            color: AppColors.umBlue,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Case Management',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Review, assign, and track reported incidents.',
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

                    // Overview cards.
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total Cases',
                              count: allCount,
                              icon: Icons.folder_outlined,
                              color: AppColors.umBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'New',
                              count: newCount,
                              icon: Icons.fiber_new_outlined,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Investigating',
                              count: investigatingCount,
                              icon: Icons.manage_search,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Resolved',
                              count: resolvedCount,
                              icon: Icons.check_circle_outline,
                              color: AppColors.success,
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
                                  title: 'Total Cases',
                                  count: allCount,
                                  icon: Icons.folder_outlined,
                                  color: AppColors.umBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'New',
                                  count: newCount,
                                  icon: Icons.fiber_new_outlined,
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
                                  title: 'Investigating',
                                  count: investigatingCount,
                                  icon: Icons.manage_search,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  title: 'Resolved',
                                  count: resolvedCount,
                                  icon: Icons.check_circle_outline,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // Search and filters.
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
                            'Incident Reports',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${filteredIncidents.length} of $allCount case(s)',
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 12,
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
                              'Search category, location, description, or case ID',
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
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((filter) {
                                final selected = _selectedFilter == filter;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(filter),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedFilter = filter;
                                      });
                                    },
                                    selectedColor: AppColors.umLightBlue,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? AppColors.umBlue
                                          : AppColors.grey,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: selected
                                          ? AppColors.umBlue
                                          : AppColors.borderGrey,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (incidents.isEmpty)
                      _buildEmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No incident reports yet',
                        message:
                        'New reports submitted by students will appear here.',
                      )
                    else if (filteredIncidents.isEmpty)
                      _buildEmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No matching cases',
                        message:
                        'Try another search term or select a different status filter.',
                      )
                    else
                      ...filteredIncidents.map(
                            (doc) => _buildIncidentCard(context, doc),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}


class AdminEvidenceViewer extends StatefulWidget {
  final String storagePath;

  const AdminEvidenceViewer({
    super.key,
    required this.storagePath,
  });

  @override
  State<AdminEvidenceViewer> createState() =>
      _AdminEvidenceViewerState();
}


class _AdminEvidenceViewerState
    extends State<AdminEvidenceViewer> {
  Future<String>? _evidenceUrlFuture;

  @override
  void initState() {
    super.initState();
    _evidenceUrlFuture = _getEvidenceUrl();
  }

  Future<String> _getEvidenceUrl() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please sign in again.');
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw Exception('Unable to verify your account.');
    }

    final response =
    await Supabase.instance.client.functions.invoke(
      'admin-evidence-url',
      headers: {
        'Authorization': 'Bearer $idToken',
      },
      body: {
        'storagePath': widget.storagePath,
      },
    );

    if (response.status != 200 ||
        response.data is! Map ||
        response.data['signedUrl'] is! String) {
      throw Exception('Unable to access incident evidence.');
    }

    return response.data['signedUrl'] as String;
  }

  void _retry() {
    setState(() {
      _evidenceUrlFuture = _getEvidenceUrl();
    });
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder:
                          (context, child, progress) {
                        if (progress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder:
                          (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Unable to display the full image.',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Close image',
                  onPressed: () =>
                      Navigator.pop(dialogContext),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _evidenceUrlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load evidence.',
                style: TextStyle(color: Colors.red),
              ),
              TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        final url = snapshot.data!;

        final isPdf = widget.storagePath
            .toLowerCase()
            .split('?')
            .first
            .endsWith('.pdf');

        if (isPdf) {
          return const ListTile(
            leading: Icon(
              Icons.picture_as_pdf,
              color: Colors.red,
              size: 36,
            ),
            title: Text('PDF evidence'),
            subtitle: Text(
              'Evidence URL retrieved successfully. '
                  'A PDF viewer is needed to preview it.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: AppColors.umLightBlue,
                child: InkWell(
                  onTap: () => _showFullImage(context, url),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 240,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder:
                              (context, child, progress) {
                            if (progress == null) return child;

                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder:
                              (context, error, stackTrace) {
                            return const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text(
                                  'Could not display this image.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        color: Colors.black54,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Click to view full image',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}



