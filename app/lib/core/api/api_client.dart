import "package:dio/dio.dart";
import "api_exception.dart";

/// Thin dio wrapper for the Cinnamon Trace backend.
///
/// Base URL is injected via --dart-define=API_BASE_URL=... and defaults to the
/// local dev backend. On an Android emulator use http://10.0.2.2:3100/v1.
class ApiClient {
  ApiClient({String? baseUrl, String? Function()? tokenProvider})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? activeBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            contentType: "application/json",
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.baseUrl = activeBaseUrl;
          final token = tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers["Authorization"] = "Bearer $token";
          }
          handler.next(options);
        },
        onError: (e, handler) {
          handler.reject(e);
        },
      ),
    );
  }

  static const String defaultBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "https://api-cinnamon.viduwa.dev/v1",
  );

  static String activeBaseUrl = defaultBaseUrl;

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String url) {
    final clean = url.trim().endsWith("/")
        ? url.trim().substring(0, url.trim().length - 1)
        : url.trim();
    _dio.options.baseUrl = clean;
    activeBaseUrl = clean;
  }

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() => _dio.get(path, queryParameters: query));
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    return _send(
      () => _dio.post(path, data: body, options: Options(headers: headers)),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() => _dio.put(path, data: body));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => _dio.delete(path));
  }

  Future<dynamic> _send(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (data is Map && data["error"] is Map) {
      final err = data["error"] as Map;
      return ApiException(
        code: (err["code"] ?? "UNKNOWN").toString(),
        message: (err["message"] ?? "Something went wrong").toString(),
        status: e.response?.statusCode,
        details: err["details"],
      );
    }
    // class-validator style: { message: [...], error, statusCode }
    if (data is Map && data["message"] is List) {
      return ApiException(
        code: "VALIDATION",
        message: (data["message"] as List).join("; "),
        status: e.response?.statusCode,
      );
    }
    return ApiException(
      code: e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout
          ? "TIMEOUT"
          : "NETWORK",
      message: e.message ?? "Network error",
      status: e.response?.statusCode,
    );
  }
}
