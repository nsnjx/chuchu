
import 'dart:async';

import 'package:chuchu/presentation/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';

import 'core/manager/chuchu_user_info_manager.dart';
import 'core/manager/thread_pool_manager.dart';
import 'core/utils/initialization_manager.dart';
import 'core/utils/navigator/navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/chuchu_Loading.dart';
import 'core/config/config.dart' as AppConfig;
import 'core/relayGroups/relayGroup.dart';
import 'core/relayGroups/relayGroup+info.dart';
import 'core/account/account.dart';
import 'core/account/account+profile.dart';
import 'presentation/feed/pages/feed_personal_page.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  
  try {
    await InitializationManager.instance.initialize();
  } catch (error) {
    debugPrint('The application initialization failed, but it continued to start: $error');
  }
  
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return MainState();
  }
}

class MainState extends State<MainApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  Uri? _initialLink;
  bool _hasProcessedInitialLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinkListener();
  }

  // Initialize deep link listener
  void _initDeepLinkListener() {
    _appLinks = AppLinks();
    
    // Handle initial link when app is opened from a deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _initialLink = uri;
        _hasProcessedInitialLink = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleDeepLink(uri);
          });
        });
      }
    }).catchError((err) {
      debugPrint('Get initial link error: $err');
    });
    
    // Listen to incoming links when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        // Skip if this is the same as the initial link (already processed)
        if (_hasProcessedInitialLink && _initialLink != null && uri.toString() == _initialLink.toString()) {
          _hasProcessedInitialLink = false;
          return;
        }
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  // Handle deep link
  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'chuchu' && uri.host == 'invite') {
      _handleInviteDeepLink(uri);
    }
  }

  // Handle invite deep link: chuchu://invite?npub=xxx&name=xxx&avatar=xxx
  Future<void> _handleInviteDeepLink(Uri uri) async {
    try {
      final npub = uri.queryParameters['npub'];
      if (npub == null || npub.isEmpty) {
        return;
      }

      final pubkey = Nip19.decodePubkey(npub);
      if (pubkey.isEmpty) {
        return;
      }

      // Wait for initialization to complete
      try {
        await InitializationManager.instance.waitForComponent(
          'user_services',
          timeout: const Duration(seconds: 10),
        );
      } catch (e) {
        // Continue even if timeout
      }

      // Reload user profile from relay to get latest data
      try {
        await Account.sharedInstance.reloadProfileFromRelay(pubkey);
      } catch (e) {
        // Continue even if reload fails
      }

      // Get relay group info
      final relayGroup = await RelayGroup.sharedInstance
          .searchGroupsMetadataWithGroupID(
        pubkey,
        AppConfig.Config.sharedInstance.recommendGroupRelays.first,
      );

      if (relayGroup == null) {
        return;
      }

      // Navigate to FeedPersonalPage
      final context = ChuChuNavigator.navigatorKey.currentContext;
      if (context != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ChuChuNavigator.pushPage(
            context,
            (context) => FeedPersonalPage(relayGroupDB: relayGroup),
          );
        });
      }
    } catch (e) {
      debugPrint('Deep link handling error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      default:
        break;
    }
  }

  void _handleAppResumed() {
    Future.microtask(() async {
      try {
        final userServiceReady = await InitializationManager.instance
            .waitForComponent('user_services', timeout: const Duration(seconds: 5));
        
        if (userServiceReady) {
          await ChuChuUserInfoManager.sharedInstance.resetHeartBeat();
          debugPrint('The heart rate reset is completed.');
        } else {
          debugPrint('The user service is not ready. Skip the heartbeat reset');
        }
      } catch (error) {
        debugPrint('Heart rate reset error: $error');
      }
    });
  }

  void _handleAppPaused() {
    debugPrint('The application has been suspended.');
  }

  void _handleAppDetached() {
    Future.microtask(() async {
      try {
        ThreadPoolManager.sharedInstance.dispose();
        debugPrint('The application resource cleaning has been completed');
      } catch (error) {
        debugPrint('Application resource cleaning error: $error');
      }
    });
  }

  // Global builder for web layout constraints
  Widget _buildWithWebLayout(BuildContext context, Widget? child) {
    Widget widget = child ?? const SizedBox.shrink();
    
    // Apply EasyLoading initialization
    final easyLoadingBuilder = ChuChuLoading.init();
    widget = easyLoadingBuilder(context, widget);
    

    
    return widget;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: _buildWithWebLayout,
      navigatorKey: ChuChuNavigator.navigatorKey,
      title: 'ChuChu',
      theme: lightTheme,
      darkTheme: lightTheme,
      themeMode: ThemeMode.light,
      home: const SplashPage(),
      onGenerateRoute: (settings) {
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashPage(),
        );
      },
    );
  }
}
