import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/medical_report_model.dart';
import '../../services/medical_report_service.dart';
import '../../providers/auth_provider.dart';

final medicalReportServiceProvider =
    Provider<MedicalReportService>((ref) => MedicalReportService());

final patientReportsProvider = StreamProvider<List<MedicalReportModel>>((ref) {
  final currentUser = ref.watch(authStateNotifierProvider).value;
  if (currentUser == null) {
    return Stream.value([]);
  }
  final reportService = ref.read(medicalReportServiceProvider);
  return reportService.getPatientReportsStream(currentUser.uid);
});

class MedicalReportsScreen extends ConsumerStatefulWidget {
  const MedicalReportsScreen({super.key});

  @override
  ConsumerState<MedicalReportsScreen> createState() =>
      _MedicalReportsScreenState();
}

class _MedicalReportsScreenState extends ConsumerState<MedicalReportsScreen> {
  bool _isUploading = false;

  Future<void> _uploadReport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      setState(() => _isUploading = true);

      final currentUser = ref.read(authStateNotifierProvider).value;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final reportService = ref.read(medicalReportServiceProvider);

      // Show dialog to get report details
      final reportDetails = await _showReportDetailsDialog(fileName);
      if (reportDetails == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Upload file to Firebase Storage
      final fileUrl = await reportService.uploadReportFile(file, currentUser.uid);

      // Create report document
      final report = MedicalReportModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: currentUser.uid,
        title: reportDetails['title']!,
        type: reportDetails['type'] as ReportType,
        description: reportDetails['description'],
        fileUrl: fileUrl,
        fileName: fileName,
        reportDate: reportDetails['reportDate'] as DateTime,
        uploadedAt: DateTime.now(),
      );

      await reportService.createReport(report);

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showReportDetailsDialog(String fileName) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    ReportType? selectedType;
    DateTime? reportDate = DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Report Title *',
                    hintText: 'e.g., Blood Test Results',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReportType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Report Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: ReportType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getReportTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Additional notes...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Report Date'),
                  subtitle: Text(
                    reportDate != null
                        ? '${reportDate!.day}/${reportDate!.month}/${reportDate!.year}'
                        : 'Not set',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: reportDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => reportDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty || selectedType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'title': titleController.text.trim(),
                  'type': selectedType,
                  'description': descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  'reportDate': reportDate ?? DateTime.now(),
                });
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  String _getReportTypeLabel(ReportType type) {
    switch (type) {
      case ReportType.labResult:
        return 'Lab Result';
      case ReportType.xRay:
        return 'X-Ray';
      case ReportType.mri:
        return 'MRI';
      case ReportType.ctScan:
        return 'CT Scan';
      case ReportType.ultrasound:
        return 'Ultrasound';
      case ReportType.prescription:
        return 'Prescription';
      case ReportType.other:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(patientReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical Reports'),
        actions: [
          IconButton(
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file),
            onPressed: _isUploading ? null : _uploadReport,
            tooltip: 'Upload Report',
          ),
        ],
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No medical reports yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your medical reports to keep them organized',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _uploadReport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Report'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(patientReportsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2196F3),
                      child: Icon(
                        _getReportTypeIcon(report.type),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      report.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getReportTypeLabel(report.type)),
                        Text(
                          'Uploaded: ${_formatDate(report.uploadedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (report.reviewedBy != null)
                          Text(
                            'Reviewed by doctor',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () {
                        context.push('/report-details/${report.id}');
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(patientReportsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getReportTypeIcon(ReportType type) {
    switch (type) {
      case ReportType.labResult:
        return Icons.science;
      case ReportType.xRay:
      case ReportType.mri:
      case ReportType.ctScan:
      case ReportType.ultrasound:
        return Icons.image;
      case ReportType.prescription:
        return Icons.description;
      case ReportType.other:
        return Icons.folder;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

