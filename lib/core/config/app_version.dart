import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  static PackageInfo? _packageInfo;
  static String? _cachedVersion;

  static Future<String> getVersion() async {
    if (_cachedVersion != null) {
      return _cachedVersion!;
    }

    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      _cachedVersion = _packageInfo!.version;
      return _cachedVersion!;
    } catch (e) {
      return '0.0.0';
    }
  }

  static Future<String> getBuildNumber() async {
    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      return _packageInfo!.buildNumber;
    } catch (e) {
      return '0';
    }
  }

  static Future<String> getFullVersion() async {
    final version = await getVersion();
    final buildNumber = await getBuildNumber();
    return '$version+$buildNumber';
  }

  static Future<String> getDisplayVersion() async {
    final version = await getVersion();
    return 'Version $version';
  }
}

