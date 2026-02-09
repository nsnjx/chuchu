/// Application configuration manager
/// Handles DNS, discovery, and proxy configuration (proxy logic delegated to UnifiedProxyManager)

import '../proxy/unified_proxy_manager.dart';
import '../proxy/proxy_settings.dart';

/// Application configuration manager
/// Handles DNS, discovery, and proxy configuration (proxy logic delegated to UnifiedProxyManager)
class Config {
  /// Singleton instance
  Config._internal();

  factory Config() => sharedInstance;
  static final Config sharedInstance = Config._internal();

  ProxySettings? proxySettings;

  // recommend relays config: only chuchu.app + profile relay (damus)
  List<String> recommendGeneralRelays = [
    // 'wss://relay.damus.io',、
    'wss://profiles.nostr1.com'
  ];

  List<String> recommendGroupRelays = [
    'wss://relay.chuchu.app',
  ];

  // default LNbits URL
  String defaultLnbitsUrl = 'https://lnbits.chuchu.app';
  // host config
  Map<String, String> hostConfig = {
    // "wss://relay.chuchu.app": "ws://54.183.141.200:5577",
    // "https://lnbits.chuchu.app": "http://54.183.141.200:5000",
    "wss://relay.chuchu.app": "wss://relay.chuchu.app",
    "https://lnbits.chuchu.app": "https://lnbits.chuchu.app",
  };
  final String wssHost = 'wss://relay.chuchu.app';

  Future<void> initConfig() async {
    // Config initialization logic removed
  }

  ProxySettings getProxy() {
    return proxySettings ?? ProxySettings(turnOnProxy: false);
  }

  Future<void> setProxy(ProxySettings setting) async {
    try {
      proxySettings = setting;
      
      try {
        final proxyManager = UnifiedProxyManager();
        await proxyManager.setProxy(setting.socksProxyHost, setting.socksProxyPort);
        print('🔧 Proxy settings updated and synced to unified manager');
      } catch (e) {
        print('⚠️ Failed to sync to unified manager: $e');
      }
      
    } catch (e) {
      print('⚠️ Failed to update proxy settings: $e');
      rethrow;
    }
  }
}
