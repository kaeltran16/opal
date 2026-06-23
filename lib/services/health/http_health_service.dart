import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pal/http_pal_service.dart' show PalException, TokenProvider;
import 'health_service.dart';

/// Real [HealthService]: reads today's metrics from the droplet proxy (which the
/// iOS Shortcut populates). Shares the proxy's base URL + device-token plumbing
/// with [HttpPalService]. Interface-compatible with [MockHealthService].
class HttpHealthService implements HealthService {
  HttpHealthService({
    required String baseUrl,
    required http.Client httpClient,
    required this.tokens,
    this.timeout = const Duration(seconds: 30),
  })  : _base = Uri.parse(baseUrl),
        _http = httpClient;

  final Uri _base;
  final http.Client _http;
  final TokenProvider tokens;
  final Duration timeout;

  @override
  Future<HealthDay> fetchDay(DateTime day) async {
    final query = {'date': _formatDate(day)};

    Future<http.Response> send() async {
      final token = await tokens.token();
      return _http
          .get(
            _base.replace(path: '/v1/health/day', queryParameters: query),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      // a 200 with a non-JSON / non-object body (e.g. an HTML error page);
      // normalize to PalException so callers hit the offline path.
      throw const PalException('malformed health response');
    }
    final metrics = (json['metrics'] as Map<String, dynamic>?) ?? const {};
    return HealthDay(
      activeEnergyKcal: _metricValue(metrics['activeEnergy']),
      steps: _metricValue(metrics['steps']),
    );
  }

  @override
  Future<List<HealthSleep>> fetchSleep(DateTime from, DateTime to) async {
    final query = {'from': _formatDate(from), 'to': _formatDate(to)};

    Future<http.Response> send() async {
      final token = await tokens.token();
      return _http
          .get(
            _base.replace(path: '/v1/health/sleep', queryParameters: query),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(timeout);
    }

    http.Response res;
    try {
      res = await send();
      if (res.statusCode == 401) {
        await tokens.clear();
        res = await send();
      }
    } on TimeoutException {
      throw const PalException('request timed out');
    } catch (e) {
      throw PalException('network error: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PalException('proxy returned ${res.statusCode}');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const PalException('malformed sleep response');
    }
    final nights = (json['nights'] as List?) ?? const [];
    return [
      for (final raw in nights.whereType<Map<String, dynamic>>())
        _sleepFromJson(raw)
    ];
  }

  static HealthSleep _sleepFromJson(Map<String, dynamic> j) {
    final stages = (j['stages'] as Map<String, dynamic>?) ?? const {};
    int i(Object? v) => (v as num?)?.round() ?? 0;
    return HealthSleep(
      night: DateTime.parse(j['night'] as String),
      asleepMinutes: i(j['asleepMinutes']),
      inBedMinutes: i(j['inBedMinutes']),
      bedtime: (j['bedtime'] as String?) ?? '',
      wake: (j['wake'] as String?) ?? '',
      deepMinutes: i(stages['deep']),
      remMinutes: i(stages['rem']),
      coreMinutes: i(stages['core']),
      awakeMinutes: i(stages['awake']),
      wakes: i(j['wakes']),
      sourceRef: j['sourceRef'] as String?,
    );
  }

  /// Reads `{"value": <num>}` from a metric object, rounding to int. Missing or
  /// malformed metrics default to 0.
  static int _metricValue(Object? metric) {
    if (metric is! Map<String, dynamic>) return 0;
    return (metric['value'] as num?)?.round() ?? 0;
  }

  /// Zero-padded `yyyy-MM-dd` (no `intl` dependency in this project).
  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
