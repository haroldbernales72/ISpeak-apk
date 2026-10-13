
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import '../constants/app_colors.dart';
import '../models/incident_model.dart';
import '../services/incident_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState
    extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final IncidentService _incidentService = IncidentService();
  final ImagePicker _picker = ImagePicker();

  String _selectedCategory = 'Bullying';
  bool _isAnonymous = true;
  bool _isLoading = false;
  bool _isUploadingMedia = false;

  Uint8List? _selectedBytes;
  String? _selectedFileName;
  String? _selectedContentType;

  static const int _maxFileSize = 5 * 1024 * 1024;

  final List<String> _categories = [
    'Weapons',
    'Drugs',
    'Bullying',
    'Theft',
    'Vandalism',
    'Other',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Select a photo.
  Future<void> _pickPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.length > _maxFileSize) {
        _showMessage('Photo must be 5 MB or smaller.');
        return;
      }

      final name = file.name.toLowerCase();
      final isJpg = name.endsWith('.jpg') ||
          name.endsWith('.jpeg');
      final isPng = name.endsWith('.png');

      if (!isJpg && !isPng) {
        _showMessage('Only JPG and PNG photos are accepted.');
        return;
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _selectedContentType =
        isPng ? 'image/png' : 'image/jpeg';
      });
    } catch (e) {
      _showMessage('Could not select photo: $e');
    }
  }

  // Select a PDF document.
  Future<void> _pickPdf() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) return;

      final file = files.first;
      final Uint8List bytes = await file.readAsBytes();

      if (bytes.length > _maxFileSize) {
        _showMessage('PDF must be 5 MB or smaller.');
        return;
      }

      if (!file.name.toLowerCase().endsWith('.pdf')) {
        _showMessage('Please select a PDF document.');
        return;
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _selectedContentType = 'application/pdf';
      });
    } catch (e) {
      _showMessage('Could not select PDF: $e');
    }
  }

  void _removeEvidence() {
    setState(() {
      _selectedBytes = null;
      _selectedFileName = null;
      _selectedContentType = null;
    });
  }

  // Upload evidence to the private Supabase bucket.
  // Returns the storage path, not a public URL.

  Future<String?> _uploadEvidence(String incidentId) async {
    if (_selectedBytes == null ||
        _selectedFileName == null ||
        _selectedContentType == null) {
      return null;
    }

    setState(() {
      _isUploadingMedia = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please sign in again.');
      }

      final token = await user.getIdToken(true);

      if (token == null) {
        throw Exception('Could not obtain your sign-in token.');
      }

      final originalName = _selectedFileName!
          .split('/')
          .last
          .split('\\')
          .last;

      final safeName = originalName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );

      final storagePath = '${user.uid}/$incidentId-$safeName';

      final response = await Supabase.instance.client.functions.invoke(
        'upload-incident-evidence',
        headers: {
          'Authorization': 'Bearer $token',
        },
        body: {
          'storagePath': storagePath,
          'fileBase64': base64Encode(_selectedBytes!),
          'contentType': _selectedContentType!,
        },
      );

      if (response.status != 200 ||
          response.data is! Map ||
          response.data['success'] != true) {
        final message = response.data is Map
            ? response.data['error']?.toString()
            : null;

        throw Exception(message ?? 'Evidence upload failed.');
      }

      return storagePath;
    } catch (e) {
      throw Exception('Evidence upload failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingMedia = false;
        });
      }
    }
  }


  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('You must be logged in to submit a report.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final incidentId =
      DateTime.now().millisecondsSinceEpoch.toString();

      // If evidence was selected, require its upload to succeed.
      final mediaPath = await _uploadEvidence(incidentId);

      final incident = IncidentModel(
        id: incidentId,
        reporterId: currentUser.uid,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        isAnonymous: _isAnonymous,
        status: 'New',
        createdAt: DateTime.now(),
        mediaUrl: mediaPath,
      );

      await _incidentService.createIncident(incident);

      if (!mounted) return;

      _showMessage('Incident report submitted successfully.');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Failed to submit report: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Incident'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  size: 65,
                  color: AppColors.umBlue,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Report an Incident',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provide accurate information about the incident. '
                      'You may submit the report anonymously.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 30),

                // Incident category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: _inputDecoration(
                    label: 'Incident Category',
                    icon: Icons.category_outlined,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration(
                    label: 'Incident Location',
                    icon: Icons.location_on_outlined,
                    hint: 'Example: Building A, Room 204',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the incident location.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  decoration: _inputDecoration(
                    label: 'Description',
                    icon: Icons.description_outlined,
                    hint: 'Describe what happened...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please describe the incident.';
                    }
                    if (value.trim().length < 10) {
                      return 'Please provide more details.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Anonymous option
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Submit Anonymously',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _isAnonymous
                          ? 'Your identity will be hidden from other users.'
                          : 'Your identity may be visible to authorized staff.',
                    ),
                    value: _isAnonymous,
                    onChanged: (value) {
                      setState(() {
                        _isAnonymous = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Evidence attachment
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.umBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.umBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 35,
                        color: AppColors.umBlue,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Evidence Attachment',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Attach one JPG, PNG, or PDF file (maximum 5 MB).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (_selectedBytes != null &&
                          _selectedContentType != 'application/pdf')
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _selectedBytes!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),

                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              _selectedContentType == 'application/pdf'
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color: AppColors.umBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedFileName!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove evidence',
                              onPressed:
                              _isLoading ? null : _removeEvidence,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isLoading || _isUploadingMedia
                                ? null
                                : _pickPhoto,
                            icon: const Icon(Icons.photo_outlined),
                            label: const Text('Choose Photo'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isLoading || _isUploadingMedia
                                ? null
                                : _pickPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Choose PDF'),
                          ),
                        ],
                      ),

                      if (_isUploadingMedia) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 6),
                        const Text('Uploading evidence...'),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // Submit button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading || _isUploadingMedia
                        ? null
                        : _submitReport,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isLoading ? 'Submitting...' : 'Submit Report',
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'For emergencies requiring immediate assistance, '
                      'use the Quick Alert button instead.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
