import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../models/employee.dart';
import '../../services/employee_service.dart';

class AddEditEmployeeScreen extends ConsumerStatefulWidget {
  final Employee? employee;

  const AddEditEmployeeScreen({super.key, this.employee});

  @override
  ConsumerState<AddEditEmployeeScreen> createState() => _AddEditEmployeeScreenState();
}

class _AddEditEmployeeScreenState extends ConsumerState<AddEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _aadharController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _overtimeRateController;
  late TextEditingController _dailySalaryController;
  late TextEditingController _monthlySalaryController;
  DateTime? _selectedDob;
  late String _salaryType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name);
    _phoneController = TextEditingController(text: employee?.phone);
    _aadharController = TextEditingController(text: employee?.aadharNumber);
    
    final initialHourlyRate = employee?.hourlyRate ?? 100.0;
    _hourlyRateController = TextEditingController(text: initialHourlyRate.toStringAsFixed(2));
    _overtimeRateController = TextEditingController(
      text: employee?.overtimeRate.toString() ?? '150.0',
    );
    
    _salaryType = employee?.salaryType ?? 'Daily';
    
    // Calculate initial daily/monthly values
    double dailyVal = _salaryType == 'Daily' ? initialHourlyRate * 8 : (initialHourlyRate * 8);
    double monthlyVal = _salaryType == 'Monthly' ? initialHourlyRate * 8 * 26 : (initialHourlyRate * 8 * 26);
    
    _dailySalaryController = TextEditingController(text: dailyVal.toStringAsFixed(0));
    _monthlySalaryController = TextEditingController(text: monthlyVal.toStringAsFixed(0));

    _selectedDob = employee?.dateOfBirth;

    // Add listeners for automatic calculation
    _dailySalaryController.addListener(_updateHourlyRate);
    _monthlySalaryController.addListener(_updateHourlyRate);
  }

  void _updateHourlyRate() {
    if (!mounted) return;
    double amount = 0;
    if (_salaryType == 'Daily') {
      amount = double.tryParse(_dailySalaryController.text) ?? 0;
      final hourly = amount / 8;
      _hourlyRateController.text = hourly.toStringAsFixed(2);
    } else {
      amount = double.tryParse(_monthlySalaryController.text) ?? 0;
      final hourly = amount / (26 * 8);
      _hourlyRateController.text = hourly.toStringAsFixed(2);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Date of Birth')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Validate active salary is not 0
      final dailyAmt = double.tryParse(_dailySalaryController.text) ?? 0;
      final monthlyAmt = double.tryParse(_monthlySalaryController.text) ?? 0;
      
      if (_salaryType == 'Daily' && dailyAmt <= 0) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Daily Salary')));
        return;
      }
      if (_salaryType == 'Monthly' && monthlyAmt <= 0) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Monthly Salary')));
        return;
      }

      final employee = Employee(
        id: widget.employee?.id ?? '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        aadharNumber: _aadharController.text.trim(),
        dateOfBirth: _selectedDob!,
        salaryType: _salaryType,
        hourlyRate: double.tryParse(_hourlyRateController.text) ?? 100.0,
        overtimeRate: double.tryParse(_overtimeRateController.text) ?? 150.0,
        shiftId: widget.employee?.shiftId ?? 'Default',
        status: widget.employee?.status ?? 'Active',
        joinedDate: widget.employee?.joinedDate ?? DateTime.now(),
      );

      if (widget.employee == null) {
        await ref.read(employeeServiceProvider).addEmployee(employee);
      } else {
        await ref.read(employeeServiceProvider).updateEmployee(employee);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      appBar: AppBar(
        title: Text(widget.employee == null ? 'Add New Employee' : 'Edit Employee'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Employee Details'),
                  const SizedBox(height: AppSpacing.m),
                  
                  _buildTextField(
                    'Full Name', 
                    _nameController, 
                    Icons.person_outline,
                    hint: 'Enter first and last name',
                  ),
                  const SizedBox(height: AppSpacing.m),
                  
                  _buildDatePicker(context),
                  const SizedBox(height: AppSpacing.m),

                  _buildTextField(
                    'Aadhar Card Number', 
                    _aadharController, 
                    Icons.credit_card, 
                    keyboardType: TextInputType.number,
                    hint: '12-digit number',
                    maxLength: 12,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Field required';
                      if (val.length != 12) return 'Must be 12 digits';
                      if (!RegExp(r'^[0-9]+$').hasMatch(val)) return 'Digits only';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),

                  _buildTextField(
                    'Phone Number', 
                    _phoneController, 
                    Icons.phone_outlined, 
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Field required';
                      if (val.length != 10) return 'Must be 10 digits';
                      if (!RegExp(r'^[0-9]+$').hasMatch(val)) return 'Digits only';
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionTitle('Salary Details'),
                  const SizedBox(height: AppSpacing.m),
                  
                  _buildSalaryTypeRadio(),
                  const SizedBox(height: AppSpacing.m),

                  Row(
                    children: [
                      Expanded(
                      child: _buildTextField(
                        'Hourly Rate (₹)', 
                        _hourlyRateController, 
                        Icons.currency_rupee, 
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        readOnly: true,
                        hint: 'Autocalculated',
                      ),
                    ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _buildTextField(
                          'Overtime Rate per hour (₹)', 
                          _overtimeRateController, 
                          Icons.more_time, 
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.employee == null ? 'Save Employee' : 'Update Employee'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textHigh),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, String? hint, int? maxLength, bool readOnly = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            if (maxLength != null)
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  final bool isComplete = value.text.length == maxLength;
                  return Text(
                    '${value.text.length}/$maxLength',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? const Color(0xFF50C878) : AppColors.error,
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: readOnly ? const TextStyle(color: AppColors.textMedium) : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.textMedium, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? AppColors.backgroundAlt : Colors.white,
            hintText: hint,
          ),
          validator: validator ?? (val) => val!.isEmpty ? 'Field required' : null,
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.textMedium, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDob == null 
                    ? 'Select Date' 
                    : DateFormat('dd/MM/yyyy').format(_selectedDob!),
                  style: TextStyle(
                    color: _selectedDob == null ? AppColors.textLow : AppColors.textHigh,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryTypeRadio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Salary Basis', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        
        // Daily Salary Row
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Salary per day'),
                value: 'Daily',
                groupValue: _salaryType,
                onChanged: (val) {
                  setState(() => _salaryType = val!);
                  _updateHourlyRate();
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_salaryType == 'Daily')
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _dailySalaryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.currency_rupee, size: 16),
                    hintText: 'Amount',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
          ],
        ),

        // Monthly Salary Row
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Salary per month'),
                value: 'Monthly',
                groupValue: _salaryType,
                onChanged: (val) {
                  setState(() => _salaryType = val!);
                  _updateHourlyRate();
                },
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_salaryType == 'Monthly')
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _monthlySalaryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.currency_rupee, size: 16),
                    hintText: 'Amount',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _hourlyRateController.dispose();
    _overtimeRateController.dispose();
    _dailySalaryController.dispose();
    _monthlySalaryController.dispose();
    super.dispose();
  }
}
