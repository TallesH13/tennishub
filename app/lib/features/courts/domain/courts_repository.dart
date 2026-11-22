import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';

/// Quadras e horários livres.
///
/// Os métodos lançam `ApiException` (core/network) em caso de falha.
abstract interface class CourtsRepository {
  /// Quadras que aceitam reservas hoje (área pública).
  Future<List<Court>> listCourts();

  /// Horários de todas as quadras no dia de [day] (RF01).
  Future<DayAvailability> fetchAvailability(DateTime day);

  /// Todas as quadras, inclusive as que vão sair do sistema (painel, RF06).
  Future<List<Court>> listAllCourts();

  Future<Court> createCourt(CourtInput input);

  /// Edita uma quadra. Para removê-la, informe `unavailableFrom` (D11).
  Future<Court> updateCourt(String id, CourtInput input);
}

/// Horário de funcionamento e bloqueios das quadras (painel, RF07).
abstract interface class CourtScheduleRepository {
  /// Horário em vigor hoje, ou `null` se a quadra ainda não tem horário.
  Future<OpeningHours?> fetchOpeningHours(String courtId);

  /// Cria uma nova vigência a partir de `hours.validFrom`.
  Future<OpeningHoursUpdate> saveOpeningHours(
    String courtId,
    OpeningHours hours,
  );

  /// Bloqueios de hoje em diante.
  Future<List<ScheduleBlock>> listBlocks(String courtId);

  Future<ScheduleBlock> createBlock(String courtId, ScheduleBlockInput input);

  Future<void> deleteBlock(String blockId);
}
