import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

import '../../models/medical_report_model.dart';
import '../../services/medical_report_service.dart';
import '../../services/pdf_export_service.dart';
import '../../providers/auth_provider.dart';

final medicalReportServiceProvider = Provider<MedicalReportService>(
  (ref) => MedicalReportService(),
);

final pdfExportServiceProvider = Provider<PdfExportService>(
  (ref) => PdfExportService(),
);

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
  bool _isExporting = false;
  bool _includeOriginals = false;

  // --- EXPORT LOGIC ---

  void _showExportOptions(List<MedicalReportModel> reports) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share / Save to Files'),
              subtitle: Text(
                'Send summary and ${_includeOriginals ? 'attachments' : 'metadata'}',
              ),
              onTap: () {
                Navigator.pop(context);
                _handleExportAction(reports, action: 'share');
              },
            ),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print Summary PDF'),
              subtitle: const Text('Send summary directly to printer'),
              onTap: () {
                Navigator.pop(context);
                _handleExportAction(reports, action: 'print');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleExportAction(
    List<MedicalReportModel> reports, {
    required String action,
  }) async {
    if (reports.isEmpty) return;

    setState(() => _isExporting = true);
    final currentContext = context;
    final patientName =
        ref.read(authStateNotifierProvider).value?.displayName ?? "Patient";

    try {
      final pdfService = ref.read(pdfExportServiceProvider);

      final result = await pdfService.generateReportsPdf(
        reports,
        patientName: patientName,
        includeOriginalPdfs: _includeOriginals,
      );

      if (!currentContext.mounted) return;

      if (action == 'print') {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => result.summaryPdfBytes,
          name: 'Medical_Summary_$patientName',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final exportDir = await Directory(
          '${tempDir.path}/export_${DateTime.now().millisecondsSinceEpoch}',
        ).create();
        final List<XFile> filesToShare = [];

        final summaryFile = File(
          '${exportDir.path}/Medical_Summary_$patientName.pdf',
        );
        await summaryFile.writeAsBytes(result.summaryPdfBytes);
        filesToShare.add(XFile(summaryFile.path));

        if (_includeOriginals && result.additionalAttachments.isNotEmpty) {
          for (final entry in result.additionalAttachments.entries) {
            final cleanName = entry.key.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
            final file = File('${exportDir.path}/$cleanName');
            await file.writeAsBytes(entry.value);
            filesToShare.add(XFile(file.path));
          }
        }

        final box = currentContext.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          filesToShare,
          subject: 'Medical Reports - $patientName',
          sharePositionOrigin: box != null
              ? (box.localToGlobal(Offset.zero) & box.size)
              : null,
        );
      }
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // --- UPLOAD LOGIC ---

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

      final reportDetails = await _showReportDetailsDialog(fileName);
      if (reportDetails == null) {
        setState(() => _isUploading = false);
        return;
      }

      final fileUrl = await reportService.uploadReportFile(
        file,
        currentUser.uid,
      );

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

  // --- DIALOG & HELPER METHODS ---

  Future<Map<String, dynamic>?> _showReportDetailsDialog(
    String fileName,
  ) async {
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
                  value: selectedType,
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
                    '${reportDate!.day}/${reportDate?.month}/${reportDate?.year}',
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
                if (titleController.text.trim().isEmpty ||
                    selectedType == null) {
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

  // --- BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(patientReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical Reports'),
        actions: [
          // 1. ATTACHMENT TOGGLE
          IconButton(
            icon: Icon(
              Icons.attachment,
              color: _includeOriginals
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
            tooltip: 'Include original files in export',
            onPressed: () {
              final newValue = !_includeOriginals;
              setState(() => _includeOriginals = newValue);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    newValue
                        ? 'Including original files in export'
                        : 'Excluding original files from export',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // 2. EXPORT MENU BUTTON
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            onPressed:
                (reportsAsync.asData?.value == null ||
                    reportsAsync.asData!.value.isEmpty ||
                    _isExporting)
                ? null
                : () => _showExportOptions(reportsAsync.asData!.value),
            tooltip: 'Export Options (Share/Print)',
          ),
          // 3. UPLOAD BUTTON
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
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
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
            onRefresh: () async => ref.refresh(patientReportsProvider),
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
                      icon: const Icon(Icons.chevron_right),
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
}
