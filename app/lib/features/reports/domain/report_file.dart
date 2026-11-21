import 'dart:typed_data';

/// Arquivo do relatório pronto para ser baixado (PDF).
final class ReportFile {
  const ReportFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
