/// Validadores reutilizables para formularios.
class Validators {
  static String? required(String? value, {String message = 'Campo obligatorio'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? maxLength(
    String? value,
    int max, {
    String? message,
  }) {
    if (value == null || value.isEmpty) return null;
    if (value.length > max) {
      return message ?? 'Máximo $max caracteres';
    }
    return null;
  }

  static String? email(String? value, {int maxLength = 100}) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    final lengthError = Validators.maxLength(value, maxLength);
    if (lengthError != null) return lengthError;
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value!.trim())) return 'Correo inválido';
    return null;
  }

  static String? positiveNumber(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
    final number = num.tryParse(value!.replaceAll(',', '.'));
    if (number == null || number < 0) return 'Debe ser un número positivo';
    return null;
  }

  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
