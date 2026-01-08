import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/utils/navigator/navigator.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import '../../../core/manager/chuchu_user_info_manager.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../core/widgets/logout_confirm_dialog.dart';
import '../../creator/pages/create_creator_page.dart';
import '../../feed/pages/feed_personal_page.dart';
import '../../profile/pages/my_profile_page.dart';
import '../../profile/pages/share_profile_page.dart';
import '../../search/pages/search_page.dart';
import '../../wallet/wallet_page.dart';
import '../../feed/pages/bookmarks_page.dart';

/// Enum representing different content pages for web layout
enum WebContentPage {
  home,
  myPosts,
  shareProfile,
  wallet,
  search,
  bookmarks,
  settings,
}

class DrawerMenu extends StatefulWidget {
  /// Callback for web layout to switch content page without navigation
  final void Function(WebContentPage page)? onWebPageChange;
  
  /// Currently selected page (for highlighting in web layout)
  final WebContentPage? currentPage;

  const DrawerMenu({
    super.key,
    this.onWebPageChange,
    this.currentPage,
  });

  @override
  State createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu>
    with SingleTickerProviderStateMixin {
  String get _getUserNupbStr {
    UserDBISAR? userInfo = ChuChuUserInfoManager.sharedInstance.currentUserInfo;
    if (userInfo == null) return '--';
    String pubkey = userInfo.pubKey;
    String nupKey = Nip19.encodePubkey(pubkey);
    return '${nupKey.substring(0, 6)}:${nupKey.substring(nupKey.length - 6)}';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _getFullNpub() {
    UserDBISAR? userInfo = ChuChuUserInfoManager.sharedInstance.currentUserInfo;
    if (userInfo == null) return '';
    String pubkey = userInfo.pubKey;
    return Nip19.encodePubkey(pubkey);
  }

  void _copyNpub() {
    final npub = _getFullNpub();
    if (npub.isEmpty) return;

    Clipboard.setData(ClipboardData(text: npub));
    CommonToast.instance.show(context, 'Copied to clipboard', toastType: ToastType.success);
  }

  /// Handle menu item tap - use callback for web, navigation for mobile
  void _handleMenuTap(WebContentPage page, VoidCallback mobileAction) {
    if (kIsWeb && widget.onWebPageChange != null) {
      // On web, use callback to switch content without navigation
      widget.onWebPageChange!(page);
    } else {
      // On mobile, close drawer and navigate
      Navigator.of(context).pop();
      mobileAction();
    }
  }

  @override
  Widget build(BuildContext context) {
    UserDBISAR? userInfo = ChuChuUserInfoManager.sharedInstance.currentUserInfo;

    String? nikName = userInfo?.name ?? userInfo?.nickName ?? '';
    if (nikName.isEmpty) {
      nikName = _getUserNupbStr;
    }
    final theme = Theme.of(context);
    // On web, no border radius (flat sidebar); on mobile, rounded corners for drawer
    final borderRadius = kIsWeb
        ? BorderRadius.zero
        : BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User profile section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: kIsWeb ? 20 : 50,
                    bottom: 20,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: kIsWeb
                        ? BorderRadius.zero
                        : BorderRadius.only(
                            topLeft: Radius.circular(20),
                          ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFDF2F8),
                        Color(0xFFFAF5FF),
                        Color(0xFFFFFFFF),
                      ],
                    ),
                  ),
                  child: ValueListenableBuilder<UserDBISAR>(
                    valueListenable: Account.sharedInstance.getUserNotifier(
                      ChuChuUserInfoManager
                              .sharedInstance
                              .currentUserInfo
                              ?.pubKey ??
                          '',
                    ),
                    builder: (context, user, child) {
                      final avatarSize = 70.0;
                      final borderWidth = 3.0;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: avatarSize + borderWidth * 2,
                          height: avatarSize + borderWidth * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: borderWidth,
                            ),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              Navigator.of(context).pop();
                              ChuChuNavigator.pushPage(
                                context,
                                (context) => MyProfilePage(),
                              );
                            },
                            child: FeedWidgetsUtils.clipImage(
                              borderRadius: avatarSize,
                              imageSize: avatarSize,
                              child: ChuChuCachedNetworkImage(
                                imageUrl: user.picture ?? '',
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) =>
                                        FeedWidgetsUtils.badgePlaceholderImage(),
                                errorWidget:
                                    (_, __, ___) =>
                                        FeedWidgetsUtils.badgePlaceholderImage(),
                                width: avatarSize,
                                height: avatarSize,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<UserDBISAR>(
                  valueListenable: Account.sharedInstance.getUserNotifier(
                    ChuChuUserInfoManager
                            .sharedInstance
                            .currentUserInfo
                            ?.pubKey ??
                        '',
                  ),
                  builder: (context, user, child) {
                    final followersCount = user.followersList?.length ?? 0;
                    final followingCount = user.followingList?.length ?? 0;

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        Navigator.of(context).pop();
                        ChuChuNavigator.pushPage(
                          context,
                          (context) => MyProfilePage(),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  nikName ?? '--',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: kTitleColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 6),
                              CommonImage(iconName: 'lighting_icon.png',size: 16, color: kYellow,)
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getUserNupbStr,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _copyNpub(),
                                child: CommonImage(
                                  iconName: 'copy_icon.png',
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                _formatNumber(followersCount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: kTitleColor,
                                ),
                              ),
                              Text(
                                ' Followers',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                _formatNumber(followingCount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: kTitleColor,
                                ),
                              ),
                              Text(
                                ' Following',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ).setPadding(EdgeInsets.symmetric(horizontal: 20)),
              ],
            ),
            const SizedBox(height: 24),
            // _menuItem(
            //   context,
            //   Icons.person_outline,
            //   "Nostr profile",
            //   onTap: () {
            //     Navigator.of(context).pop(); // Close drawer first
            //     ChuChuNavigator.pushPage(
            //       context,
            //       (context) => MyProfilePage(),
            //     );
            //   }
            // ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _menuItem(
                        context,
                        'post_bg_icon.png',
                        "My Posts",
                        isSelected: widget.currentPage == WebContentPage.myPosts,
                        onTap: () {
                          // Check if user is a creator first
                          RelayGroupDBISAR? myRelayGroup =
                              RelayGroup
                                  .sharedInstance
                                  .myGroups[Account.sharedInstance.currentPubkey]
                                  ?.value;
                          if (myRelayGroup == null) {
                            // Show become creator dialog for both web and mobile
                            FeedWidgetsUtils.showBecomeCreatorDialog(
                              context,
                              callback: () {
                                Navigator.of(context, rootNavigator: true).pop();
                                if (kIsWeb) {
                                  // On web, navigate using root navigator
                                  Navigator.of(context, rootNavigator: true).push(
                                    FeedWidgetsUtils.createSlideTransition(
                                      pageBuilder:
                                          (context, animation, secondaryAnimation) =>
                                              CreateCreatorPage(),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).push(
                                    FeedWidgetsUtils.createSlideTransition(
                                      pageBuilder:
                                          (context, animation, secondaryAnimation) =>
                                              CreateCreatorPage(),
                                    ),
                                  );
                                }
                              },
                            );
                            return;
                          }
                          // User is a creator, proceed with page switch
                          _handleMenuTap(
                            WebContentPage.myPosts,
                            () {
                              ChuChuNavigator.pushPage(
                                context,
                                (context) =>
                                    FeedPersonalPage(relayGroupDB: myRelayGroup),
                              );
                            },
                          );
                        },
                      ),
                      _menuItem(
                        context,
                        'share_bg_icon.png',
                        "Share Profile",
                        isSelected: widget.currentPage == WebContentPage.shareProfile,
                        onTap: () => _handleMenuTap(
                          WebContentPage.shareProfile,
                          () {
                            final currentPubkey = ChuChuUserInfoManager.sharedInstance.currentUserInfo?.pubKey;
                            if (currentPubkey != null && currentPubkey.isNotEmpty) {
                              ChuChuNavigator.pushPage(
                                context,
                                (context) => ShareProfilePage(pubkey: currentPubkey),
                              );
                            }
                          },
                        ),
                      ),
                      _menuItem(
                        context,
                        'wallet_bg_icon.png',
                        "Wallet",
                        isSelected: widget.currentPage == WebContentPage.wallet,
                        onTap: () => _handleMenuTap(
                          WebContentPage.wallet,
                          () {
                            ChuChuNavigator.pushPage(
                              context,
                              (context) => WalletPage(),
                            );
                          },
                        ),
                      ),
                      _menuItem(
                        context,
                        'search_bg_icon.png',
                        "Search",
                        isSelected: widget.currentPage == WebContentPage.search,
                        onTap: () => _handleMenuTap(
                          WebContentPage.search,
                          () {
                            ChuChuNavigator.pushPage(
                              context,
                              (context) => SearchPage(),
                            );
                          },
                        ),
                      ),
                      _menuItem(
                        context,
                        'bookmarks_bg_icon.png',
                        "Bookmarks",
                        isSelected: widget.currentPage == WebContentPage.bookmarks,
                        onTap: () => _handleMenuTap(
                          WebContentPage.bookmarks,
                          () {
                            ChuChuNavigator.pushPage(
                              context,
                              (context) => BookmarksPage(),
                            );
                          },
                        ),
                      ),

                      _menuItem(
                        context,
                        'settings_bg_icon.png',
                        "Settings",
                        isSelected: widget.currentPage == WebContentPage.settings,
                        onTap: () => _handleMenuTap(
                          WebContentPage.settings,
                          () {
                            ChuChuNavigator.pushPage(
                              context,
                              (context) => const MyProfilePage(),
                            );
                          },
                        ),
                      ),
                      // _menuItem(
                      //   context,
                      //   Icons.subscriptions,
                      //   "Subscription Settings",
                      //   onTap: () {
                      //     Navigator.of(context).pop(); // Close drawer first
                      //     ChuChuNavigator.pushPage(context, (context) => const SubscriptionSettingsPage());
                      //   },
                      // ),
                      // _menuItem(
                      //   context,
                      //   Icons.star_outline,
                      //   "Creator Center",
                      //   onTap: () {
                      //     Navigator.of(context).pop(); // Close drawer first
                      //     ChuChuNavigator.pushPage(context, (context) => const CreateCreatorPage());
                      //   },
                      // ),
                      const SizedBox(height: 16),
                      // Creator Pro upgrade box
                      _buildCreatorProBox(context),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Divider(color: theme.dividerColor.withOpacity(0.1)),
                  _menuItem(
                    context,
                    Icons.logout,
                    "Log Out",
                    iconColor: theme.colorScheme.onSurfaceVariant,
                    trailing: const SizedBox.shrink(),
                    onTap: () {
                      LogoutConfirmDialog.show(context, closeDrawer: true);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorProBox(BuildContext context) {
    final currentPubkey = Account.sharedInstance.currentPubkey;
    final myRelayGroup =
        RelayGroup.sharedInstance.myGroups[currentPubkey]?.value;
    final isCreator = myRelayGroup != null;
    final hasPaidSubscription =
        myRelayGroup?.subscriptionAmount != null &&
        myRelayGroup!.subscriptionAmount > 0;

    // Don't show anything if user is creator but has no paid subscription
    if (isCreator && !hasPaidSubscription) {
      return const SizedBox.shrink();
    }

    // Determine content based on user status
    final String title;
    final String iconName;
    final String description;
    final String buttonText;
    final VoidCallback? onButtonTap;

    if (isCreator && hasPaidSubscription) {
      final formattedAmount = _formatNumber(myRelayGroup.subscriptionAmount);
      title = 'Creator';
      iconName = 'start_ill_icon.png';
      description =
          'Subscribers will pay $formattedAmount sats per month to access your content.';
      buttonText = '$formattedAmount sats/mo';
      onButtonTap = null; // Not clickable
    } else {
      title = 'Become a Creator';
      iconName = 'red_star_icon.png';
      description =
          'Become a creator to publish content and earn subscription revenue.';
      buttonText = 'Become Creator';
      onButtonTap = () {
        if (kIsWeb) {
          // On web, sidebar is fixed, use root navigator to push page
          Navigator.of(context, rootNavigator: true).push(
            FeedWidgetsUtils.createSlideTransition(
              pageBuilder:
                  (context, animation, secondaryAnimation) => CreateCreatorPage(),
            ),
          );
        } else {
          // On mobile, close drawer first then navigate
          Navigator.of(context).pop();
          Navigator.of(context).push(
            FeedWidgetsUtils.createSlideTransition(
              pageBuilder:
                  (context, animation, secondaryAnimation) => CreateCreatorPage(),
            ),
          );
        }
      };
    }

    return _buildCreatorBox(
      title: title,
      iconName: iconName,
      description: description,
      buttonText: buttonText,
      onButtonTap: onButtonTap,
    );
  }

  Widget _buildCreatorBox({
    required String title,
    required String iconName,
    required String description,
    required String buttonText,
    VoidCallback? onButtonTap,
  }) {
    final buttonWidget = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Color(0xFF334155), // Dark grey button
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        buttonText,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16,horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B), // Dark blue background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CommonImage(
                iconName: iconName,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          onButtonTap != null
              ? GestureDetector(onTap: onButtonTap, child: buttonWidget)
              : buttonWidget,
        ],
      ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    dynamic icon,
    String title, {
    bool bold = true,
    bool isSelected = false,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    // Highlight selected item on web
    final isHighlighted = kIsWeb && isSelected;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: isHighlighted
            ? BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Row(
          children: [
            icon is String
                ? CommonImage(iconName: icon, size: 40)
                : Icon(
                  icon as IconData,
                  size: 24,
                  color: iconColor ?? theme.iconTheme.color,
                ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                  color: isHighlighted ? kPrimary : theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else if (!kIsWeb) // Hide chevron on web
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
          ],
        ),
      ),
    );
  }
}
