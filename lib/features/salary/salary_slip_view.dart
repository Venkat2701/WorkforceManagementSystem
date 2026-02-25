import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/custom_card.dart';
import '../../models/salary_record.dart';
import '../../models/attendance.dart';
import '../../services/salary_service.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalarySlipView extends ConsumerStatefulWidget {
  final WeeklySalary salary;
  final bool isReadOnly;

  const SalarySlipView({
    super.key,
    required this.salary,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<SalarySlipView> createState() => _SalarySlipViewState();
}

class _SalarySlipViewState extends ConsumerState<SalarySlipView> {
  bool _isProcessing = false;
  late bool _currentPaidStatus;
  List<Attendance>? _attendanceRecords;
  bool _isLoadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _currentPaidStatus = widget.salary.paid;
    _fetchAttendanceDetails();
  }

  Future<void> _fetchAttendanceDetails() async {
    setState(() => _isLoadingAttendance = true);
    try {
      final start = DateTime(
        widget.salary.startDate.year,
        widget.salary.startDate.month,
        widget.salary.startDate.day,
      );
      final end = DateTime(
        widget.salary.endDate.year,
        widget.salary.endDate.month,
        widget.salary.endDate.day,
      ).add(const Duration(days: 1));

      // Querying only by date range to use existing single-field index.
      // Filtering employeeId in-memory to avoid composite index requirement.
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      final records = snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .where((a) => a.employeeId == widget.salary.employeeId)
          .toList();

      records.sort((a, b) => a.date.compareTo(b.date));
      if (mounted) setState(() => _attendanceRecords = records);
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  List<Attendance> get _filteredAttendance {
    if (_attendanceRecords == null) return [];
    if (widget.isReadOnly) return _attendanceRecords!;
    return _attendanceRecords!
        .where((r) => r.isPaid == _currentPaidStatus)
        .toList();
  }

  Map<double, double> _getRegularHoursBreakdown() {
    final Map<double, double> breakdown = {};

    final employee = ref
        .read(employeesStreamProvider)
        .value
        ?.firstWhere((e) => e.id == widget.salary.employeeId);

    for (var r in _filteredAttendance.where((r) => r.isPresent)) {
      final rate =
          r.hourlyRate ??
          (employee?.getHourlyRateForDate(r.date) ?? widget.salary.hourlyRate);
      if (r.hoursWorked > 0) {
        breakdown[rate] = (breakdown[rate] ?? 0.0) + r.hoursWorked;
      }
    }
    return breakdown;
  }

  Map<double, double> _getOvertimeHoursBreakdown() {
    final Map<double, double> breakdown = {};

    final employee = ref
        .read(employeesStreamProvider)
        .value
        ?.firstWhere((e) => e.id == widget.salary.employeeId);

    for (var r in _filteredAttendance.where((r) => r.isPresent)) {
      final rate =
          r.overtimeRate ??
          (employee?.getOvertimeRateForDate(r.date) ??
              widget.salary.overtimeRate);
      if (r.overtimeHours > 0) {
        breakdown[rate] = (breakdown[rate] ?? 0.0) + r.overtimeHours;
      }
    }
    return breakdown;
  }

  String _getFormattedBreakdown(Map<double, double> breakdown) {
    if (breakdown.isEmpty) return '';
    return breakdown.entries
        .map((e) {
          final hours = e.value % 1 == 0
              ? e.value.toInt().toString()
              : e.value.toStringAsFixed(1);
          return '${hours}h x ₹${e.key.toStringAsFixed(1)}';
        })
        .join(', ');
  }

  Future<void> _handlePayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text(
          'Are you sure you want to mark ₹${widget.salary.totalSalary.toStringAsFixed(0)} as PAID for ${widget.salary.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await ref
            .read(salaryServiceProvider)
            .markPeriodAsPaid(
              widget.salary.employeeId,
              widget.salary.startDate,
              widget.salary.endDate,
            );
        setState(() => _currentPaidStatus = true);
        await _fetchAttendanceDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment processed successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRevert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert Payment'),
        content: Text(
          'Are you sure you want to mark this payment as UNPAID for ${widget.salary.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Revert'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await ref
            .read(salaryServiceProvider)
            .revertPaymentStatus(
              widget.salary.employeeId,
              widget.salary.startDate,
              widget.salary.endDate,
            );
        setState(() => _currentPaidStatus = false);
        await _fetchAttendanceDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment reverted to Unpaid')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _downloadSlip() async {
    final pdf = await _generatePdf();
    final dateRange =
        '${DateFormat('MMM d').format(widget.salary.startDate)} to ${DateFormat('MMM d').format(widget.salary.endDate)}';
    final fileName =
        '${widget.salary.employeeName.replaceAll(' ', '_')}_$dateRange';

    // On Web, this triggers a direct download. On mobile, it opens the share sheet.
    await Printing.sharePdf(bytes: pdf, filename: '$fileName.pdf');
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Load a font that supports the Rupee symbol
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Foundry EMS - Salary Slip',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    pw.Text(DateFormat('MMM dd, yyyy').format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Employee: ${widget.salary.employeeName}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Employee ID: ${widget.salary.employeeId}'),
              pw.Text(
                'Period: ${DateFormat('MMM d').format(widget.salary.startDate)} to ${DateFormat('MMM d, yyyy').format(widget.salary.endDate)}',
              ),
              pw.SizedBox(height: 30),
              pw.Divider(),
              _pwRow('Description', 'Amount', isHeader: true),
              pw.Divider(),
              _pwRow(
                'Base Salary',
                '₹${widget.salary.baseSalary.toStringAsFixed(2)}',
              ),
              _pwText(_getFormattedBreakdown(_getRegularHoursBreakdown())),
              _pwRow(
                'Overtime Pay',
                '₹${widget.salary.overtimePay.toStringAsFixed(2)}',
              ),
              _pwText(_getFormattedBreakdown(_getOvertimeHoursBreakdown())),
              pw.Divider(),
              _pwRow(
                'Gross Total',
                '₹${widget.salary.totalSalary.toStringAsFixed(2)}',
                isBold: true,
              ),

              if (_attendanceRecords != null) ...[
                pw.SizedBox(height: 30),
                pw.Text(
                  'PAYMENT STATUS',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 10),
                ..._buildPdfPaymentBreakdown(),
              ],

              pw.SizedBox(height: 50),
              pw.Text(
                'Status: ${_currentPaidStatus ? 'PAID' : 'MIXED/UNPAID'}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'This is a computer-generated document and does not require a signature.',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  List<pw.Widget> _buildPdfPaymentBreakdown() {
    final records = _filteredAttendance;
    final paidRecords = records.where((r) => r.isPaid).toList();
    final unpaidRecords = records.where((r) => !r.isPaid).toList();

    List<pw.Widget> widgets = [];
    final employee = ref
        .read(employeesStreamProvider)
        .value
        ?.firstWhere((e) => e.id == widget.salary.employeeId);

    if (paidRecords.isNotEmpty) {
      double amount = paidRecords.fold(0, (sum, r) {
        final rHRate =
            r.hourlyRate ??
            (employee?.getHourlyRateForDate(r.date) ??
                widget.salary.hourlyRate);
        final rORate =
            r.overtimeRate ??
            (employee?.getOvertimeRateForDate(r.date) ??
                widget.salary.overtimeRate);
        return sum + (r.hoursWorked * rHRate) + (r.overtimeHours * rORate);
      });
      widgets.add(
        _pwRow(
          'Paid Amount (${_formatDateRanges(paidRecords.map((r) => r.date).toList())})',
          '₹${amount.toStringAsFixed(2)}',
        ),
      );
    }

    if (unpaidRecords.isNotEmpty) {
      double amount = unpaidRecords.fold(0, (sum, r) {
        final rHRate =
            r.hourlyRate ??
            (employee?.getHourlyRateForDate(r.date) ??
                widget.salary.hourlyRate);
        final rORate =
            r.overtimeRate ??
            (employee?.getOvertimeRateForDate(r.date) ??
                widget.salary.overtimeRate);
        return sum + (r.hoursWorked * rHRate) + (r.overtimeHours * rORate);
      });
      widgets.add(
        _pwRow(
          'Due Amount (${_formatDateRanges(unpaidRecords.map((r) => r.date).toList())})',
          '₹${amount.toStringAsFixed(2)}',
        ),
      );
    }

    return widgets;
  }

  pw.Widget _pwRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    final style = pw.TextStyle(
      fontWeight: (isHeader || isBold)
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
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

  pw.Widget _pwText(String text) {
    if (text.isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context, _currentPaidStatus != widget.salary.paid),
        ),
        actions: [
          if (widget.isReadOnly || _currentPaidStatus)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadSlip,
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
                      Text(
                        '₹${widget.salary.totalSalary.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: widget.isReadOnly
                              ? const Color(0xFFF57C00)
                              : (_currentPaidStatus
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFFEF5350)),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isReadOnly)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _currentPaidStatus
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _currentPaidStatus
                              ? const Color(0xFF66BB6A).withOpacity(0.5)
                              : const Color(0xFFEF5350).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _currentPaidStatus ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          color: _currentPaidStatus
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildInfoRow('Employee Name', widget.salary.employeeName),
              _buildInfoRow(
                'Employee ID',
                widget.salary.employeeId.substring(0, 8).toUpperCase(),
              ),
              _buildInfoRow(
                'Period',
                '${DateFormat('MMM d').format(widget.salary.startDate)} to ${DateFormat('MMM d, yyyy').format(widget.salary.endDate)}',
              ),
              _buildPaymentDetailsSection(),
              const Divider(height: 40),
              const Text(
                'EARNINGS BREAKDOWN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.m),
              _buildDetailRow(
                'Base Salary',
                _getFormattedBreakdown(_getRegularHoursBreakdown()),
                '₹${widget.salary.baseSalary.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                'Overtime Pay',
                _getFormattedBreakdown(_getOvertimeHoursBreakdown()),
                '₹${widget.salary.overtimePay.toStringAsFixed(2)}',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gross Total',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '₹${widget.salary.totalSalary.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    if (widget.isReadOnly || _currentPaidStatus) ...[
                      OutlinedButton.icon(
                        onPressed: _downloadSlip,
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.m,
                          ),
                          minimumSize: const Size(double.infinity, 50),
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.m),
                    ],
                    if (!widget.isReadOnly) ...[
                      if (!_currentPaidStatus) ...[
                        const SizedBox(height: AppSpacing.m),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _handlePayment,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isProcessing ? 'Processing...' : 'Mark as Paid',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.m,
                            ),
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: const Color(0xFF66BB6A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: AppSpacing.m),
                        Consumer(
                          builder: (context, ref, child) {
                            final userRole = ref.watch(userRoleProvider).value;
                            if (userRole == 'superadmin') {
                              return TextButton.icon(
                                onPressed: _isProcessing ? null : _handleRevert,
                                icon: _isProcessing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.history, size: 18),
                                label: Text(
                                  _isProcessing
                                      ? 'Processing...'
                                      : 'Revert to Unpaid',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.m,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection() {
    if (_isLoadingAttendance) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Determine if we have any records to show
    final presentRecords = _filteredAttendance
        .where((r) => r.isPresent)
        .toList();
    if (presentRecords.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const Divider(height: 40),
        _buildPaymentBreakdown(presentRecords),
      ],
    );
  }

  Widget _buildPaymentBreakdown(List<Attendance> records) {
    final paidRecords = records.where((r) => r.isPaid).toList();
    final unpaidRecords = records.where((r) => !r.isPaid).toList();

    double paidAmount = 0;
    final employee = ref
        .read(employeesStreamProvider)
        .value
        ?.firstWhere((e) => e.id == widget.salary.employeeId);

    for (var r in paidRecords) {
      final rHRate =
          r.hourlyRate ??
          (employee?.getHourlyRateForDate(r.date) ?? widget.salary.hourlyRate);
      final rORate =
          r.overtimeRate ??
          (employee?.getOvertimeRateForDate(r.date) ??
              widget.salary.overtimeRate);
      paidAmount += (r.hoursWorked * rHRate) + (r.overtimeHours * rORate);
    }

    double unpaidAmount = 0;
    for (var r in unpaidRecords) {
      final rHRate =
          r.hourlyRate ??
          (employee?.getHourlyRateForDate(r.date) ?? widget.salary.hourlyRate);
      final rORate =
          r.overtimeRate ??
          (employee?.getOvertimeRateForDate(r.date) ??
              widget.salary.overtimeRate);
      unpaidAmount += (r.hoursWorked * rHRate) + (r.overtimeHours * rORate);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAYMENT STATUS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: AppSpacing.m),
        if (paidAmount > 0)
          _buildStatusRow(
            'Paid Amount',
            '₹${paidAmount.toStringAsFixed(2)}',
            _formatDateRanges(paidRecords.map((r) => r.date).toList()),
            const Color(0xFF43A047),
          ),
        if (paidAmount > 0 && unpaidAmount > 0)
          const SizedBox(height: AppSpacing.s),
        if (unpaidAmount > 0)
          _buildStatusRow(
            'Due Amount',
            '₹${unpaidAmount.toStringAsFixed(2)}',
            _formatDateRanges(unpaidRecords.map((r) => r.date).toList()),
            const Color(0xFFEF5350),
          ),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String amount,
    String dates,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  dates,
                  style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRanges(List<DateTime> rawDates) {
    if (rawDates.isEmpty) return '';

    // Normalize to unique dates (ignoring time)
    final dates = rawDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();

    dates.sort();
    List<String> ranges = [];
    DateTime? start = dates[0];
    DateTime? prev = dates[0];

    for (int i = 1; i <= dates.length; i++) {
      if (i < dates.length &&
          dates[i].isAtSameMomentAs(prev!.add(const Duration(days: 1)))) {
        prev = dates[i];
      } else {
        if (start == prev) {
          ranges.add(DateFormat('MMM d').format(start!));
        } else {
          ranges.add(
            '${DateFormat('MMM d').format(start!)} - ${DateFormat('d').format(prev!)}',
          );
        }
        if (i < dates.length) {
          start = dates[i];
          prev = dates[i];
        }
      }
    }
    return ranges.join(', ');
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
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  calculation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
