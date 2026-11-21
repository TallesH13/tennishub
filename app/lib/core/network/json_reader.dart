import 'package:tennishub/core/network/api_exception.dart';

/// Objeto JSON já decodificado.
typedef JsonMap = Map<String, Object?>;

/// Garante que [value] é um objeto JSON.
JsonMap asJsonMap(Object? value, {String context = 'resposta'}) {
  if (value is JsonMap) {
    return value;
  }
  throw FormatException('Esperado um objeto em "$context".');
}

/// Executa a leitura de uma resposta e converte erros de formato em
/// [UnexpectedResponseException].
T parseResponse<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException catch (error) {
    throw UnexpectedResponseException(error.message);
  }
}

/// Converte uma data `AAAA-MM-DD` da API em [DateTime] local (sem hora).
DateTime parseApiDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Data inválida: "$value".');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Formata o dia de [date] como `AAAA-MM-DD`, o formato de data da API.
String formatApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Formata um instante para a API (ISO 8601 em UTC).
String formatApiDateTime(DateTime dateTime) =>
    dateTime.toUtc().toIso8601String();

/// Leitura tipada dos campos de um objeto JSON.
///
/// Cada método lança [FormatException] dizendo qual campo veio errado.
extension JsonMapReader on JsonMap {
  String readString(String key) {
    final value = this[key];
    if (value is String) {
      return value;
    }
    throw _invalid(key, 'texto');
  }

  String? readOptionalString(String key) {
    final value = this[key];
    if (value == null || value is String) {
      return value as String?;
    }
    throw _invalid(key, 'texto');
  }

  int readInt(String key) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw _invalid(key, 'número inteiro');
  }

  int? readOptionalInt(String key) => this[key] == null ? null : readInt(key);

  bool readBool(String key, {bool fallback = false}) {
    final value = this[key];
    if (value == null) {
      return fallback;
    }
    if (value is bool) {
      return value;
    }
    throw _invalid(key, 'verdadeiro/falso');
  }

  /// Identificador: a API pode mandar número ou texto; o app usa texto.
  String readId(String key) {
    final value = this[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is num) {
      return value.toInt().toString();
    }
    throw _invalid(key, 'identificador');
  }

  /// Instante ISO 8601, convertido para o horário local.
  DateTime readDateTime(String key) {
    final text = readString(key);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      throw _invalid(key, 'data e hora');
    }
    return parsed.toLocal();
  }

  DateTime? readOptionalDateTime(String key) =>
      this[key] == null ? null : readDateTime(key);

  /// Data `AAAA-MM-DD`, sem hora.
  DateTime readDate(String key) => parseApiDate(readString(key));

  DateTime? readOptionalDate(String key) =>
      this[key] == null ? null : readDate(key);

  JsonMap readMap(String key) => asJsonMap(this[key], context: key);

  List<JsonMap> readList(String key) {
    final value = this[key];
    if (value is List<Object?>) {
      return [for (final item in value) asJsonMap(item, context: key)];
    }
    throw _invalid(key, 'lista');
  }

  FormatException _invalid(String key, String expected) => FormatException(
    'Campo "$key" ausente ou inválido (esperado: $expected).',
  );
}
