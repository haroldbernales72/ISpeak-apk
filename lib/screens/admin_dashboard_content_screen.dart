import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/incident_history_service.dart';
import '../services/in_app_notification_service.dart';
import 'admin_case_management_screen.dart';

class AdminDashboardContentScreen extends StatefulWidget {
  const AdminDashboardContentScreen({super.key});

  @override
  State<AdminDashboardContentScreen> createState() =>
      _AdminDashboardContentScreenState();
}

class _AdminDashboardContentScreenState
    extends State<AdminDashboardContentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = [
    'All',
    'New',
    'Under Investigation',
    'Resolved',
    'Emergency',
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'New':
        return Colors.blue;
      case 'Under Investigation':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Emergency':
        return Colors.red;
      case 'Weapons':
        return Colors.deepOrange;
      case 'Drugs':
        return Colors.purple;
      case 'Bullying':
        return Colors.orange;
      case 'Theft':
        return Colors.indigo;
      case 'Vandalism':
        return Colors.brown;
      default:
        return AppColors.umBlue;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Emergency':
        return Icons.warning_rounded;
      case 'Weapons':
        return Icons.gpp_bad_outlined;
      case 'Drugs':
        return Icons.health_and_safety_outlined;
      case 'Bullying':
        return Icons.people_outline;
      case 'Theft':
        return Icons.inventory_2_outlined;
      case 'Vandalism':
        return Icons.broken_image_outlined;
      default:
        return Icons.report_outlined;
    }
  }

  Future<void> _updateStatus(
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

      await InAppNotificationService().createStatusNotification(
        incidentId: incidentId,
        reporterId: (data['reporterId'] ?? '').toString(),
        category: (data['category'] ?? 'Incident').toString(),
        status: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Incident marked as $status.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update incident: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showIncidentDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final category = (data['category'] ?? 'Unknown').toString();
    final description =
    (data['description'] ?? 'No description').toString();
    final location = (data['location'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'New').toString();
    final isAnonymous = data['isAnonymous'] ?? true;

    // This is the Firestore field used by Case Management.
    // Its value must be the storage path expected by the
    // admin-evidence-url Supabase Edge Function.
    final evidencePath = (data['mediaUrl'] ?? '').toString().trim();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                _categoryIcon(category),
                color: _categoryColor(category),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(category)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Status', status),
                  _detailRow('Location', location),
                  _detailRow(
                    'Reporter',
                    isAnonymous == true ? 'Anonymous' : 'Identified',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                  const SizedBox(height: 20),
                  const Text(
                    'Incident Evidence',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (evidencePath.isEmpty)
                    const Text('No evidence was attached to this report.')
                  else
                    AdminEvidenceViewer(
                      key: ValueKey(evidencePath),
                      storagePath: evidencePath,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$title:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF69778C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B4D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _incidentCard(
      String incidentId,
      Map<String, dynamic> data,
      ) {
    final category = (data['category'] ?? 'Unknown').toString();
    final description =
    (data['description'] ?? 'No description').toString();
    final location = (data['location'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'New').toString();
    final isAnonymous = data['isAnonymous'] ?? true;
    final createdAt = data['createdAt'];

    DateTime? date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    }

    final categoryColor = _categoryColor(category);
    final statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showIncidentDetails(context, data),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      color: categoryColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _categoryIcon(category),
                      color: categoryColor,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172B4D),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
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
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF59677C),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    isAnonymous == true
                        ? Icons.visibility_off_outlined
                        : Icons.person_outline,
                    size: 15,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isAnonymous == true ? 'Anonymous' : 'Identified',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (date != null)
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFEDF0F5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _showIncidentDetails(context, data),
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: const Text('View details'),
                  ),
                  const Spacer(),
                  if (status != 'Resolved')
                    PopupMenuButton<String>(
                      tooltip: 'Update incident status',
                      onSelected: (newStatus) {
                        _updateStatus(incidentId, newStatus);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'New',
                          child: Text('New'),
                        ),
                        PopupMenuItem(
                          value: 'Under Investigation',
                          child: Text('Under Investigation'),
                        ),
                        PopupMenuItem(
                          value: 'Resolved',
                          child: Text('Resolved'),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.more_horiz, size: 20),
                            SizedBox(width: 4),
                            Text('Actions'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;

    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.month}/${date.day}/${date.year} '
        '$hour:$minute $period';
  }

  Widget _buildIncidentList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> incidents,
      bool isDesktop,
      ) {
    if (incidents.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE7ECF3)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: Color(0xFF9AA6B6),
            ),
            SizedBox(height: 12),
            Text(
              'No incident reports found.',
              style: TextStyle(
                color: Color(0xFF69778C),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try changing your search or filter.',
              style: TextStyle(
                color: Color(0xFF9AA6B6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (!isDesktop) {
      return Column(
        children: incidents
            .map((doc) => _incidentCard(doc.id, doc.data()))
            .toList(),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            const Color(0xFFF7F9FC),
          ),
          headingTextStyle: const TextStyle(
            color: Color(0xFF69778C),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          dataTextStyle: const TextStyle(
            color: Color(0xFF344054),
            fontSize: 12,
          ),
          columnSpacing: 24,
          horizontalMargin: 18,
          columns: const [
            DataColumn(label: Text('CATEGORY')),
            DataColumn(label: Text('LOCATION')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('DATE REPORTED')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: incidents.map((doc) {
            final data = doc.data();
            final category = (data['category'] ?? 'Unknown').toString();
            final location = (data['location'] ?? 'Unknown').toString();
            final status = (data['status'] ?? 'New').toString();
            final createdAt = data['createdAt'];

            final date = createdAt is Timestamp
                ? _formatDate(createdAt.toDate())
                : 'Pending';

            final statusColor = _statusColor(status);

            return DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 135,
                    child: Row(
                      children: [
                        Icon(
                          _categoryIcon(category),
                          color: _categoryColor(category),
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 140,
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(date)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View details',
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 19,
                        ),
                        onPressed: () => _showIncidentDetails(context, data),
                      ),
                      if (status != 'Resolved')
                        PopupMenuButton<String>(
                          tooltip: 'Update status',
                          onSelected: (newStatus) {
                            _updateStatus(doc.id, newStatus);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'New',
                              child: Text('New'),
                            ),
                            PopupMenuItem(
                              value: 'Under Investigation',
                              child: Text('Under Investigation'),
                            ),
                            PopupMenuItem(
                              value: 'Resolved',
                              child: Text('Resolved'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('incidents').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading incidents:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final incidents = (snapshot.data?.docs ?? []).toList();

          incidents.sort((a, b) {
            final aTime = a.data()['createdAt'];
            final bTime = b.data()['createdAt'];

            if (aTime is Timestamp && bTime is Timestamp) {
              return bTime.compareTo(aTime);
            }
            if (aTime is Timestamp) return -1;
            if (bTime is Timestamp) return 1;
            return 0;
          });

          final total = incidents.length;

          final newCount = incidents
              .where((doc) => doc.data()['status'] == 'New')
              .length;

          final investigatingCount = incidents
              .where(
                (doc) => doc.data()['status'] == 'Under Investigation',
          )
              .length;

          final resolvedCount = incidents
              .where((doc) => doc.data()['status'] == 'Resolved')
              .length;

          final emergencyCount = incidents.where((doc) {
            final data = doc.data();
            final category = (data['category'] ?? '').toString();
            final status = (data['status'] ?? 'New').toString();

            return category == 'Emergency' && status != 'Resolved';
          }).length;

          final filteredIncidents = incidents.where((doc) {
            final data = doc.data();
            final category = (data['category'] ?? 'Unknown').toString();
            final status = (data['status'] ?? 'New').toString();
            final location = (data['location'] ?? '').toString();
            final description = (data['description'] ?? '').toString();

            final matchesFilter = _selectedFilter == 'All'
                ? true
                : _selectedFilter == 'Emergency'
                ? category == 'Emergency'
                : status == _selectedFilter;

            final query = _searchQuery.trim().toLowerCase();
            final matchesSearch = query.isEmpty ||
                category.toLowerCase().contains(query) ||
                location.toLowerCase().contains(query) ||
                description.toLowerCase().contains(query) ||
                doc.id.toLowerCase().contains(query);

            return matchesFilter && matchesSearch;
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              final pagePadding = isDesktop ? 28.0 : 16.0;

              return SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Safety Overview',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF172B4D),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isDesktop
                              ? 'A summary of incident reports across campus.'
                              : 'Monitor and manage campus safety reports.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF77849A),
                          ),
                        ),
                        const SizedBox(height: 22),

                        if (isDesktop)
                          Row(
                            children: [
                              _statCard(
                                'Total Reports',
                                total.toString(),
                                Icons.assessment_outlined,
                                AppColors.umBlue,
                              ),
                              const SizedBox(width: 12),
                              _statCard(
                                'New',
                                newCount.toString(),
                                Icons.fiber_new_outlined,
                                Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              _statCard(
                                'Investigating',
                                investigatingCount.toString(),
                                Icons.search,
                                Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              _statCard(
                                'Resolved',
                                resolvedCount.toString(),
                                Icons.check_circle_outline,
                                Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _statCard(
                                'Emergencies',
                                emergencyCount.toString(),
                                Icons.warning_amber_rounded,
                                Colors.red,
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Row(
                                children: [
                                  _statCard(
                                    'Total Reports',
                                    total.toString(),
                                    Icons.assessment_outlined,
                                    AppColors.umBlue,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'New',
                                    newCount.toString(),
                                    Icons.fiber_new_outlined,
                                    Colors.blue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    'Investigating',
                                    investigatingCount.toString(),
                                    Icons.search,
                                    Colors.orange,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Resolved',
                                    resolvedCount.toString(),
                                    Icons.check_circle_outline,
                                    Colors.green,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    'Emergencies',
                                    emergencyCount.toString(),
                                    Icons.warning_amber_rounded,
                                    Colors.red,
                                  ),
                                ],
                              ),
                            ],
                          ),

                        const SizedBox(height: 22),

                        if (emergencyCount > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD8D5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFD92D20),
                                  size: 23,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Emergency reports need attention',
                                        style: TextStyle(
                                          color: Color(0xFFB42318),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$emergencyCount unresolved emergency report(s). Please review them.',
                                        style: const TextStyle(
                                          color: Color(0xFF912018),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Incident Reports',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF172B4D),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Review reports and update their status.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF77849A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${filteredIncidents.length} results',
                              style: const TextStyle(
                                color: Color(0xFF77849A),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText:
                                    'Search category, location, description or ID',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE1E7EF),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE1E7EF),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedFilter,
                                  decoration: InputDecoration(
                                    labelText: 'Filter status',
                                    filled: true,
                                    fillColor: Colors.white,
                                    isDense: true,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                  ),
                                  items: _filters.map((filter) {
                                    return DropdownMenuItem<String>(
                                      value: filter,
                                      child: Text(filter),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedFilter = value;
                                    });
                                  },
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search incident reports',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE1E7EF),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE1E7EF),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedFilter,
                                decoration: InputDecoration(
                                  labelText: 'Filter reports',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: _filters.map((filter) {
                                  return DropdownMenuItem<String>(
                                    value: filter,
                                    child: Text(filter),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedFilter = value;
                                  });
                                },
                              ),
                            ],
                          ),

                        const SizedBox(height: 16),

                        _buildIncidentList(
                          filteredIncidents,
                          isDesktop,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}