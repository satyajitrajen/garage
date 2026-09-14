/// Error thrown for any non-2xx backend response after decoding the server's
/// `{"error":{"code","message"}}` envelope (spec §8).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
