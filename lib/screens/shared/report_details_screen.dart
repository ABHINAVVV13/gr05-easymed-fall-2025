import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/medical_report_model.dart';
import '../../services/medical_report_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';

final medicalReportServiceProvider =
    Provider<MedicalReportService>((ref) => MedicalReportService());

final reportDetailsProvider = StreamProvider.family<MedicalReportModel?, String>((ref, reportId) {
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
      appBar: AppBar(
        title: const Text('Report Details'),
      ),
      body: reportAsync.when(
        data: (report) {
          if (report == null) {
            return const Center(
              child: Text('Report not found'),
            );
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
                        _buildInfoRow('Report Date', _formatDate(report.reportDate)),
                        _buildInfoRow('Uploaded', _formatDateTime(report.uploadedAt)),
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
                        if (report.reviewedBy != null && report.reviewedAt != null) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow('Reviewed', _formatDateTime(report.reviewedAt!)),
                          _buildInfoRow('Reviewed By', 'Doctor ID: ${report.reviewedBy}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // File Actions
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Report File',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          report.fileName,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openReport(report.fileUrl),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('View Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReport(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
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

