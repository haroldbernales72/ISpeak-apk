import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_colors.dart';
import '../services/incident_service.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final incidentService = IncidentService();

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reports')),
        body: const Center(
          child: Text('You must be logged in to view your reports.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: StreamBuilder(
        stream: incidentService.getUserIncidents(currentUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Failed to load reports.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final reports = snapshot.data?.docs ?? [];

          if (reports.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index].data();
              return _buildReportCard(context, report);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 80,
              color: AppColors.umBlue.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your submitted incident reports will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
      BuildContext context,
      Map<String, dynamic> report,
      ) {
    final category = report['category'] ?? 'Other';
    final description = report['description'] ?? '';
    final location = report['location'] ?? '';
    final status = report['status'] ?? 'New';
    final isAnonymous = report['isAnonymous'] ?? true;
    final mediaUrl = report['mediaUrl']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CATEGORY AND STATUS
            Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppColors.umBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.report_problem_outlined,
                    color: AppColors.umBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(status.toString()),
              ],
            ),

            const SizedBox(height: 16),

            // LOCATION
            const Text(
              'Location',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppColors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location.toString(),
                    style: const TextStyle(color: AppColors.grey),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // DESCRIPTION
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              description.toString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // EVIDENCE
            if (mediaUrl != null && mediaUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Evidence',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildEvidence(context, mediaUrl),
            ],

            const SizedBox(height: 14),

            // ANONYMOUS STATUS
            Row(
              children: [
                Icon(
                  isAnonymous
                      ? Icons.visibility_off_outlined
                      : Icons.person_outline,
                  size: 18,
                  color: AppColors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  isAnonymous
                      ? 'Submitted anonymously'
                      : 'Identity provided',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Create a signed URL for the private Supabase bucket.
  // Supports a stored object path or an existing signed URL.

  Future<String> _getEvidenceUrl(String storagePath) async {
    final trimmedPath = storagePath.trim();

    if (trimmedPath.isEmpty) {
      throw Exception('Evidence path is empty.');
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('You must be logged in to view evidence.');
    }

    // Normalize the path stored in Firestore.
    var cleanPath = trimmedPath;

    // Remove the bucket prefix if present.
    if (cleanPath.startsWith('incident-evidence/')) {
      cleanPath = cleanPath.substring('incident-evidence/'.length);
    }

    // Support older records that contain only a filename.
    if (!cleanPath.contains('/')) {
      cleanPath = '${currentUser.uid}/$cleanPath';
    }

    final pathParts = cleanPath.split('/');

    // Validate the path before sending it to the server.
    if (cleanPath.length > 512 ||
        cleanPath.startsWith('/') ||
        cleanPath.contains('\\') ||
        pathParts.length != 2 ||
        pathParts.any(
              (part) => part.isEmpty || part == '.' || part == '..',
        ) ||
        !RegExp(r'\.(jpg|jpeg|png|pdf)$', caseSensitive: false)
            .hasMatch(cleanPath)) {
      throw Exception('Invalid evidence storage path.');
    }

    // The requested file must be in this user's folder.
    if (pathParts.first != currentUser.uid) {
      throw Exception('This evidence does not belong to your account.');
    }

    try {
      // Get a fresh Firebase ID token.
      final token = await currentUser.getIdToken(true);

      if (token == null || token.isEmpty) {
        throw Exception('Could not verify your sign-in. Please log in again.');
      }

      debugPrint('Requesting evidence URL for: $cleanPath');

      // Ask the Edge Function to verify ownership and sign the private file.
      final response = await Supabase.instance.client.functions.invoke(
        'user-evidence-url',
        headers: {
          'Authorization': 'Bearer $token',
        },
        body: {
          'storagePath': cleanPath,
        },
      );

      final data = response.data;

      if (response.status != 200 || data is! Map) {
        final message = data is Map
            ? data['error']?.toString()
            : null;

        throw Exception(message ?? 'Unable to retrieve evidence URL.');
      }

      final signedUrl = data['signedUrl'];

      if (signedUrl is! String || signedUrl.isEmpty) {
        throw Exception('The server did not return a valid evidence URL.');
      }

      final uri = Uri.tryParse(signedUrl);

      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'jarsabtclofppwtkxnte.supabase.co') {
        throw Exception('The server returned an unrecognized evidence URL.');
      }

      debugPrint('Evidence URL retrieved successfully.');

      return signedUrl;
    } catch (e) {
      debugPrint('Evidence URL error: $e');
      rethrow;
    }
  }


  Widget _buildEvidence(BuildContext context, String storagePath) {
    final isPdf = storagePath.toLowerCase().split('?').first.endsWith('.pdf');

    return FutureBuilder<String>(
      future: _getEvidenceUrl(storagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Evidence error: ${snapshot.error ?? 'No URL returned.'}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final signedUrl = snapshot.data!;

        if (isPdf) {
          return Card(
            child: ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 36,
              ),
              title: const Text('PDF Evidence'),
              subtitle: const Text('Tap to open document'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final uri = Uri.tryParse(signedUrl);
                if (uri == null) return;

                try {
                  final opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to open PDF.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open PDF: $e')),
                    );
                  }
                }
              },
            ),
          );
        }

        // Tap the preview to view the complete photo.
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenPhotoViewer(
                    imageUrl: signedUrl,
                  ),
                ),
              );
            },
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(
                  signedUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Evidence image display error: $error');

                    return Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('Unable to display photo evidence'),
                        ],
                      ),
                    );
                  },
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'View full photo',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    IconData icon;

    switch (status) {
      case 'Under Investigation':
        icon = Icons.search;
        break;
      case 'Resolved':
        icon = Icons.check_circle_outline;
        break;
      default:
        icon = Icons.access_time;
    }

    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: statusColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Under Investigation':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      default:
        return AppColors.umBlue;
    }
  }
}

// Full-screen viewer: shows the complete image and supports zooming.
class FullScreenPhotoViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenPhotoViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Evidence Photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load full photo.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}