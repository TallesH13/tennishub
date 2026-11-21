import 'package:flutter/services.dart';

/// Máscara de data para campos de texto: aceita só dígitos e insere as
/// barras sozinha, no formato `dd/mm/aaaa`.
class BrDateInputFormatter extends TextInputFormatter {
  const BrDateInputFormatter();

  static const int _maxDigits = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > _maxDigits
        ? digits.substring(0, _maxDigits)
        : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(limited[i]);
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
