import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiResponse<T> {
  ApiResponse({
    required this.statusCode,
    required this.data,
    this.message,
  });

  final int statusCode;
  final T? data;
  final String? message;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.instance.baseUrl;

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token?.isNotEmpty ?? false) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? token,
    T Function(dynamic json)? parser,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );

    final response = await _client
        .get(uri, headers: _headers(token: token))
        .timeout(AppConfig.instance.apiTimeout);

    return _parseResponse<T>(response, parser: parser);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    T Function(dynamic json)? parser,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: _headers(token: token),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(AppConfig.instance.apiTimeout);

    return _parseResponse<T>(response, parser: parser);
  }

  ApiResponse<T> _parseResponse<T>(http.Response response, {T Function(dynamic json)? parser}) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : decoded is List
            ? decoded
            : decoded;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final parsed = parser == null ? payload as T? : parser(payload);
      return ApiResponse<T>(
        statusCode: response.statusCode,
        data: parsed,
        message: 'Request succeeded',
      );
    }

    final errorMessage = payload is Map<String, dynamic>
        ? payload['message']?.toString() ?? 'Request failed'
        : response.reasonPhrase ?? 'Request failed';

    throw ApiException(response.statusCode, errorMessage);
  }
}
