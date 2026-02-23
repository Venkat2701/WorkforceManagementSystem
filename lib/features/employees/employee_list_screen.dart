import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../services/employee_service.dart';
import '../../models/employee.dart';
import 'add_edit_employee_screen.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesStreamProvider);

    return ResponsiveShell(
      title: 'Employee Directory',
      selectedIndex: 1,
      onDestinationSelected: (index) {},
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEditEmployeeScreen()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeesStreamProvider);
          // Wait for the stream to emit a new value to show the indicator for a moment
          await ref.read(employeesStreamProvider.future);
        },
        child: employeesAsync.when(
          data: (employees) => _EmployeeContent(employees: employees),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}

class _EmployeeContent extends StatefulWidget {
  final List<Employee> employees;

  const _EmployeeContent({required this.employees});

  @override
  State<_EmployeeContent> createState() => _EmployeeContentState();
}

class _EmployeeContentState extends State<_EmployeeContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredEmployees = widget.employees.where((e) {
      return e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.aadharNumber.contains(_searchQuery);
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by name or Aadhar...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMedium),
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ResponsiveLayout(
                mobile: _buildCardList(filteredEmployees),
                desktop: _buildDataTable(filteredEmployees),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(List<Employee> employees) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.m),
          child: CustomCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(employee: employee)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    employee.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Aadhar: ${employee.aadharNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SalaryTypeBadge(type: employee.salaryType),
                    const SizedBox(height: 4),
                    Text(
                      '₹${employee.hourlyRate.toInt()}/hr',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataTable(List<Employee> employees) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: CustomCard(
        padding: EdgeInsets.zero,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.backgroundAlt),
          columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Aadhar Number')),
            DataColumn(label: Text('DOB')),
            DataColumn(label: Text('Salary Basis')),
            DataColumn(label: Text('Actions')),
          ],
          rows: employees.map((employee) {
            return DataRow(cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(employee.name.substring(0, 1), style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(employee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(employee.phone, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(employee.aadharNumber)),
              DataCell(Text(DateFormat('dd/MM/yyyy').format(employee.dateOfBirth))),
              DataCell(_SalaryTypeBadge(type: employee.salaryType)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(employee: employee)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      onPressed: () {
                        // Handle delete
                      },
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _SalaryTypeBadge extends StatelessWidget {
  final String type;
  const _SalaryTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isDaily = type == 'Daily';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isDaily ? Colors.blue : Colors.purple).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: isDaily ? Colors.blue : Colors.purple,
          fontSize: 10, 
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
