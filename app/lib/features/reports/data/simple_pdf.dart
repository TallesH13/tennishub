import 'dart:convert';
import 'dart:typed_data';

import 'package:tennishub/core/formatting/text_normalizer.dart';

/// Gera um PDF de uma página só com linhas de texto.
///
/// Serve à implementação falsa do relatório, para o botão "Exportar PDF"
/// baixar um arquivo que abre de verdade. O PDF real vem da API (issue #20).
///
/// O texto sai sem acentos, porque a fonte padrão do PDF só cobre ASCII.
/// Linhas além do que cabe na página são trocadas por um aviso.
Uint8List buildSimplePdf(List<String> lines) {
  const maxLines = 54;

  final visible = lines.length <= maxLines
      ? lines
      : [
          ...lines.take(maxLines - 1),
          '... e mais ${lines.length - (maxLines - 1)} linhas',
        ];

  final content = StringBuffer('BT\n/F1 10 Tf\n14 TL\n50 800 Td\n');
  for (final line in visible) {
    content.write('(${_escape(line)}) Tj\nT*\n');
  }
  content.write('ET');
  final contentText = content.toString();

  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${contentText.length} >>\nstream\n$contentText\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];

  // Tudo é ASCII, então o tamanho do texto é o tamanho em bytes.
  final document = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(document.length);
    document.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }

  final xrefOffset = document.length;
  document
    ..write('xref\n0 ${objects.length + 1}\n')
    ..write('0000000000 65535 f \n');
  for (final offset in offsets) {
    document.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  document
    ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');

  return Uint8List.fromList(ascii.encode(document.toString()));
}

String _escape(String line) {
  final plain = TextNormalizer.removeAccents(line);
  final buffer = StringBuffer();
  for (final rune in plain.runes) {
    if (rune == 0x5C || rune == 0x28 || rune == 0x29) {
      buffer.write('\\');
    }
    buffer.writeCharCode(rune >= 0x20 && rune < 0x7F ? rune : 0x3F);
  }
  return buffer.toString();
}
