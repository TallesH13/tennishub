/// Tratamento de texto para buscas e para saídas que só aceitam ASCII.
abstract final class TextNormalizer {
  static const String _withAccent =
      'áàâãäéèêëíìîïóòôõöúùûüçñ'
      'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  static const String _withoutAccent =
      'aaaaaeeeeiiiiooooouuuucn'
      'AAAAAEEEEIIIIOOOOOUUUUCN';

  /// Troca letras acentuadas pelas equivalentes sem acento (`ç` vira `c`).
  static String removeAccents(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final index = _withAccent.indexOf(char);
      buffer.write(index == -1 ? char : _withoutAccent[index]);
    }
    return buffer.toString();
  }

  /// Texto para comparar em buscas: sem acento, em minúsculas e sem espaços
  /// nas pontas.
  static String forSearch(String text) {
    return removeAccents(text).toLowerCase().trim();
  }
}
