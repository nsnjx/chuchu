import 'package:chuchu/core/utils/adapt.dart';
import 'package:chuchu/core/utils/navigator/navigator.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:chuchu/presentation/drawerMenu/follows/pages/follows_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart' show Platform;
import '../../../core/account/account.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../feed/pages/create_feed_page.dart';
import '../../feed/pages/feed_notifications_page.dart';
import '../../creator/pages/create_creator_page.dart';

import '../widgets/drawer_menu.dart';
import '../../feed/pages/feed_page.dart';
import '../../feed/pages/feed_personal_page.dart';
import '../../feed/pages/bookmarks_page.dart';
import '../../profile/pages/my_profile_page.dart';
import '../../profile/pages/share_profile_page.dart';
import '../../search/pages/search_page.dart';
import '../../wallet/wallet_page.dart';
import '../../../core/manager/chuchu_user_info_manager.dart';
import '../../../core/manager/chuchu_feed_manager.dart';
import '../../../core/feed/model/notificationDB_isar.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/theme/app_theme.dart';


enum BottomNavItem {
  home(
    selectedAsset: 'home_select_icon.png',
    unselectedAsset: 'home_select_icon.png',
  ),
  // search(
  //   selectedAsset: 'search_select_icon.png',
  //   unselectedAsset: 'search_icon.png',
  // ),
  add(
    selectedAsset: 'reply_select_icon.png',
    unselectedAsset: 'reply.png',
  ),
  // messages(
  //   selectedAsset: 'reply_select_icon.png',
  //   unselectedAsset: 'reply.png',
  // ),
  profile(
    selectedAsset: 'user_icon.png',
    unselectedAsset: 'user_icon.png',
  );

  final String? selectedAsset;
  final String? unselectedAsset;

  const BottomNavItem({
    this.selectedAsset,
    this.unselectedAsset,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, ChuChuFeedObserver, ChuChuUIRefreshMixin {
  final double maxSlide = 0.75;
  late final AnimationController _controller;
  late final ScrollController _scrollController;
  bool _isScrolled = false;
  bool _hasNotifications = false;
  BottomNavItem _currentTab = BottomNavItem.home;
  
  // Web content page state
  WebContentPage _currentWebPage = WebContentPage.home;
  // Flag to show dialog when switching to myPosts page
  bool _shouldShowMyPostsDialog = false;
  // Store nested Navigator context for each page to allow pushing from drawer menu
  final Map<WebContentPage, BuildContext?> _nestedNavigatorContexts = {};

  bool get isOpen => _controller.value == 1.0;
  
  /// Public method to switch web content page (used by child widgets)
  void switchToWebPage(WebContentPage page, {bool showDialog = false}) {
    if (kIsWeb && mounted) {
      setState(() {
        _currentWebPage = page;
        _shouldShowMyPostsDialog = showDialog && page == WebContentPage.myPosts;
      });
    }
  }
  
  /// Get nested Navigator context for a specific page (used by drawer menu)
  BuildContext? getNestedNavigatorContext(WebContentPage page) {
    return _nestedNavigatorContexts[page];
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    ChuChuFeedManager.sharedInstance.addObserver(this);
  }

  void _scrollListener() {
    final isScrolled =
        _scrollController.hasClients && _scrollController.offset > 0;
    if (isScrolled != _isScrolled) {
      setState(() {
        _isScrolled = isScrolled;
      });
    }
  }

  void open() => _controller.forward();
  void close() => _controller.reverse();
  void toggle() => isOpen ? close() : open();



  void _showProfileDrawer() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, animation1, animation2, child) {
        // Use fixed width for web, relative width for mobile
        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth = kIsWeb ? 360.0 : screenWidth * 0.75;
        
        return Stack(
          children: [
            Positioned.fill(
              child: FadeTransition(
                opacity: animation1,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation1,
                curve: Curves.easeInOut,
              )),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: drawerWidth,
                  height: MediaQuery.of(context).size.height,
                  child: DrawerMenu(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    ChuChuFeedManager.sharedInstance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget buildBody(BuildContext context) {
    // On web, use fixed sidebar layout; on mobile, use drawer
    if (kIsWeb) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Row(
              children: [
                // Fixed sidebar on the left for web
                SizedBox(
                  width: 280,
                  child: DrawerMenu(
                    currentPage: _currentWebPage,
                    onWebPageChange: (page) {
                      setState(() {
                        _currentWebPage = page;
                      });
                      // Navigator is recreated with new key when page changes, so no need to reset
                    },
                  ),
                ),
                // Main content area with max width constraint
                SizedBox(
                  width: 600,
                  child: ClipRect(
                    child: _buildWebContentPage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Mobile layout with drawer
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildCurrentPage(),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigationBar(context),
          ),
        ],
      ),
    );
  }
  
  /// Build content page for web based on current selected page
  Widget _buildWebContentPage() {
    switch (_currentWebPage) {
      case WebContentPage.home:
        return _wrapWithBackHandler(
          Builder(
            builder: (nestedContext) {
              // Store nested Navigator context for home page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _nestedNavigatorContexts[WebContentPage.home] = nestedContext;
                }
              });
              return Scaffold(
                appBar: _buildAppBar(context),
                body: Stack(
                  children: [
                    _buildCurrentPage(),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _buildBottomNavigationBar(context),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      case WebContentPage.myPosts:
        final myRelayGroup = RelayGroup.sharedInstance.myGroups[Account.sharedInstance.currentPubkey]?.value;
        if (myRelayGroup == null) {
          return _wrapWithBackHandler(
            Builder(
              builder: (nestedContext) {
                // Show dialog if flag is set (when switching from drawer menu)
                if (_shouldShowMyPostsDialog && kIsWeb) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _shouldShowMyPostsDialog = false;
                    FeedWidgetsUtils.showBecomeCreatorDialog(
                      nestedContext,
                      navigatorContext: nestedContext,
                      callback: (pushContext) async {
                        // Use ChuChuNavigator to handle both web and mobile
                        final result = await ChuChuNavigator.pushPage(
                          pushContext,
                          (context) => CreateCreatorPage(),
                          nestedNavigatorContext: kIsWeb ? pushContext : null,
                          fullscreenDialog: false,
                        );
                        // If creator was created successfully, refresh state and return to home
                        if (result != null && result == true && mounted) {
                          setState(() {});
                          // Return to home page after creating creator
                          if (kIsWeb) {
                            setState(() {
                              _currentWebPage = WebContentPage.home;
                            });
                          }
                        }
                      },
                    );
                  });
                }
                
                return _buildWebPageWrapper(
                  title: 'My Posts',
                  showBackButton: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Become a creator to see your posts'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            // Use ChuChuNavigator to handle both web and mobile
                            final result = await ChuChuNavigator.pushPage(
                              nestedContext,
                              (context) => CreateCreatorPage(),
                              nestedNavigatorContext: kIsWeb ? nestedContext : null,
                              fullscreenDialog: false,
                            );
                            // If creator was created successfully, refresh state and return to home
                            if (result != null && result == true && mounted) {
                              setState(() {});
                              // Return to home page after creating creator
                              if (kIsWeb) {
                                setState(() {
                                  _currentWebPage = WebContentPage.home;
                                });
                              }
                            }
                          },
                          child: Text('Become Creator'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }
        return _wrapWithBackHandler(FeedPersonalPage(relayGroupDB: myRelayGroup));
      case WebContentPage.shareProfile:
        final currentPubkey = ChuChuUserInfoManager.sharedInstance.currentUserInfo?.pubKey;
        if (currentPubkey != null && currentPubkey.isNotEmpty) {
          return _wrapWithBackHandler(
            Builder(
              builder: (nestedContext) {
                // Store nested Navigator context for this page
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _nestedNavigatorContexts[WebContentPage.shareProfile] = nestedContext;
                  }
                });
                return ShareProfilePage(pubkey: currentPubkey);
              },
            ),
          );
        }
        return _wrapWithBackHandler(_buildWebPageWrapper(
          title: 'Share Profile', 
          showBackButton: false,
          child: Center(child: Text('No profile available')),
        ));
      case WebContentPage.wallet:
        return _wrapWithBackHandler(
          Builder(
            builder: (nestedContext) {
              // Store nested Navigator context for this page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _nestedNavigatorContexts[WebContentPage.wallet] = nestedContext;
                }
              });
              return WalletPage();
            },
          ),
        );
      case WebContentPage.search:
        return _wrapWithBackHandler(
          Builder(
            builder: (nestedContext) {
              // Store nested Navigator context for this page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _nestedNavigatorContexts[WebContentPage.search] = nestedContext;
                }
              });
              return SearchPage();
            },
          ),
        );
      case WebContentPage.bookmarks:
        return _wrapWithBackHandler(
          Builder(
            builder: (nestedContext) {
              // Store nested Navigator context for this page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _nestedNavigatorContexts[WebContentPage.bookmarks] = nestedContext;
                }
              });
              return BookmarksPage();
            },
          ),
        );
      case WebContentPage.settings:
        return _wrapWithBackHandler(
          Builder(
            builder: (nestedContext) {
              // Store nested Navigator context for this page
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _nestedNavigatorContexts[WebContentPage.settings] = nestedContext;
                }
              });
              return MyProfilePage();
            },
          ),
        );
    }
  }
  
  /// Wrap page with back handler - intercepts back navigation to go Home
  Widget _wrapWithBackHandler(Widget child) {
    // Use HeroControllerScope to enable Hero animations in the nested Navigator
    return HeroControllerScope(
      controller: MaterialApp.createMaterialHeroController(),
      child: ClipRect(
        child: Navigator(
          key: ValueKey('${_currentWebPage}_navigator'),
          onPopPage: (route, result) {
            if (!route.didPop(result)) {
              return false;
            }
            // After pop, check if we should return to home
            // This will be handled by the NavigatorObserver if stack becomes empty
            // But if we're on myPosts page and popping back to initial route, go to home
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _currentWebPage != WebContentPage.home) {
                // Check if Navigator can still pop (if not, we're back to initial route)
                final navigatorState = Navigator.of(context, rootNavigator: false);
                if (!navigatorState.canPop() && _currentWebPage == WebContentPage.myPosts) {
                  // We're back to initial route on myPosts page, return to home
                  setState(() {
                    _currentWebPage = WebContentPage.home;
                  });
                }
              }
            });
            return true;
          },
          observers: [_WebContentNavigatorObserver(
            onEmptyStack: () {
              // When stack becomes empty, return to home page
              if (_currentWebPage != WebContentPage.home && mounted) {
                setState(() {
                  _currentWebPage = WebContentPage.home;
                });
              }
            },
            onPopToInitial: () {
              // When popping back to initial route, return to home
              // This applies to all pages (myPosts, shareProfile, wallet, search, bookmarks, settings)
              if (_currentWebPage != WebContentPage.home && mounted) {
                setState(() {
                  _currentWebPage = WebContentPage.home;
                });
              }
            },
          )],
          onGenerateRoute: (settings) {
            if (settings.name == '/') {
              return MaterialPageRoute(
                builder: (context) => child,
                settings: settings,
              );
            }
            return null;
          },
          initialRoute: '/',
        ),
      ),
    );
  }
  
  /// Wrapper for simple web pages with consistent styling
  Widget _buildWebPageWrapper({
    required String title, 
    required Widget child,
    bool showBackButton = true,
  }) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBgLight,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: showBackButton 
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: kTitleColor),
                onPressed: () {
                  // Go back to Home
                  setState(() {
                    _currentWebPage = WebContentPage.home;
                  });
                },
              )
            : null,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: kTitleColor,
          ),
        ),
      ),
      body: child,
    );
  }

  PreferredSizeWidget? _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    
    switch (_currentTab) {
      case BottomNavItem.home:
        return AppBar(
          backgroundColor: kBgLight,
          foregroundColor: kBgLight,
          elevation: _isScrolled ? 4 : 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          centerTitle: false,
          title: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: toggle,
              child: CommonImage(
                iconName: 'logo_text_primary.png',
                height: 40,
              ),
            ).setPaddingOnly(left: 12.0),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(12.px),
            child: const SizedBox(),
          ),
          actions: [
            Stack(
              children: [
                GestureDetector(
                  onTap: (){
                    setState(() {
                      _hasNotifications = false;
                    });

                    ChuChuNavigator.pushPage(
                      context,
                          (context) => FeedNotificationsPage(relayGroupDB: RelayGroup.sharedInstance.myGroups[Account.sharedInstance.currentPubkey]?.value),
                    );
                  },
                  child: CommonImage(
                    iconName: 'notification.png',
                    size: 24,
                  ),
                ).setPaddingOnly(right: 12.0),
                // Red dot indicator for notifications
                if (_hasNotifications)
                  Positioned(
                    right: 14.0,
                    top: 0.0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        );
        
      // case BottomNavItem.search:
      //   return null;
        
      // case BottomNavItem.messages:
      //   return AppBar(
      //     backgroundColor: theme.colorScheme.surface,
      //     elevation: 0,
      //     title: Text(
      //       'Messages',
      //       style: theme.textTheme.headlineMedium?.copyWith(
      //         fontWeight: FontWeight.bold,
      //       ),
      //     ),
      //     actions: [
      //       IconButton(
      //         icon: Icon(Icons.edit, color: theme.colorScheme.onSurface),
      //         onPressed: () {
      //           // Handle new message
      //         },
      //       ),
      //     ],
      //   );
      //
      case BottomNavItem.profile:
        return AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'Profile',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
              onPressed: () {
                // Handle settings
              },
            ),
          ],
        );
        
      case BottomNavItem.add:
        return AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text(
            'Create Post',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            onPressed: () {
              setState(() {
                _currentTab = BottomNavItem.home;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Handle post creation
              },
              child: Text(
                'Post',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    if (kIsWeb) {
      return _buildWebBottomNavigationBar(context);
    } else {
      return _buildMobileBottomNavigationBar(context);
    }
  }

  Widget _buildWebBottomNavigationBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 24, bottom: 24),
        child: Builder(
          builder: (buttonContext) => _buildAddButton(buttonContext),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    
    final double systemBottomInset = mediaQuery.viewPadding.bottom;
    final double bottomInset = mediaQuery.padding.bottom;
    final double effectiveBottomInset = systemBottomInset > bottomInset 
        ? systemBottomInset 
        : bottomInset;

    const double barHeight  = 90;
    const double floatGap   = 24;
    const double sideMargin = 0;
    
    final double minBottomPadding = Platform.isAndroid ? 32.0 : floatGap;
    final double totalBottomPadding = effectiveBottomInset + floatGap;
    final double finalBottomPadding = totalBottomPadding > minBottomPadding 
        ? totalBottomPadding 
        : minBottomPadding;

    return Padding(
      padding: EdgeInsets.only(
        left   : sideMargin,
        right  : sideMargin,
        bottom : finalBottomPadding,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.20),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in [BottomNavItem.home])
                  _buildTabItem(item),
                _buildAddButton(),
                for (final item in [BottomNavItem.profile])
                  _buildTabItem(item),
              ],
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildTabItem(BottomNavItem item) {
    final bool isSelected = _currentTab == item && item != BottomNavItem.profile;
    final theme = Theme.of(context);

    Widget iconWidget;
    if (item.unselectedAsset != null && item.selectedAsset != null) {
      final asset = isSelected ? item.selectedAsset! : item.unselectedAsset!;
      iconWidget = CommonImage(iconName: asset,size: 23,);
    } else {
      iconWidget = Icon(
        Icons.add,
        size: 23,
        color: isSelected ? theme.colorScheme.primary : Colors.grey[600],
      );
    }

    return GestureDetector(
      onTap: () {
        if (item == BottomNavItem.profile) {
          // Show drawer menu from right side for profile tab
          _showProfileDrawer();
        } else {
          setState(() => _currentTab = item);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return IndexedStack(
      index: _currentTab.index,
      children: [
        FeedPage(scrollController: _scrollController),
        FollowsPages(),
        FollowsPages(),
        Container(), // Placeholder for profile - will show drawer instead
        CreateFeedPage(),
      ],
    );
  }

  Widget _buildAddButton([BuildContext? buttonContext]) {
    // Use buttonContext if provided (from Builder in web), otherwise use this.context
    final ctx = buttonContext ?? context;
    return GestureDetector(
      onTap: () {
        Map<String, ValueNotifier<RelayGroupDBISAR>>? groups = RelayGroup.sharedInstance.myGroups;
        bool hasExistingGroup = groups[Account.sharedInstance.currentPubkey] != null;
        
        if (hasExistingGroup) {
          _navigateToCreatePostWithContext(ctx);
        } else {
          // Show dialog - on web, pass nested Navigator context for push
          if (kIsWeb) {
            // Use buttonContext which is inside nested Navigator
            FeedWidgetsUtils.showBecomeCreatorDialog(
              ctx,
              navigatorContext: ctx, // Use buttonContext which is nested Navigator context
              callback: (pushContext) {
                _navigateToCreateCreatorWithContext(pushContext);
              },
            );
          } else {
            // On mobile, show dialog first
            FeedWidgetsUtils.showBecomeCreatorDialog(
              ctx,
              callback: (pushContext) {
                _navigateToCreateCreatorWithContext(pushContext);
              },
            );
          }
        }
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: getBrandGradientDiagonal(),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Main shadow - soft and natural
            BoxShadow(
              color: kPrimary.withOpacity(0.25),
              blurRadius: 12,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
            // Secondary shadow - subtle depth
            BoxShadow(
              color: kSecondary.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 2),
              spreadRadius: -2,
            ),
            // Highlight shadow - adds glow effect
            BoxShadow(
              color: kTertiary.withOpacity(0.1),
              blurRadius: 16,
              offset: Offset(0, 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  @override
  didNewNotesCallBackCallBack(List<NoteDBISAR> notes) {}

  @override
  didNewNotificationCallBack(List<NotificationDBISAR> notifications) {
    if (notifications.isNotEmpty && mounted) {
      setState(() {
        _hasNotifications = true;
      });
    }
  }

  void _navigateToCreatePostWithContext(BuildContext pushContext) {
    // Use ChuChuNavigator to handle both web and mobile
    ChuChuNavigator.pushPage(
      pushContext,
      (context) => CreateFeedPage(),
      nestedNavigatorContext: (kIsWeb == true) ? pushContext : null,
      fullscreenDialog: false,
    );
  }

  void _navigateToCreateCreatorWithContext(BuildContext pushContext) async {
    // Use ChuChuNavigator to handle both web and mobile
    final result = await ChuChuNavigator.pushPage(
      pushContext,
      (context) => CreateCreatorPage(),
      nestedNavigatorContext: (kIsWeb == true) ? pushContext : null,
      fullscreenDialog: false,
    );
    if (result != null && result == true && mounted) {
      setState(() {});
    }
  }
}

/// Navigator observer to detect when the stack becomes empty
class _WebContentNavigatorObserver extends NavigatorObserver {
  final VoidCallback onEmptyStack;
  final VoidCallback? onPopToInitial;

  _WebContentNavigatorObserver({
    required this.onEmptyStack,
    this.onPopToInitial,
  });

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // If there's no previous route after pop, the stack is empty
    if (previousRoute == null) {
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onEmptyStack();
      });
    } else if (previousRoute.settings.name == '/' && onPopToInitial != null) {
      // If we're popping back to initial route, check if we should return to home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPopToInitial!();
      });
    }
  }
}
