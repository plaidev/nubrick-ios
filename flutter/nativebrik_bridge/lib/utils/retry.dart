import 'dart:async';

/// Attempts to execute [fn] up to [retries] times with a [delay] between attempts.
///
/// Returns the result of [fn] if successful, otherwise throws the last error.
Future<bool> retryUntilTrue({
  required Future<bool> Function() fn,
  required int retries,
  required Duration delay,
}) async {
  int attempts = 0;

  while (true) {
    try {
      final result = await fn();
      if (result) {
        return true;
      }

      attempts++;

      // If we've reached max retries, return false
      if (attempts >= retries) {
        return false;
      }

      // Wait before the next retry
      await Future.delayed(delay);
    } catch (e) {
      attempts++;

      // If we've reached max retries, rethrow
      if (attempts >= retries) {
        return false;
      }

      // Wait before the next retry
      await Future.delayed(delay);
    }
  }
}
