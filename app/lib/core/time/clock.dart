import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio do app: devolve o instante atual.
///
/// As telas leem a data por aqui em vez de chamar `DateTime.now()`, para que
/// os testes possam fixar o "hoje".
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
