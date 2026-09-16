/// Error thrown for any non-2xx backend response after decoding the server's
/// `{"error":{"code","message"}}` envelope (spec §8).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isPaymentRequired => statusCode == 402;
  bool get isRateLimited => statusCode == 429;
  bool get isValidation =>
      statusCode == 400 || statusCode == 422 || statusCode == 409;
  bool get isNetwork => statusCode == 0 && code == 'network_error';
  bool get isTimeout => statusCode == 0 && code == 'timeout';

  /// Human-readable message safe to show in a SnackBar (strips raw codes).
  String get userMessage {
    if (message.trim().isNotEmpty) return message;
    return switch (statusCode) {
      400 => 'Invalid data. Please check the fields and try again.',
      401 => 'Session expired. Please sign in again.',
      402 => 'Subscription required. Please renew to continue.',
      403 => 'You do not have permission for this action.',
      404 => 'Record not found. It may have been deleted.',
      405 => 'Operation not supported.',
      409 => 'This conflicts with existing data.',
      422 => 'This action is not allowed in the current state.',
      429 => 'Too many attempts. Please wait a minute and try again.',
      0 => 'Could not reach the server. Check your connection.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
