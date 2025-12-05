import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

import '../../models/medical_report_model.dart';
import '../../services/medical_report_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

final medicalReportServiceProvider = Provider<MedicalReportService>(
  (ref) => MedicalReportService(),
);

final reportDetailsProvider =
    StreamProvider.family<MedicalReportModel?, String>((ref, reportId) {
      final reportService = ref.read(medicalReportServiceProvider);
      return reportService.getReportStreamById(reportId);
    });

class ReportDetailsScreen extends ConsumerWidget {
  final String reportId;

  const ReportDetailsScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportDetailsProvider(reportId));
    final currentUser = ref.watch(authStateNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: reportAsync.when(
        data: (report) {
          if (report == null) {
            return const Center(child: Text('Report not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Header
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF2196F3),
                          child: Icon(
                            _getReportTypeIcon(report.type),
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getReportTypeLabel(report.type),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Report Information
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Report Date',
                          _formatDate(report.reportDate),
                        ),
                        _buildInfoRow(
                          'Uploaded',
                          _formatDateTime(report.uploadedAt),
                        ),
                        if (report.description != null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            report.description!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                        if (report.reviewedBy != null &&
                            report.reviewedAt != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            'Reviewed',
                            _formatDateTime(report.reviewedAt!),
                          ),
                          _buildInfoRow(
                            'Reviewed By',
                            'Doctor ID: ${report.reviewedBy}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // File Viewer/Actions
                _buildFileViewer(context, report),

                // Delete button (for patients only)
                if (currentUser != null &&
                    currentUser.userType == UserType.patient &&
                    currentUser.uid == report.patientId) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _deleteReport(context, ref, report),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Delete Report',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ],
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
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FILE VIEWER WIDGET ---
  Widget _buildFileViewer(BuildContext context, MedicalReportModel report) {
    final String url = report.fileUrl;
    final String name = report.fileName.toLowerCase();

    // The shared widget for the viewer content
    final viewerWidget = name.endsWith('.pdf')
        ? FutureBuilder<http.Response>(
            future: http.get(Uri.parse(url)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                return _buildErrorState(
                  context,
                  url,
                  'Failed to load PDF bytes.',
                );
              }
              return PdfPreview(
                build: (format) => snapshot.data!.bodyBytes,
                allowSharing: true,
                allowPrinting: true,
                maxPageWidth: 700,
              );
            },
          )
        : Image.network(
            url,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorState(context, url, 'Failed to load image.');
            },
          );

    // 1. PDF VIEWER / IMAGE VIEWER
    if (name.endsWith('.pdf') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png')) {
      return Card(
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                'Viewing File: ${report.fileName}',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openReportFallback(url),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Open Externally'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push(
                          '/fullscreen-viewer',
                          extra: {
                            'report': report,
                            'viewerWidget': viewerWidget,
                          },
                        );
                      },
                      icon: const Icon(Icons.fullscreen),
                      label: const Text('Full Screen'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Viewer Section
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: viewerWidget,
            ),
          ],
        ),
      );
    }
    // 3. FALLBACK (Show filename and button to attempt external launch)
    else {
      return _buildErrorState(
        context,
        url,
        'File type (${report.fileName.split('.').last.toUpperCase()}) not directly viewable.',
      );
    }
  }

  Widget _buildErrorState(
    BuildContext context,
    String fileUrl,
    String message,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Report File',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Status: $message', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openReportFallback(fileUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External App'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportFallback(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport(
    BuildContext context,
    WidgetRef ref,
    MedicalReportModel report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text(
          'Are you sure you want to delete this report? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final reportService = ref.read(medicalReportServiceProvider);
        await reportService.deleteReport(report.id, report.fileUrl);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
