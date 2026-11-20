import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/formatting/br_date_input_formatter.dart';

String applyMask(String typed) {
  const formatter = BrDateInputFormatter();
  final result = formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: typed),
  );
  return result.text;
}

void main() {
  group('BrDateInputFormatter', () {
    test('insere as barras enquanto o usuário digita', () {
      expect(applyMask('2'), '2');
      expect(applyMask('20'), '20');
      expect(applyMask('201'), '20/1');
      expect(applyMask('20112'), '20/11/2');
      expect(applyMask('20112026'), '20/11/2026');
    });

    test('mantém o texto que já está com as barras', () {
      expect(applyMask('20/11/2026'), '20/11/2026');
    });

    test('descarta o que não é dígito', () {
      expect(applyMask('2a0-1b1.2026'), '20/11/2026');
    });

    test('limita a 8 dígitos', () {
      expect(applyMask('201120269999'), '20/11/2026');
    });

    test('deixa o cursor no fim do texto', () {
      const formatter = BrDateInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '2011'),
      );

      expect(result.selection.baseOffset, result.text.length);
    });
  });
}
