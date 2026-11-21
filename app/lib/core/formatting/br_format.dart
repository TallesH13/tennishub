/// Formatação de datas, valores e telefones no padrão brasileiro.
abstract final class BrFormat {
  static final RegExp _dateText = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');

  /// Data no formato `dd/mm/aaaa`.
  static String date(DateTime value) {
    return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/'
        '${value.year.toString().padLeft(4, '0')}';
  }

  /// Data e hora no formato `dd/mm/aaaa hh:mm`.
  static String dateTime(DateTime value) {
    return '${date(value)} ${_twoDigits(value.hour)}:'
        '${_twoDigits(value.minute)}';
  }

  /// Lê uma data digitada como `dd/mm/aaaa`.
  ///
  /// Devolve `null` quando o texto está incompleto ou a data não existe
  /// (por exemplo, `31/02/2026`).
  static DateTime? parseDate(String text) {
    final match = _dateText.firstMatch(text.trim());
    if (match == null) {
      return null;
    }

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);

    final isRealDate =
        parsed.year == year && parsed.month == month && parsed.day == day;
    return isRealDate ? parsed : null;
  }

  /// Valor em reais a partir de centavos, como `R$ 1.234,50`.
  static String money(int cents) {
    final reais = cents ~/ 100;
    final centavos = cents % 100;
    return 'R\$ ${_withThousandsSeparator(reais)},${_twoDigits(centavos)}';
  }

  /// Telefone brasileiro a partir dos dígitos, como `(31) 99999-0000`.
  ///
  /// Se não tiver 10 ou 11 dígitos, devolve o texto como veio.
  static String phone(String digits) {
    if (digits.length != 10 && digits.length != 11) {
      return digits;
    }

    final areaCode = digits.substring(0, 2);
    final prefixLength = digits.length - 6;
    final prefix = digits.substring(2, 2 + prefixLength);
    final suffix = digits.substring(2 + prefixLength);
    return '($areaCode) $prefix-$suffix';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String _withThousandsSeparator(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}
