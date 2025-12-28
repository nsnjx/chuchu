import 'package:chuchu/core/utils/log_utils.dart';
import 'blossom_uploader.dart';

/// Blossom server configuration model
class BlossomServerConfig {
  final String url;
  final String name;

  BlossomServerConfig({
    required this.url,
    required this.name,
  });

  @override
  String toString() => 'BlossomServerConfig(name: $name, url: $url)';
}

/// Blossom server manager
/// Manages multiple Blossom servers and automatically switches to the next server on upload failure
class BlossomServerManager {
  static final BlossomServerManager shared = BlossomServerManager._internal();
  BlossomServerManager._internal();

  /// Default Blossom server list
  static final List<BlossomServerConfig> _defaultServers = [
    BlossomServerConfig(
      url: 'https://blossom.lostr.space',
      name: 'blossom.lostr.space',
    ),
    BlossomServerConfig(
      url: 'https://blossom.band',
      name: 'blossom.band',
    ),
  ];

  /// Custom server list (user-added)
  final List<BlossomServerConfig> _customServers = [];

  /// Get all available server list (default + custom)
  List<BlossomServerConfig> get allServers => [
        ..._defaultServers,
        ..._customServers,
      ];

  /// Add custom server
  void addCustomServer(String url, {String? name}) {
    final serverName = name ?? _extractServerName(url);
    if (!_customServers.any((s) => s.url == url)) {
      _customServers.add(BlossomServerConfig(url: url, name: serverName));
      LogUtils.d(() => '[BlossomServerManager] Added custom server: $url');
    }
  }

  /// Remove custom server
  void removeCustomServer(String url) {
    _customServers.removeWhere((s) => s.url == url);
    LogUtils.d(() => '[BlossomServerManager] Removed custom server: $url');
  }

  /// Clear all custom servers
  void clearCustomServers() {
    _customServers.clear();
    LogUtils.d(() => '[BlossomServerManager] Cleared all custom servers');
  }

  /// Extract server name from URL
  String _extractServerName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  /// Upload file, automatically switch servers until success or all servers fail
  ///
  /// [filePath] File path
  /// [fileName] File name (optional)
  /// [onProgress] Progress callback
  /// [preferredServer] Preferred server URL (if specified, this server will be tried first)
  ///
  /// Returns the URL after successful upload, or null if all servers fail
  Future<String?> uploadWithAutoSwitch({
    required String filePath,
    String? fileName,
    Function(double progress)? onProgress,
    String? preferredServer,
  }) async {
    final candidates = _getUploadCandidates(preferredServer);

    if (candidates.isEmpty) {
      LogUtils.e(() => '[BlossomServerManager] No available servers');
      return null;
    }

    String? lastError;
    int serverIndex = 0;
    for (final server in candidates) {
      serverIndex++;
      try {
        LogUtils.d(() => '[BlossomServerManager] Trying server: ${server.name} (${server.url})');
        print('[BlossomServerManager] 🔄 Attempting server $serverIndex/${candidates.length}: ${server.name} (${server.url})');

        final url = await BolssomUploader.upload(
          server.url,
          filePath,
          fileName: fileName,
          onProgress: onProgress,
        );

        if (url != null && url.isNotEmpty) {
          LogUtils.i(() => '[BlossomServerManager] Upload success using server: ${server.name} (${server.url})');
          print('[BlossomServerManager] ✅ Upload success using server: ${server.name} (${server.url})');
          print('[BlossomServerManager] 📎 Uploaded URL: $url');
          return url;
        } else {
          // Treat empty URL as failure
          lastError = 'Empty URL returned from ${server.name}';
          LogUtils.w(() => '[BlossomServerManager] Upload failed: ${server.name} - $lastError');
          print('[BlossomServerManager] ❌ Server ${server.name} failed: Empty URL returned');
          continue; // Continue to next server
        }
      } catch (e, stackTrace) {
        // Catch exception, log error, continue to next server
        lastError = e.toString();
        LogUtils.w(() => '[BlossomServerManager] Upload failed: ${server.name} - $lastError');
        print('[BlossomServerManager] ❌ Server ${server.name} failed: $lastError');
        LogUtils.d(() => '[BlossomServerManager] Stack trace: $stackTrace');
        // Continue loop, try next server
      }
    }

    // All servers failed
    LogUtils.e(() => '[BlossomServerManager] All servers failed. Last error: $lastError');
    print('[BlossomServerManager] ❌ All $serverIndex servers failed. Last error: $lastError');
    return null;
  }

  /// Get upload candidate server list
  /// If preferredServer is specified, it will be placed at the front of the list
  List<BlossomServerConfig> _getUploadCandidates(String? preferredServer) {
    final all = allServers;

    if (preferredServer == null || preferredServer.isEmpty) {
      return all;
    }

    // Find preferred server
    final preferred = all.firstWhere(
      (s) => s.url == preferredServer,
      orElse: () => BlossomServerConfig(
        url: preferredServer,
        name: _extractServerName(preferredServer),
      ),
    );

    // Place preferred server at the front
    final others = all.where((s) => s.url != preferredServer).toList();
    return [preferred, ...others];
  }

  /// Get server count
  int get serverCount => allServers.length;

  /// Get default server count
  int get defaultServerCount => _defaultServers.length;

  /// Get custom server count
  int get customServerCount => _customServers.length;
}

