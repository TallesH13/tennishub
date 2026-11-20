import 'dart:js_interop';

import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';
import 'package:web/web.dart' as web;

/// Cria o [ReportFileSaver] do navegador: baixa o arquivo pelo próprio
/// navegador.
ReportFileSaver createReportFileSaver() => const _WebReportFileSaver();

final class _WebReportFileSaver implements ReportFileSaver {
  const _WebReportFileSaver();

  @override
  Future<void> save(ReportFile file) async {
    try {
      final blob = web.Blob(
        <JSAny>[file.bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      final url = web.URL.createObjectURL(blob);

      final link = web.HTMLAnchorElement()
        ..href = url
        ..download = file.fileName;
      web.document.body!.append(link);
      link.click();
      link.remove();

      web.URL.revokeObjectURL(url);
    } on Object {
      throw const ReportsException('Não foi possível baixar o PDF.');
    }
  }
}
