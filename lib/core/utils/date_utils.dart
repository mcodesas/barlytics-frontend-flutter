import 'package:intl/intl.dart';

/// Utilidades de fecha para mostrar datos del backend.
class AppDateUtils {
  static String formatDateTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  static String formatDate(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return DateFormat('dd/MM/yyyy').format(date.toLocal());
  }
}
