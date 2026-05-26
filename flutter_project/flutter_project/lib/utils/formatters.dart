import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat currencyFormat = NumberFormat('#,##0.00', 'ar');
  static final DateFormat dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  static String formatCurrency(double amount) {
    return '${currencyFormat.format(amount)} ج.م';
  }

  static String formatDate(DateTime date) => dateFormat.format(date);
  static String formatDateTime(DateTime date) => dateTimeFormat.format(date);

  static String formatDateFromString(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    try {
      return dateFormat.format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  static String generateInvoiceNo(String prefix, int id) {
    return '$prefix${id.toString().padLeft(6, '0')}';
  }

  static String todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String generateAccessCode() {
    final now = DateTime.now();
    final base = now.millisecondsSinceEpoch % 1000000;
    return base.toString().padLeft(6, '0');
  }
}
