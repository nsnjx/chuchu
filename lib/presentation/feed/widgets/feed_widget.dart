import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:chuchu/core/widgets/common_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/utils/feed_utils.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../home/widgets/carousel_widget.dart';
import '../../home/pages/home_page.dart';
import '../../home/widgets/drawer_menu.dart';
import '../pages/feed_info_page.dart';
import '../pages/feed_personal_page.dart';
import '../pages/feed_reply_page.dart';
import 'feed_article_widget.dart';
import 'feed_option_widget.dart';
import 'feed_reply_abbreviate_widget.dart';
import 'feed_reply_contact_widget.dart';
import 'feed_rich_text_widget.dart';
import 'feed_url_widget.dart';
import 'feed_video_widget.dart';

enum EFeedWidgetLayout { fullScreen, halfScreen }

class FeedWidget extends StatefulWidget {
  final bool isShowReply;
  final bool isShowUserInfo;
  final bool isShowReplyWidget;
  final bool isShowMomentOptionWidget;
  final bool isShowAllContent;
  final bool isShowBottomBorder;
  final bool isShowOption;
  final bool isShowSimpleReplyBtn;
  final bool isShowContentLeftPadding;

  final Function(NotedUIModel? notedUIModel)? clickMomentCallback;
  final NotedUIModel? notedUIModel;
  final EFeedWidgetLayout? feedWidgetLayout;
  final double horizontalPadding;

  const FeedWidget({
    super.key,
    required this.notedUIModel,
    this.clickMomentCallback,
    this.isShowAllContent = false,
    this.isShowReply = true,
    this.isShowOption = true,
    this.isShowUserInfo = true,
    this.isShowReplyWidget = false,
    this.isShowMomentOptionWidget = true,
    this.isShowBottomBorder = true,
    this.feedWidgetLayout = EFeedWidgetLayout.halfScreen,
    this.isShowSimpleReplyBtn = false,
    this.horizontalPadding = 0,
    this.isShowContentLeftPadding = true,
  });

  @override
  _FeedWidgetState createState() => _FeedWidgetState();
}

class _FeedWidgetState extends State<FeedWidget> {
  static const double _avatarSize = 40.0;
  static const double _borderWidth = 0.5;
  static const double _verticalPadding = 12.0;
  static const double _rightPadding = 8.0;
  static const double _bottomSpacing = 18.0;

  NotedUIModel? notedUIModel;

  RelayGroupDBISAR? relayGroup;

  ThemeData? _cachedTheme;
  MediaQueryData? _cachedMediaQuery;

  @override
  void initState() {
    super.initState();
    _dataInit();
  }

  @override
  Widget build(BuildContext context) {
    _cachedTheme ??= Theme.of(context);
    _cachedMediaQuery ??= MediaQuery.of(context);

    return Container(
      child:
          widget.feedWidgetLayout == EFeedWidgetLayout.halfScreen
              ? _feedHalfItemWidget()
              : _feedFullItemWidget(),
    );
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    NotedUIModel? newNote = widget.notedUIModel;
    NotedUIModel? oldNote = oldWidget.notedUIModel;
    // Update if noteId changed or replyCount changed (to catch data updates)
    if (newNote?.noteDB.noteId != oldNote?.noteDB.noteId ||
        newNote?.noteDB.replyCount != oldNote?.noteDB.replyCount ||
        newNote?.noteDB.reactionCount != oldNote?.noteDB.reactionCount ||
        newNote != oldNote) {
      _dataInit();
    }
  }

  Border? get _bottomBorder =>
      widget.isShowBottomBorder
          ? Border(
            bottom: BorderSide(
              color: (_cachedTheme ?? Theme.of(context)).dividerColor.withAlpha(40),
              width: _borderWidth,
            ),
          )
          : null;

  Widget _buildFeedContainer({required Widget child}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => widget.clickMomentCallback?.call(notedUIModel),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(border: _bottomBorder),
        child: child,
      ),
    );
  }

  Widget _buildContentColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _feedUserInfoWidget().setPadding(
          EdgeInsets.only(left: 12 ,right: widget.horizontalPadding),
        ),
        _showReplyContactWidget().setPadding(
          EdgeInsets.only(left:  12 ,right: widget.horizontalPadding),
        ),
        _showFeedContent().setPadding(
          EdgeInsets.only(left: widget.isShowContentLeftPadding ? 12 : 0 ,right: widget.horizontalPadding),
        ),
        _showFeedMediaWidget().setPadding(
        EdgeInsets.only(left: widget.isShowContentLeftPadding ? 12 : 0 ,right: widget.horizontalPadding),
    ),
        FeedReplyAbbreviateWidget(
          notedUIModel: notedUIModel,
          isShowReplyWidget: widget.isShowReplyWidget,
        ).setPadding(
          EdgeInsets.only(left: 12 ,right: widget.horizontalPadding),
        ),
        if (widget.isShowOption)
          Container(
            child: FeedOptionWidget(
              key: ValueKey(
                notedUIModel?.noteDB.noteId ??
                    'option_${notedUIModel.hashCode}',
              ),
              notedUIModel: notedUIModel,
            ).setPaddingOnly(bottom: _verticalPadding),
          ).setPadding(
            EdgeInsets.only(left: 12 ,right: widget.horizontalPadding),
          ),
        if (widget.isShowSimpleReplyBtn)
          showSimpleReplyBtnWidget().setPadding(
            EdgeInsets.only(right: widget.horizontalPadding),
          ),
      ],
    );
  }

  Widget showSimpleReplyBtnWidget() {
    String? pubKey = notedUIModel?.noteDB.author;
    if (pubKey == null) return const SizedBox();
    UserDBISAR? user = Account.sharedInstance.getUserNotifier(pubKey).value;
    return Container(
      padding: EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Text(
            FeedUtils.getUserMomentInfo(user, notedUIModel!.createAtStr)[2],
            style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
                fontWeight: FontWeight.w400
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ).setPaddingOnly(right: 14.0),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          FeedReplyPage(notedUIModel: notedUIModel!),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;

                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);

                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                  reverseTransitionDuration: const Duration(milliseconds: 250),
                ),
              );
            },
            child: Text(
              'Reply',
              style: GoogleFonts.inter(
                color: kTitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w800
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedFullItemWidget() {
    if (notedUIModel == null) return const SizedBox();

    return _buildFeedContainer(child: _buildContentColumn());
  }

  Widget _buildAvatarWidget({String? imageUrl}) {
    return Container(
      child: GestureDetector(
        onTap: () {
          if (relayGroup != null) {
            // On web, if it's current user's page, switch to myPosts; otherwise push in nested Navigator
            if (kIsWeb) {
              final currentPubkey = Account.sharedInstance.currentPubkey;
              final isCurrentUser = relayGroup!.groupId == currentPubkey;
              
              if (isCurrentUser) {
                // Switch to myPosts page
                final homeState = context.findAncestorStateOfType<HomePageState>();
                if (homeState != null) {
                  homeState.switchToWebPage(WebContentPage.myPosts);
                  return;
                }
              } else {
                // For other users, push in nested Navigator
                final navigator = Navigator.of(context, rootNavigator: false);
                navigator.push(
                  MaterialPageRoute(
                    builder: (context) => FeedPersonalPage(relayGroupDB: relayGroup!),
                  ),
                );
                return;
              }
            }
            
            // Mobile: use normal navigation
            ChuChuNavigator.pushPage(
              context,
              (context) => FeedPersonalPage(relayGroupDB: relayGroup!),
            );
          } else {
            CommonToast.instance.show(context, "The creator couldn't be found" ,toastType:ToastType.failed);
          }
        },
        child: FeedWidgetsUtils.clipImage(
          borderRadius: _avatarSize,
          imageSize: _avatarSize,
          child: ChuChuCachedNetworkImage(
            imageUrl: imageUrl ?? '',
            fit: BoxFit.cover,
            placeholder: (_, __) => FeedWidgetsUtils.badgePlaceholderImage(),
            errorWidget:
                (_, __, ___) => FeedWidgetsUtils.badgePlaceholderImage(),
            width: _avatarSize,
            height: _avatarSize,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarColumn() {
    if (notedUIModel == null) return const SizedBox();
    return Column(
      children: [
        ValueListenableBuilder<UserDBISAR>(
          valueListenable: Account.sharedInstance.getUserNotifier(
            notedUIModel!.noteDB.author,
          ),
          builder: (context, user, child) {
            return _buildAvatarWidget(imageUrl: user.picture);
          },
        ),
        if (widget.isShowAllContent)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: _rightPadding),
              width: 1,
              color: Colors.grey.withOpacity(.5),
            ),
          ),
      ],
    );
  }

  Widget _feedHalfItemWidget() {
    if (notedUIModel == null) return const SizedBox();

    return _buildFeedContainer(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatarColumn(),
            Expanded(child: _buildContentColumn()),
          ],
        ),
      ),
    );
  }

  Widget _buildContentItem(
    String content,
    NotedUIModel model,
    List<String> nddrlList,
  ) {
    return Container(
      child:
          nddrlList.contains(content)
              ? MomentArticleWidget(naddr: content)
              : FeedRichTextWidget(
                isShowAllContent: widget.isShowAllContent,
                clickBlankCallback:
                    () => widget.clickMomentCallback?.call(model),
                showMoreCallback: () async {
                  await ChuChuNavigator.pushPage(
                    context,
                    (context) => FeedInfoPage(
                      notedUIModel: model,
                      isShowReply: widget.isShowReply,
                    ),
                  );
                },
                text: content,
              ).setPadding(EdgeInsets.only(bottom: _bottomSpacing)),
    );
  }

  Widget _showFeedContent() {
    final model = notedUIModel;
    if (model == null) return const SizedBox();

    final nddrlList = model.getNddrlList;
    final contentList = FeedUtils.momentContentSplit(model.noteDB.content);
    if (contentList.isEmpty) return const SizedBox();
    return Column(
      children:
          contentList
              .map((content) => _buildContentItem(content, model, nddrlList))
              .toList(),
    );
  }

  Widget _buildImageGrid(List<String> imageList) {
    return CarouselWidget(items: imageList);
  }

  Widget _buildVideoWidget(String videoUrl) {
    final isYoutube =
        videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be');
    return Container(
      child:
          isYoutube
              ? FeedWidgetsUtils.youtubeSurfaceMoment(context, videoUrl)
              : FeedVideoWidget(videoUrl: videoUrl)
              // .setPaddingOnly(right :widget.isShowContentLeftPadding ? 16 : 0),
    );
  }

  Widget _showFeedMediaWidget() {
    final model = notedUIModel;
    if (model == null) return const SizedBox();

    final imageList = model.getImageList;
    if (imageList.isNotEmpty) {
      return _buildImageGrid(imageList);
    }

    final videoList = model.getVideoList;
    if (videoList.isNotEmpty) {
      return _buildVideoWidget(videoList[0]);
    }

    final externalLinks = model.getMomentExternalLink;
    if (externalLinks.isNotEmpty) {
      return Container(child: FeedUrlWidget(url: externalLinks[0]));
    }

    return const SizedBox();
  }

  Widget _showReplyContactWidget() {
    if (!widget.isShowReply) return const SizedBox();
    return FeedReplyContactWidget(notedUIModel: notedUIModel);
  }

  Widget _buildUserNameAndTime(RelayGroupDBISAR user, NotedUIModel model) {
    String getUserNupbStr() {
      String nupKey = Nip19.encodePubkey(model.noteDB.author);
      return '${nupKey.substring(0, 6)}:${nupKey.substring(nupKey.length - 6)}';
    }

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  user.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kTitleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Text(
                    model.createAtStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // CommonImage(
                  //   iconName: 'more_icon.png',
                  //   size: 24,
                  // ).setPaddingOnly(left: 13.0),
                ],
              ),

              // _checkIsPrivate(),
            ],
          ),
          Text(
            getUserNupbStr(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow() {
    final model = notedUIModel;
    if (model == null) return const SizedBox();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.feedWidgetLayout == EFeedWidgetLayout.fullScreen)
          GestureDetector(
            onTap: () async {},
            child: ValueListenableBuilder<UserDBISAR>(
              valueListenable: Account.sharedInstance.getUserNotifier(
                model.noteDB.author,
              ),
              builder: (context, user, child) {
                return _buildAvatarWidget(imageUrl: user.picture);
              },
            ),
          ).setPaddingOnly(right: _rightPadding),
        ValueListenableBuilder<RelayGroupDBISAR>(
          valueListenable: RelayGroup.sharedInstance.getRelayGroupNotifier(
            model.noteDB.author,
          ),
          builder: (context, user, child) {
            return _buildUserNameAndTime(user, model);
          },
        ),
      ],
    );
  }

  Widget _feedUserInfoWidget() {
    final model = notedUIModel;
    if (model == null || !widget.isShowUserInfo) return const SizedBox();

    return Container(
      padding: EdgeInsets.only(bottom: 6),
      child: _buildUserInfoRow(),
    );
  }

  Future<void> _dataInit() async {
    final model = widget.notedUIModel;
    if (model == null) return;
    notedUIModel = model;
    getRelayGroup();

    await _getFeedUserInfo(model);

    Future.microtask(() {
      if (mounted) setState(() {});
    });
  }

  void getRelayGroup() {
    Map<String, ValueNotifier<RelayGroupDBISAR>> groupMap =
        RelayGroup.sharedInstance.groups;
    if (groupMap[widget.notedUIModel?.noteDB.author] != null) {
      relayGroup = groupMap[widget.notedUIModel?.noteDB.author]!.value;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _getFeedUserInfo(NotedUIModel model) async {
    final pubKey = model.noteDB.author;
    await Account.sharedInstance.getUserInfo(pubKey);
  }
}
