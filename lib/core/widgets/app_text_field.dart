import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_palette.dart';

/// Campo de texto estándar de la aplicación sincronizado con la paleta activa.
class AppTextField extends ConsumerWidget {
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
    this.maxLength,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
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
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(selectedAppPaletteProvider);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: palette.surface.withOpacity(palette.darkBackground ? 0.82 : 0.94),
        labelStyle: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w800),
        hintStyle: TextStyle(color: palette.textSecondary.withOpacity(0.68), fontWeight: FontWeight.w600),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.accent, width: 1.6),
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Icon(prefixIcon, color: palette.secondary),
              ),
        suffixIcon: readOnly ? Icon(Icons.lock_outline_rounded, size: 18, color: palette.textSecondary) : null,
        counterText: maxLength == null ? null : '',
      ),
      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      readOnly: readOnly,
      onChanged: onChanged,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      textCapitalization: textCapitalization,
    );
  }
}
