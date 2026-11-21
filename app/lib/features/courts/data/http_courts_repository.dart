import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/json_reader.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';
import 'package:tennishub/features/courts/domain/courts_repository.dart';

/// [CourtsRepository] ligado à API. Contrato em `docs/api.md`.
class HttpCourtsRepository implements CourtsRepository {
  HttpCourtsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Court>> listCourts() async => _courts(await _api.get('/courts'));

  @override
  Future<DayAvailability> fetchAvailability(DateTime day) async {
    final data = await _api.get(
      '/availability',
      query: {'date': formatApiDate(day)},
    );
    return parseResponse(() => DayAvailability.fromJson(asJsonMap(data)));
  }

  @override
  Future<List<Court>> listAllCourts() async =>
      _courts(await _api.get('/owner/courts'));

  @override
  Future<Court> createCourt(CourtInput input) async {
    return _court(await _api.post('/owner/courts', body: input.toJson()));
  }

  @override
  Future<Court> updateCourt(String id, CourtInput input) async {
    return _court(await _api.put('/owner/courts/$id', body: input.toJson()));
  }

  List<Court> _courts(Object? data) => parseResponse(
    () => [
      for (final court in asJsonMap(data).readList('courts'))
        Court.fromJson(court),
    ],
  );

  Court _court(Object? data) =>
      parseResponse(() => Court.fromJson(asJsonMap(data).readMap('court')));
}

/// [CourtScheduleRepository] ligado à API. Contrato em `docs/api.md`.
class HttpCourtScheduleRepository implements CourtScheduleRepository {
  HttpCourtScheduleRepository(this._api);

  final ApiClient _api;

  @override
  Future<OpeningHours?> fetchOpeningHours(String courtId) async {
    final data = await _api.get('/owner/courts/$courtId/opening-hours');
    return parseResponse(() {
      final json = asJsonMap(data);
      return json['openingHours'] == null
          ? null
          : OpeningHours.fromJson(json.readMap('openingHours'));
    });
  }

  @override
  Future<OpeningHoursUpdate> saveOpeningHours(
    String courtId,
    OpeningHours hours,
  ) async {
    final data = await _api.post(
      '/owner/courts/$courtId/opening-hours',
      body: hours.toJson(),
    );
    return parseResponse(() => OpeningHoursUpdate.fromJson(asJsonMap(data)));
  }

  @override
  Future<List<ScheduleBlock>> listBlocks(String courtId) async {
    final data = await _api.get('/owner/courts/$courtId/blocks');
    return parseResponse(
      () => [
        for (final block in asJsonMap(data).readList('blocks'))
          ScheduleBlock.fromJson(block),
      ],
    );
  }

  @override
  Future<ScheduleBlock> createBlock(
    String courtId,
    ScheduleBlockInput input,
  ) async {
    final data = await _api.post(
      '/owner/courts/$courtId/blocks',
      body: input.toJson(),
    );
    return parseResponse(
      () => ScheduleBlock.fromJson(asJsonMap(data).readMap('block')),
    );
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    await _api.delete('/owner/blocks/$blockId');
  }
}
