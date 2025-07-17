import 'package:flutter/foundation.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

/// A class to handle crash reporting in Flutter applications.
///
/// This class provides methods to record Flutter errors and exceptions
/// and sends them to the native Nativebrik SDK for tracking.
///
/// reference: https://docs.nativebrik.com/reference/flutter/nativebrikcrashreport
///
/// Usage:
/// ```dart
/// // Set up global error handling
/// FlutterError.onError = (errorDetails) {
///   NativebrikCrashReport.instance.recordFlutterError(errorDetails);
/// };
///
/// // Set up platform dispatcher error handling
/// PlatformDispatcher.instance.onError = (error, stack) {
///   NativebrikCrashReport.instance.recordPlatformError(error, stack);
///   return true;
/// };
/// ```
class NativebrikCrashReport {
  static final NativebrikCrashReport _instance = NativebrikCrashReport._();

  /// The singleton instance of [NativebrikCrashReport].
  static NativebrikCrashReport get instance => _instance;

  NativebrikCrashReport._();

  /// Creates a new instance of [NativebrikCrashReport].
  ///
  /// In most cases, you should use [NativebrikCrashReport.instance] instead.
  factory NativebrikCrashReport() => _instance;

  /// Records a Flutter error for crash reporting.
  ///
  /// This method takes a [FlutterErrorDetails] object, extracts the relevant
  /// information, and sends it to the native implementation for tracking.
  Future<void> recordFlutterError(FlutterErrorDetails errorDetails) async {
    try {
      final Map<String, dynamic> errorData = {
        'exception': errorDetails.exception.toString(),
        'stack': errorDetails.stack?.toString() ?? '',
        'library': errorDetails.library ?? 'flutter',
        'context': errorDetails.context?.toString() ?? '',
        'summary': errorDetails.summary.toString(),
      };

      await NativebrikBridgePlatform.instance.recordCrash(errorData);
    } catch (e) {
      // Silently handle any errors in the crash reporting itself
      // to avoid causing additional crashes
      debugPrint('Error recording crash: $e');
    }
  }

  /// Records a platform error and stack trace for crash reporting.
  ///
  /// This is a convenience method that can be used when you have an error
  Future<void> recordPlatformError(Object error, StackTrace stackTrace) async {
    try {
      final Map<String, dynamic> errorData = {
        'exception': error.toString(),
        'stack': stackTrace.toString(),
        'library': 'flutter',
        'context': '',
        'summary': error.toString(),
      };

      await NativebrikBridgePlatform.instance.recordCrash(errorData);
    } catch (e) {
      // Silently handle any errors in the crash reporting itself
      debugPrint('Error recording crash: $e');
    }
  }
}
