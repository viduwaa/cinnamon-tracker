/// Typed API error mirroring the backend envelope:
/// { error: { code, message, details? } }
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.status,
    this.details,
  });

  final String code;
  final String message;
  final int? status;
  final dynamic details;

  @override
  String toString() => "ApiException($code, $status): $message";
}
