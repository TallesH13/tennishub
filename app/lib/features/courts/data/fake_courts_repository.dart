import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';
import 'package:tennishub/features/courts/domain/courts_repository.dart';

/// [CourtsRepository] em memória, sobre o [FakeBackend].
class FakeCourtsRepository implements CourtsRepository {
  FakeCourtsRepository(this._backend);

  final FakeBackend _backend;

  @override
  Future<List<Court>> listCourts() async {
    await _backend.wait();
    return _backend.courts();
  }

  @override
  Future<DayAvailability> fetchAvailability(DateTime day) async {
    await _backend.wait();
    return _backend.availability(day);
  }

  @override
  Future<List<Court>> listAllCourts() async {
    await _backend.wait();
    return _backend.courts(includeUnavailable: true);
  }

  @override
  Future<Court> createCourt(CourtInput input) async {
    await _backend.wait();
    return _backend.createCourt(input);
  }

  @override
  Future<Court> updateCourt(String id, CourtInput input) async {
    await _backend.wait();
    return _backend.updateCourt(id, input);
  }
}

/// [CourtScheduleRepository] em memória, sobre o [FakeBackend].
class FakeCourtScheduleRepository implements CourtScheduleRepository {
  FakeCourtScheduleRepository(this._backend, {DateTime Function()? today})
    : _today = today ?? DateTime.now;

  final FakeBackend _backend;
  final DateTime Function() _today;

  @override
  Future<OpeningHours?> fetchOpeningHours(String courtId) async {
    await _backend.wait();
    return _backend.openingHoursOn(courtId, _today());
  }

  @override
  Future<OpeningHoursUpdate> saveOpeningHours(
    String courtId,
    OpeningHours hours,
  ) async {
    await _backend.wait();
    return _backend.saveOpeningHours(courtId, hours);
  }

  @override
  Future<List<ScheduleBlock>> listBlocks(String courtId) async {
    await _backend.wait();
    return _backend.blocks(courtId);
  }

  @override
  Future<ScheduleBlock> createBlock(
    String courtId,
    ScheduleBlockInput input,
  ) async {
    await _backend.wait();
    return _backend.createBlock(courtId, input);
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    await _backend.wait();
    _backend.deleteBlock(blockId);
  }
}
