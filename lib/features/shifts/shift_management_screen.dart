import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/responsive_shell.dart';
import '../../core/widgets/custom_card.dart';
import '../../services/shift_service.dart';
import '../../models/shift.dart';

class ShiftManagementScreen extends ConsumerWidget {
  const ShiftManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsStreamProvider);

    return ResponsiveShell(
      title: 'Shift Management',
      selectedIndex: 4,
      onDestinationSelected: (index) {},
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showShiftDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(shiftsStreamProvider);
          await ref.read(shiftsStreamProvider.future);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: shiftsAsync.when(
              data: (shifts) => LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1));
                  final childAspectRatio = constraints.maxWidth > 1200 ? 2.2 : (constraints.maxWidth > 900 ? 2.5 : (constraints.maxWidth > 600 ? 2.5 : 3.0));
  
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator to work
                    padding: const EdgeInsets.all(AppSpacing.l),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: AppSpacing.m,
                      mainAxisSpacing: AppSpacing.m,
                    ),
                    itemCount: shifts.length,
                    itemBuilder: (context, index) {
                      final shift = shifts[index];
                      return CustomCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.m),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppRadius.small),
                              ),
                              child: const Icon(Icons.schedule, color: AppColors.primary),
                            ),
                            const SizedBox(width: AppSpacing.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(shift.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('${shift.startTime} - ${shift.endTime}', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showShiftDialog(context, ref, shift: shift),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => ref.read(shiftServiceProvider).deleteShift(shift.id),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ),
      ),
    );
  }

  void _showShiftDialog(BuildContext context, WidgetRef ref, {Shift? shift}) {
    final nameController = TextEditingController(text: shift?.name);
    String startTime = shift?.startTime ?? '09:00';
    String endTime = shift?.endTime ?? '18:00';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(shift == null ? 'Add Shift Template' : 'Edit Shift Template'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController, 
                decoration: const InputDecoration(labelText: 'Shift Name', hintText: 'e.g. Morning Shift'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(context, 'Start Time', startTime, (time) {
                      setDialogState(() => startTime = time);
                    }),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker(context, 'End Time', endTime, (time) {
                      setDialogState(() => endTime = time);
                    }),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty) return;
                final newShift = Shift(
                  id: shift?.id ?? '',
                  name: nameController.text,
                  startTime: startTime,
                  endTime: endTime,
                );
                if (shift == null) {
                  ref.read(shiftServiceProvider).addShift(newShift);
                } else {
                  ref.read(shiftServiceProvider).updateShift(newShift);
                }
                Navigator.pop(context);
              },
              child: const Text('Save Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, String value, Function(String) onPicked) {
    return InkWell(
      onTap: () async {
        TimeOfDay initialTime = const TimeOfDay(hour: 9, minute: 0);
        try {
          if (value.contains(' ')) {
            // Handle "09:00 AM" format
            final timePart = value.split(' ')[0];
            final parts = timePart.split(':');
            var hour = int.parse(parts[0]);
            final minute = int.parse(parts[1]);
            if (value.toUpperCase().contains('PM') && hour < 12) hour += 12;
            if (value.toUpperCase().contains('AM') && hour == 12) hour = 0;
            initialTime = TimeOfDay(hour: hour, minute: minute);
          } else {
            final parts = value.split(':');
            initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
        } catch (_) {}

        final picked = await showTimePicker(context: context, initialTime: initialTime);
        if (picked != null) {
          onPicked('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.access_time, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
