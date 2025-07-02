import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

/// A class to handle NativebrikUser.
///
/// Usage:
/// ```dart
/// // Set Custom User Properties
/// NativebrikUser.instance.setProperties({
///   'prefecture': 'Tokyo',
///   'environment': const bool.fromEnvironment('dart.vm.product')
///       ? 'production'
///       : 'development',
/// });
/// ```
class NativebrikUser {
  static final NativebrikUser _instance = NativebrikUser._();

  /// The singleton instance of [NativebrikUser].
  static NativebrikUser get instance => _instance;

  /// Private constructor for singleton pattern.
  NativebrikUser._();

  /// Creates a new instance of [NativebrikUser].
  ///
  /// In most cases, you should use [NativebrikUser.instance] instead.
  factory NativebrikUser() => _instance;

  /// Retrieves the current user ID.
  ///
  /// Returns a [Future] that completes with the user ID as a [String],
  /// or `null` if no user ID is set.
  Future<String?> getId() async {
    return await NativebrikBridgePlatform.instance.getUserId();
  }

  /// Sets user properties for the current user.
  ///
  /// The [properties] parameter is a map of key-value pairs where both
  /// keys and values are [String]s.
  ///
  /// Returns a [Future] that completes when the properties have been set.
  Future<void> setProperties(Map<String, dynamic> properties) async {
    await NativebrikBridgePlatform.instance.setUserProperties(properties);
  }

  /// Retrieves the current user's properties.
  ///
  /// Returns a [Future] that completes with a [Map] of user properties,
  /// where both keys and values are [String]s. Returns `null` if no
  /// properties are set or if the user is not identified.
  Future<Map<String, String>?> getProperties() async {
    return await NativebrikBridgePlatform.instance.getUserProperties();
  }
}
