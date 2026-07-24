/// Validadores reutilizables para formularios.
class Validators {
  static String? required(String? value, {String message = 'Campo obligatorio'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value);
    if (requiredError != null) return requiredError;
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
}
