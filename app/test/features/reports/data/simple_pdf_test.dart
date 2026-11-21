import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/reports/data/simple_pdf.dart';

String pdfText(List<String> lines) => ascii.decode(buildSimplePdf(lines));

void main() {
  group('buildSimplePdf', () {
    test('começa com o cabeçalho e termina com o marcador de fim do PDF', () {
      final text = pdfText(['Relatório de locações']);

      expect(text.startsWith('%PDF-1.4'), isTrue);
      expect(text.trimRight().endsWith('%%EOF'), isTrue);
    });

    test('escreve as linhas sem acento', () {
      final text = pdfText(['Relatório de locações', 'Período: 01/11/2026']);

      expect(text, contains('(Relatorio de locacoes) Tj'));
      expect(text, contains('(Periodo: 01/11/2026) Tj'));
    });

    test('escapa parênteses e barras do texto', () {
      final text = pdfText([r'Quadra (coberta) \ 1']);

      expect(text, contains(r'(Quadra \(coberta\) \\ 1) Tj'));
    });

    test('troca caracteres fora do ASCII por interrogação', () {
      final text = pdfText(['preço € 10']);

      expect(text, contains('(preco ? 10) Tj'));
    });

    test('a tabela de referências aponta para o início de cada objeto', () {
      final text = pdfText(['Linha 1', 'Linha 2']);

      final xrefStart = int.parse(
        RegExp(r'startxref\n(\d+)\n').firstMatch(text)!.group(1)!,
      );
      expect(text.substring(xrefStart).startsWith('xref'), isTrue);

      final entries = RegExp(r'(\d{10}) 00000 n ')
          .allMatches(text)
          .map((m) => int.parse(m.group(1)!))
          .toList();

      expect(entries, hasLength(5));
      for (var i = 0; i < entries.length; i++) {
        expect(
          text.substring(entries[i]).startsWith('${i + 1} 0 obj'),
          isTrue,
          reason: 'objeto ${i + 1} fora do lugar',
        );
      }
    });

    test('o tamanho declarado do conteúdo bate com o conteúdo', () {
      final text = pdfText(['Linha 1', 'Linha 2']);

      final length = int.parse(
        RegExp(r'/Length (\d+)').firstMatch(text)!.group(1)!,
      );
      final content = RegExp(
        r'stream\n(.*)\nendstream',
        dotAll: true,
      ).firstMatch(text)!.group(1)!;

      expect(content.length, length);
    });

    test('limita as linhas e avisa quantas ficaram de fora', () {
      final lines = [for (var i = 1; i <= 100; i++) 'Linha $i'];

      final text = pdfText(lines);

      expect(text, contains('(Linha 53) Tj'));
      expect(text, isNot(contains('(Linha 54) Tj')));
      expect(text, contains('(... e mais 47 linhas) Tj'));
    });

    test('aceita nenhuma linha', () {
      final text = pdfText(const []);

      expect(text.startsWith('%PDF-1.4'), isTrue);
    });
  });
}
