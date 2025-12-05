import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/medical_report_model.dart';

class PdfExportResult {
  final Uint8List summaryPdfBytes;

  /// Map of filename -> bytes for original files to be attached separately
  final Map<String, Uint8List> additionalAttachments;

  PdfExportResult({
    required this.summaryPdfBytes,
    required this.additionalAttachments,
  });
}

class PdfExportService {
  final DateFormat _dateFmt = DateFormat('MMM dd, yyyy');

  /// Generates a medical summary PDF and fetches original files if requested.
  Future<PdfExportResult> generateReportsPdf(
    List<MedicalReportModel> reports, {
    String? patientName,
    bool includeOriginalPdfs = false,
  }) async {
    final pdf = pw.Document();

    // Load fonts
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    // 1. Pre-fetch images to embed and PDFs to attach
    final Map<String, Uint8List> embeddedImages = {};
    final Map<String, Uint8List> separateAttachments = {};

    // Sort reports by date descending
    reports.sort((a, b) => b.reportDate.compareTo(a.reportDate));

    for (final r in reports) {
      if (r.fileUrl.isEmpty) continue;

      try {
        final uri = Uri.parse(r.fileUrl);

        // Determine file type based on extension in URL or fileName
        final isPdf =
            r.fileUrl.toLowerCase().contains('.pdf') ||
            r.fileName.toLowerCase().endsWith('.pdf');

        final isImage = _isImageUrl(r.fileUrl) || _isImageFile(r.fileName);

        if (isImage) {
          // Fetch image to embed in the summary PDF
          final resp = await http.get(uri);
          if (resp.statusCode == 200) {
            embeddedImages[r.id] = resp.bodyBytes;
          }
        } else if (includeOriginalPdfs && isPdf) {
          // Fetch original PDF to attach separately (cannot easily embed PDF inside PDF)
          final resp = await http.get(uri);
          if (resp.statusCode == 200) {
            // Use fileName or a safe fallback
            separateAttachments[r.fileName] = resp.bodyBytes;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching file for report ${r.id}: $e');
        }
      }
    }

    // 2. Build the PDF Structure
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) => _buildHeader(patientName),
        footer: (context) => _buildFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 20),
            pw.Text(
              'Report Summary',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),

            // Generate a section for each report
            ...reports.map((report) {
              final imageBytes = embeddedImages[report.id];
              return _buildReportSection(report, imageBytes);
            }),

            if (reports.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 20),
                child: pw.Center(child: pw.Text('No reports selected.')),
              ),
          ];
        },
      ),
    );

    return PdfExportResult(
      summaryPdfBytes: await pdf.save(),
      additionalAttachments: separateAttachments,
    );
  }

  pw.Widget _buildHeader(String? patientName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'EasyMed',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.Text(
              'Medical Record Export',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        if (patientName != null)
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Patient Name: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(patientName),
                pw.Spacer(),
                pw.Text(
                  'Date: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(_dateFmt.format(DateTime.now())),
              ],
            ),
          ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildReportSection(
    MedicalReportModel report,
    Uint8List? imageBytes,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 25),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Report Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: PdfColors.blue50,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    report.title,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Text(
                  _dateFmt.format(report.reportDate),
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),

          // Details Grid
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Type', _reportTypeLabel(report.type)),
                    _buildInfoRow('File Name', report.fileName),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                flex: 1,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Uploaded',
                      _dateFmt.format(report.uploadedAt),
                    ),
                    if (report.reviewedBy != null)
                      _buildInfoRow('Status', 'Reviewed by Doctor'),
                  ],
                ),
              ),
            ],
          ),

          // Description
          if (report.description != null && report.description!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Notes:',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              report.description!,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],

          // Embedded Image
          if (imageBytes != null) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              height: 200,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ],

          pw.Divider(color: PdfColors.grey200, thickness: 0.5),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  String _reportTypeLabel(ReportType type) {
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

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp');
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }
}
