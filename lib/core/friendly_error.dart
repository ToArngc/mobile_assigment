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
