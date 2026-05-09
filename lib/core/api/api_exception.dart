/// Thrown by [ApiClient] for any non-2xx response or transport failure.
///
/// The PaddleQ backend returns errors as either:
///   * `{ "message": "..." }` — written to be user-readable, surface directly.
///   * ASP.NET Core `ValidationProblemDetails` for 400s — field-level errors
///     are stashed in [validationErrors] keyed by field name.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.validationErrors,
    this.cause,
  });

  /// HTTP status code, or `0` for transport failures (DNS, network down, etc).
  final int statusCode;

  /// Best human-readable message available — either the backend's `message`
  /// field, the ProblemDetails `title`, or a generic fallback.
  final String message;

  /// Field-level validation errors from a 400 ValidationProblemDetails
  /// response. `null` for non-400s.
  final Map<String, List<String>>? validationErrors;

  /// Underlying cause for transport errors (SocketException, etc).
  final Object? cause;

  bool get isNetwork => statusCode == 0;
  bool get isBadRequest => statusCode == 400;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServer => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
