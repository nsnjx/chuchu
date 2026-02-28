import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web implementation that registers the path_provider channel with [Registrar].
/// path_provider has no web implementation; this shim returns virtual paths so
/// callers (e.g. wallet, Isar) do not get MissingPluginException.
class PathProviderWebShimPlugin {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'plugins.flutter.io/path_provider',
      const StandardMethodCodec(),
      registrar,
    );
    channel.setMethodCallHandler((MethodCall call) async {
      const virtualPath = '/web_app';
      switch (call.method) {
        case 'getApplicationSupportDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getTemporaryDirectory':
        case 'getLibraryDirectory':
          return virtualPath;
        default:
          return null;
      }
    });
  }
}
