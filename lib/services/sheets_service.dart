import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter/foundation.dart';

class SheetsException implements Exception {
  final String message;
  const SheetsException(this.message);
  @override
  String toString() => 'SheetsException: $message';
}

class SheetsService {
  final Dio _dio;
  final String _apiKey;

  SheetsService({required Dio dio, required String apiKey})
      : _dio = dio,
        _apiKey = apiKey;

  /// A1 notation requires single-quoting sheet names that contain spaces or
  /// special characters, e.g. `'My Sheet'!A:J`.
  String _a1Range(String sheetName, String range) {
    final needsQuoting = sheetName.contains(RegExp(r"[ '()]"));
    final quoted = needsQuoting
        ? "'${sheetName.replaceAll("'", "''")}'"
        : sheetName;
    return '$quoted!$range';
  }

  /// Builds a URI with the range already encoded in the path, so Dio doesn't
  /// double-encode it.
  Uri _buildUri(String spreadsheetId, String a1Range,
      Map<String, String> queryParams) {
    return Uri(
      scheme: 'https',
      host: 'sheets.googleapis.com',
      pathSegments: ['v4', 'spreadsheets', spreadsheetId, 'values', a1Range],
      queryParameters: {...queryParams, 'key': _apiKey},
    );
  }

  /// Fetches only column A to count data rows (lightweight freshness check).
  Future<int> getDataRowCount(RemoteSource source) async {
    final range = _a1Range(source.sheetName, 'A:A');
    final uri = _buildUri(source.spreadsheetId, range, {});
    debugPrint('SheetsService.getDataRowCount: $uri');
    final response = await _dio.getUri<Map<String, dynamic>>(uri);
    if (response.data == null) {
      throw SheetsException('getDataRowCount: response data is null for sheet "${source.sheetName}"');
    }
    final values = response.data?['values'] as List?;
    if (values == null || values.isEmpty) return 0;
    return values.length;
  }

  /// Fetches the full range and converts rows to a list of maps matching
  /// the bundled JSON structure: `[{"A": "...", "B": "...", ...}]`.
  Future<String> fetchSeasonData(RemoteSource source) async {
    final range = _a1Range(source.sheetName, source.range);
    final uri = _buildUri(source.spreadsheetId, range, {
      'valueRenderOption': 'UNFORMATTED_VALUE',
    });
    debugPrint('SheetsService.fetchSeasonData: $uri');
    final response = await _dio.getUri<Map<String, dynamic>>(uri);
    if (response.data == null) {
      throw SheetsException('fetchSeasonData: response data is null for sheet "${source.sheetName}"');
    }
    if (!response.data!.containsKey('values')) {
      throw SheetsException('fetchSeasonData: response missing "values" key for sheet "${source.sheetName}" — possible API error');
    }
    final rows = (response.data?['values'] as List?)?.cast<List>() ?? [];

    // Convert 2D array to list of {A, B, C, ...} maps (column letters as keys)
    final result = <Map<String, String>>[];
    for (final row in rows) {
      final map = <String, String>{};
      for (var col = 0; col < row.length; col++) {
        final letter = String.fromCharCode(65 + col); // A=65
        map[letter] = (row[col] ?? '').toString();
      }
      result.add(map);
    }

    return jsonEncode(result);
  }
}
