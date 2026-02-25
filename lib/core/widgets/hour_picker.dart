import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

Future<int?> showHourPicker({
  required BuildContext context,
  required int initialHour,
  String title = 'Select Hour',
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Note: All times are rounded to the nearest hour.',
                style: TextStyle(fontSize: 12, color: AppColors.textMedium),
              ),
            ),
            Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(24, (index) {
                  final isSelected = index == initialHour;
                  return InkWell(
                    onTap: () => Navigator.pop(context, index),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        index.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.textHigh,
                        ),
                      ),
                    ),
                  );
                }),
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
      ],
    ),
  );
}
