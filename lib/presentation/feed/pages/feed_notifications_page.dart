import 'package:chuchu/core/feed/feed+load.dart';
import 'package:chuchu/core/feed/feed+notification.dart';
import 'package:chuchu/core/widgets/common_toast.dart';
import 'package:chuchu/data/models/feed_extension_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/feed/feed.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import '../../../core/feed/model/notificationDB_isar.dart';
import '../../../core/manager/chuchu_feed_manager.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/utils/feed_utils.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../home/pages/home_page.dart';
import '../../home/widgets/drawer_menu.dart';
import 'feed_info_page.dart';
import 'feed_personal_page.dart';

class AggregatedNotification {
  String notificationId;
  int kind;
  String author;
  int createAt;
  String content;
  int zapAmount;
  String associatedNoteId;
  int likeCount;

  AggregatedNotification({
    this.notificationId = '',
    this.kind = 0,
    this.author = '',
    this.createAt = 0,
    this.content = '',
    this.zapAmount = 0,
    this.associatedNoteId = '',
    this.likeCount = 0,
  });

  factory AggregatedNotification.fromNotificationDB(
    NotificationDBISAR notificationDB,
  ) {
    return AggregatedNotification(
      notificationId: notificationDB.notificationId,
      kind: notificationDB.kind,
      author: notificationDB.author,
      createAt: notificationDB.createAt,
      content: notificationDB.content,
      zapAmount: notificationDB.zapAmount,
      associatedNoteId: notificationDB.associatedNoteId,
    );
  }
}

class FeedNotificationsPage extends StatefulWidget {
  final RelayGroupDBISAR? relayGroupDB;

  FeedNotificationsPage({super.key, this.relayGroupDB});

  @override
  State<FeedNotificationsPage> createState() => _FeedNotificationsPageState();
}

class _FeedNotificationsPageState extends State<FeedNotificationsPage>
    with ChuChuFeedObserver, ChuChuUIRefreshMixin {
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final int _limit = 50;
  int? _lastTimestamp;
  final List<AggregatedNotification> _aggregatedNotifications = [];
  @override
  void initState() {
    super.initState();
    ChuChuFeedManager.sharedInstance.addObserver(this);
    _lastTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _loadNotificationData();
  }

  @override
  void dispose() {
    ChuChuFeedManager.sharedInstance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  _loadNotificationData() async {
    try {
      List<NotificationDBISAR> notificationList =
          await Feed.sharedInstance.loadNotificationsFromDB(
            _lastTimestamp ?? 0,
            limit: _limit,
          ) ??
          [];

      List<AggregatedNotification> aggregatedNotifications =
          _getAggregatedNotifications(notificationList);
      _aggregatedNotifications.addAll(aggregatedNotifications);

      // Only update _lastTimestamp if we have notifications
      if (notificationList.isNotEmpty) {
        _lastTimestamp = notificationList.last.createAt;
      }
    } catch (e) {
      debugPrint('[FeedNotifications] Error loading notifications: $e');
      // Continue with empty list on error
    } finally {
      // Always set loading to false, even if there was an error
      _isLoading = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  List<AggregatedNotification> _getAggregatedNotifications(
    List<NotificationDBISAR> notifications,
  ) {
    List<NotificationDBISAR> likeTypeNotification = [];
    List<NotificationDBISAR> otherTypeNotification = [];
    Set<String> groupedItems = {};

    for (var notification in notifications) {
      if (notification.isLike) {
        likeTypeNotification.add(notification);
        groupedItems.add(notification.associatedNoteId);
      } else {
        otherTypeNotification.add(notification);
      }
    }

    Map<String, List<NotificationDBISAR>> grouped = {};
    for (var groupedItem in groupedItems) {
      grouped[groupedItem] =
          likeTypeNotification
              .where(
                (notification) => notification.associatedNoteId == groupedItem,
              )
              .toList();
    }

    List<AggregatedNotification> aggregatedNotifications = [];
    grouped.forEach((key, value) {
      value.sort((a, b) => b.createAt.compareTo(a.createAt)); // sort each group
      AggregatedNotification groupedNotification =
          AggregatedNotification.fromNotificationDB(value.first);
      groupedNotification.likeCount = value.length;
      aggregatedNotifications.add(groupedNotification);
    });

    aggregatedNotifications.addAll(
      otherTypeNotification.map(
        (element) => AggregatedNotification.fromNotificationDB(element),
      ),
    );
    aggregatedNotifications.sort((a, b) => b.createAt.compareTo(a.createAt));

    return aggregatedNotifications;
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        title: Center(
          child: Text(
            'Notifications',
            style: GoogleFonts.inter(
              color: kTitleColor,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        actions: [SizedBox(width: 46,)],
        leadingWidth: 46,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: CommonImage(
              iconName: 'back_arrow_icon.png',
              size: 24,
              color: kTitleColor,
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading notifications...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_aggregatedNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _aggregatedNotifications.length,
      itemBuilder: (context, index) {
        return _buildNotificationItem(_aggregatedNotifications[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            CommonImage(iconName: 'notifications_ill_icon.png', width: 220),
            const SizedBox(height: 24),
            Text(
              'No Notifications',
              style: GoogleFonts.inter(
                fontSize: 25,
                color: kTitleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ll see notifications here when someone\ninteracts with your posts',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AggregatedNotification notification) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        if (notification.kind == 7) return;
        _handleNotificationTap(notification);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            _buildNotificationAvatar(notification),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationTitle(notification),
                  const SizedBox(height: 12),
                  _buildNotificationContent(notification),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationAvatar(AggregatedNotification notification) {
    return FutureBuilder<UserDBISAR?>(
      future: _getUserInfo(notification.author),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return GestureDetector(
          onTap: () {
            if (user?.pubKey != null) {
              if (widget.relayGroupDB == null) {
                CommonToast.instance.show(context, 'Creator not enabled',toastType:ToastType.failed);
                return;
              }
              // On web, use nested Navigator context; on mobile, use normal navigation
              if (kIsWeb) {
                // Get nested Navigator context from home page
                final homeState = context.findAncestorStateOfType<HomePageState>();
                final nestedContext = homeState?.getNestedNavigatorContext(WebContentPage.home);
                if (nestedContext != null) {
                  ChuChuNavigator.pushPage(
                    context,
                    (context) => FeedPersonalPage(relayGroupDB: widget.relayGroupDB!),
                    nestedNavigatorContext: nestedContext,
                    fullscreenDialog: false,
                  );
                } else {
                  // Fallback: use normal navigation
                  ChuChuNavigator.pushPage(
                    context,
                    (context) => FeedPersonalPage(relayGroupDB: widget.relayGroupDB!),
                  );
                }
              } else {
                // Mobile: use normal navigation
                ChuChuNavigator.pushPage(
                  context,
                  (context) => FeedPersonalPage(relayGroupDB: widget.relayGroupDB!),
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: FeedWidgetsUtils.clipImage(
              borderRadius: 48,
              imageSize: 48,
              child: ChuChuCachedNetworkImage(
                imageUrl: user?.picture ?? '',
                fit: BoxFit.cover,
                placeholder:
                    (_, __) => FeedWidgetsUtils.badgePlaceholderImage(),
                errorWidget:
                    (_, __, ___) => FeedWidgetsUtils.badgePlaceholderImage(),
                width: 48,
                height: 48,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTitle(AggregatedNotification notification) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: FutureBuilder<UserDBISAR?>(
            future: _getUserInfo(notification.author),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final userName = user?.name ?? '--';

              String actionText = _getActionText(notification.kind);

              return RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: userName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTitleColor,
                      ),
                    ),
                    WidgetSpan(
                      child: SizedBox(width: 6),
                    ),
                    TextSpan(
                      text: actionText,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        _buildNotificationTypeIcon(notification),
      ],
    );
  }

  Widget _buildNotificationContent(AggregatedNotification notification) {
    final theme = Theme.of(context);
    String content = notification.kind == 7 ? '' : notification.content;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          FeedUtils.formatTimeAgo(notification.createAt),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Color(0xFFCAD5E2),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _handleNotificationTap(AggregatedNotification notification) async {
    String noteId;
    if (notification.kind == 1 || notification.kind == 2) {
      noteId = notification.notificationId;
    } else {
      noteId = notification.associatedNoteId;
    }

    NotedUIModel? noteNotifier = await getValueNotifierNoted(
      noteId,
      isUpdateCache: true,
    );

    if (noteNotifier != null) {
      ChuChuNavigator.pushPage(
        context,
        (context) =>
            FeedInfoPage(isShowReply: true, notedUIModel: noteNotifier),
      );
    }
  }

  static Future<NotedUIModel?> getValueNotifierNoted(
    String noteId, {
    bool isUpdateCache = false,
    String? rootRelay,
    String? replyRelay,
    List<String>? setRelay,
    NotedUIModel? notedUIModel,
  }) async {
    Map<String, NoteDBISAR> notesCache = Feed.sharedInstance.notesCache;
    NoteDBISAR? noteNotifier = notesCache[noteId];

    if (!isUpdateCache && noteNotifier != null) {
      return NotedUIModel(noteDB: noteNotifier);
    }

    List<String>? relaysList = setRelay;
    if (relaysList == null) {
      String? relayStr =
          (notedUIModel?.noteDB.replyRelay ?? replyRelay) ??
          (notedUIModel?.noteDB.rootRelay ?? rootRelay);
      relaysList = relayStr != null ? [relayStr] : null;
    }

    NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(
      noteId,
      relays: relaysList,
    );
    if (note == null) return null;

    return NotedUIModel(noteDB: note);
  }

  Widget _buildNotificationTypeIcon(AggregatedNotification notification) {
    final theme = Theme.of(context);
    String iconName;
    Color color;

    switch (notification.kind) {
      case 7: // reaction/like
        iconName = 'liked_icon.png';
        color = Colors.red;
        break;
      case 1: // reply
        iconName = 'replyed_icon.png';
        color = theme.colorScheme.primary;
        break;
      case 9735: // zap
        iconName = 'lightninged_icon.png';
        color = Colors.orange;
        break;
      default:
        iconName = 'notification.png';
        color = theme.colorScheme.onSurface;
    }

    return CommonImage(size: 18, iconName: iconName);
  }

  String _getActionText(int kind) {
    switch (kind) {
      case 7: // reaction/like
        return 'liked';
      case 1: // reply
        return 'replied';
      case 9735: // zap
        return 'zapped';
      case 6: // repost
        return 'reposted';
      case 2: // quote repost
        return 'quoted';
      default:
        return 'interacted with your post';
    }
  }

  Future<UserDBISAR?> _getUserInfo(String pubkey) async {
    try {
      UserDBISAR? user = await Account.sharedInstance.getUserInfo(pubkey);
      if (user != null) {
        return user;
      }

      return null;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }
}
