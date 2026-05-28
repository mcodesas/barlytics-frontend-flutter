import 'package:flutter/material.dart';

/// Campo de texto estándar de la aplicación.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.prefixIcon,
    this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final IconData? prefixIcon;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
      cursorColor: scheme.secondary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Icon(prefixIcon, color: scheme.secondary),
              ),
        suffixIcon: readOnly ? Icon(Icons.lock_outline_rounded, size: 18, color: scheme.onSurface.withOpacity(0.48)) : null,
      ),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onChanged: onChanged,
    );
  }
}
