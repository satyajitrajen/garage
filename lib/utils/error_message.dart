import '../data/api/api_exception.dart';

/// Text to show the user for a caught error: the server's message for API
/// errors (capitalised), otherwise the exception text without Dart's
/// "Exception: " prefix.
String errorMessage(Object error) {
  final text = error is ApiException
      ? error.userMessage
      : error.toString().replaceFirst('Exception: ', '');
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
