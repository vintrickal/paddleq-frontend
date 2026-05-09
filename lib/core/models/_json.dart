/// Tiny JSON-parsing helpers shared across DTOs.
///
/// All datetimes from the PaddleQ API are UTC ISO 8601. We parse them as
/// UTC `DateTime` and let the UI layer convert to local for display.
library;

DateTime parseUtc(Object? value) {
  if (value is! String) {
    throw FormatException('Expected ISO 8601 datetime string, got: $value');
  }
  return DateTime.parse(value).toUtc();
}

DateTime? parseUtcOrNull(Object? value) {
  if (value == null) return null;
  return parseUtc(value);
}

double parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Expected number, got: $value');
}
