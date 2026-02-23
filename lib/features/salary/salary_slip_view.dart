import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/custom_card.dart';
import '../../models/salary_record.dart';

class SalarySlipView extends StatelessWidget {
  final WeeklySalary salary;

  const SalarySlipView({super.key, required this.salary});

  Future<void> _printSlip() async {
    final pdf = await _generatePdf();
    final fileName = 'SalarySlip_${salary.employeeName.replaceAll(' ', '_')}_${salary.weekId.replaceAll(' ', '_')}';
    await Printing.layoutPdf(
      onLayout: (format) => pdf,
      name: fileName,
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Foundry EMS - Salary Slip', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Employee: ${salary.employeeName}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Employee ID: ${salary.employeeId}'),
              pw.Text('Period: ${salary.weekId}'),
              pw.SizedBox(height: 30),
              pw.Divider(),
              _pwRow('Description', 'Amount', isHeader: true),
              pw.Divider(),
              _pwRow('Base Salary (${salary.totalHours}h @ ₹${salary.hourlyRate})', '₹${salary.baseSalary.toStringAsFixed(2)}'),
              _pwRow('Overtime Pay (${salary.totalOvertime}h @ ₹${salary.overtimeRate})', '₹${salary.overtimePay.toStringAsFixed(2)}'),
              pw.Divider(),
              _pwRow('Gross Total', '₹${salary.totalSalary.toStringAsFixed(2)}', isBold: true),
              pw.SizedBox(height: 50),
              pw.Text('This is a computer-generated document and does not require a signature.', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _pwRow(String label, String value, {bool isHeader = false, bool isBold = false}) {
    final style = pw.TextStyle(
      fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: isHeader ? 14 : 12,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      appBar: AppBar(
        title: const Text('Salary Slip'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printSlip,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL PAYOUT', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                      Text(
                        '₹${salary.totalSalary.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Text('PAID', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildInfoRow('Employee Name', salary.employeeName),
              _buildInfoRow('Employee ID', salary.employeeId.substring(0, 8).toUpperCase()),
              _buildInfoRow('Week ID', salary.weekId),
              const Divider(height: 40),
              const Text('BREAKDOWN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: AppSpacing.m),
              _buildDetailRow('Base Salary', '${salary.totalHours}h x ₹${salary.hourlyRate}', '₹${salary.baseSalary.toStringAsFixed(2)}'),
              _buildDetailRow('Overtime Pay', '${salary.totalOvertime}h x ₹${salary.overtimeRate}', '₹${salary.overtimePay.toStringAsFixed(2)}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gross Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('₹${salary.totalSalary.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _printSlip,
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMedium)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String calculation, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(calculation, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
