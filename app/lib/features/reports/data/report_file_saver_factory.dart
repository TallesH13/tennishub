// Escolhe, na compilação, como entregar o arquivo: download no navegador
// (web) ou o salvador sem suporte (testes e outras plataformas).
export 'package:tennishub/features/reports/data/report_file_saver_stub.dart'
    if (dart.library.js_interop) 'package:tennishub/features/reports/data/report_file_saver_web.dart';
