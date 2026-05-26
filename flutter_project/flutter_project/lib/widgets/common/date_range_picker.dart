import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangePickerWidget extends StatelessWidget {
  final DateTime fromDate;
  final DateTime toDate;
  final ValueChanged<DateTime> onFromChanged;
  final ValueChanged<DateTime> onToChanged;

  const DateRangePickerWidget({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.onFromChanged,
    required this.onToChanged,
  });

  Future<void> _pick(BuildContext context, bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      isFrom ? onFromChanged(picked) : onToChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _pick(context, true),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'من',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(fmt.format(fromDate)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => _pick(context, false),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'إلى',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: Text(fmt.format(toDate)),
            ),
          ),
        ),
      ],
    );
  }
}
