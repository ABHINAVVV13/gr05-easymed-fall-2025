import 'package:flutter/material.dart';
import '../../models/medical_report_model.dart';

class FullScreenViewer extends StatelessWidget {
  final MedicalReportModel report;
  final Widget viewerWidget;

  const FullScreenViewer({
    super.key,
    required this.report,
    required this.viewerWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(report.title), elevation: 0),
      body: Center(child: viewerWidget),
    );
  }
}
