/// Maps a raw exception onto something a rider can act on, so screens never
/// print a Dart exception verbatim. Extracted from the login screen, which
/// keeps its own credential-specific branch on top of this.
String friendlyErrorMessage(Object? error, {required String fallback}) {
  final message = error.toString().toLowerCase();
  if (message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network') ||
      message.contains('timed out') ||
      message.contains('status 0')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  if (message.contains('invalid or expired session') ||
      message.contains('authorization header')) {
    return 'Your session has expired. Please log in again.';
  }
  return fallback;
}
