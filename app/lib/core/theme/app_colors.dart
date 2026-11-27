import 'package:material_ui/material_ui.dart';

/// Paleta do TennisHub.
///
/// Nas telas, prefira as cores do tema (`Theme.of(context).colorScheme`).
/// Use estas constantes direto só para estados que o tema não cobre,
/// como a grade de horários.
abstract final class AppColors {
  /// Verde de quadra: cor-base de onde o tema deriva as demais.
  static const Color courtGreen = Color(0xFF1F6F43);

  /// Amarelo da bola, para destaques pontuais.
  static const Color ballYellow = Color(0xFFD7E84A);

  /// Fundo das páginas.
  static const Color background = Color(0xFFF7F8F6);

  /// Horário livre na grade de horários.
  static const Color slotAvailable = Color(0xFFDDF2E3);

  /// Horário ocupado (desabilitado) na grade de horários.
  static const Color slotUnavailable = Color(0xFFE6E6E6);

  /// Fundo de avisos de atenção (ex.: muitas tentativas, realocar).
  static const Color warningContainer = Color(0xFFFFDF9E);

  /// Texto e ícone sobre [warningContainer].
  static const Color onWarningContainer = Color(0xFF4D3700);
}
