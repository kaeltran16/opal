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

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final metrics = (json['metrics'] as Map<String, dynamic>?) ?? const {};
    return HealthDay(
      activeEnergyKcal: _metricValue(metrics['activeEnergy']),
      steps: _metricValue(metrics['steps']),
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
