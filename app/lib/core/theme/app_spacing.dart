/// Espaçamentos padrão do layout, em múltiplos de 4.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Arredondamento padrão de cards, campos e botões.
abstract final class AppRadius {
  static const double md = 8;
}

/// Larguras de referência do layout responsivo, pensado para desktop (RNF06).
abstract final class AppBreakpoints {
  /// Largura máxima do conteúdo, para não esticar em monitores grandes.
  static const double maxContentWidth = 1200;

  /// Abaixo desta largura, as margens laterais diminuem.
  static const double compact = 600;
}
