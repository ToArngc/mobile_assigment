class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
}

const int onTimeThresholdMinutes = 5;

final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

final RegExp usernamePattern = RegExp(r'^[A-Za-z0-9 ._-]+$');
