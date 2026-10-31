import 'package:flutter/services.dart';

/// Keeps the Android process active while an MQTT connection is in use.
///
/// Other platforms safely ignore these calls. Android implements the channel
/// with a foreground connected-device service.
abstract final class BackgroundConnectionKeeper {
  static const _channel = MethodChannel(
    'com.astraval.iotroot/background_connection',
  );

  static Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('start');
    } on MissingPluginException {
      // The keeper is Android-only and is also absent in unit tests.
    } on PlatformException {
      // MQTT must still work if a device policy refuses foreground services.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // The keeper is Android-only and is also absent in unit tests.
    } on PlatformException {
      // The native service is already unavailable or stopped.
    }
  }
}
