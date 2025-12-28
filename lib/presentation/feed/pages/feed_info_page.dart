import 'package:chuchu/core/feed/feed+load.dart';
import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/feed/feed.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import 'package:nostr_core_dart/src/ok.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feed_utils.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/navigator/navigator_observer_mixin.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../data/enum/feed_enum.dart';
import '../../../data/models/feed_extension_model.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../widgets/feed_widget.dart';
import '../widgets/feed_option_widget.dart';
import '../pages/feed_reply_page.dart';

class FeedInfoPage extends StatefulWidget {
  final bool isShowReply;
  final NotedUIModel? notedUIModel;
  const FeedInfoPage({
    super.key,
    required this.notedUIModel,
    this.isShowReply = true,
  });

  @override
  State<FeedInfoPage> createState() => _FeedInfoPageState();
}

class _FeedInfoPageState extends State<FeedInfoPage>
    with NavigatorObserverMixin, ChuChuUIRefreshMixin {
  final GlobalKey _replyListContainerKey = GlobalKey();
  final GlobalKey _containerKey = GlobalKey();

  final ScrollController _scrollController = ScrollController();

  final bool _isShowMask = false;

  List<NotedUIModel?> replyList = [];

  bool scrollTag = false;
  
  NotedUIModel? _currentNotedUIModel;

  NotedUIModel? get _currentModel => _currentNotedUIModel ?? widget.notedUIModel;

  @override
  void initState() {
    super.initState();
    _currentNotedUIModel = widget.notedUIModel;
    _updateNotedModel();
    _getReplyList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToPosition(double offset) {
    if (!scrollTag) {
      scrollTag = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(offset);
        }
      });
    }
  }

  @override
  Future<void> didPopNext() async {
    _updateNoted();
  }

  void _updateNotedModel() async {
    if (widget.notedUIModel == null) return;
    String noteId = widget.notedUIModel!.noteDB.noteId;

    NotedUIModel? noteNotifier =
        await ChuChuFeedCacheManager.getValueNotifierNoted(
          noteId,
          isUpdateCache: true,
          notedUIModel: widget.notedUIModel,
        );

    if (noteNotifier != null && mounted) {
      setState(() {
        _currentNotedUIModel = noteNotifier;
      });
    }
  }

  void _updateNoted() async {
    if (_currentModel == null) return;
    NotedUIModel notedUIModel = _currentModel!;
    String noteId = notedUIModel.noteDB.noteId;

    NotedUIModel? noteNotifier =
        await ChuChuFeedCacheManager.getValueNotifierNoted(
          noteId,
          isUpdateCache: true,
          notedUIModel: notedUIModel,
        );

    if (noteNotifier == null) return;
    
    // Update current model
    if (mounted) {
      setState(() {
        _currentNotedUIModel = noteNotifier;
      });
    }
    
    int newReplyNum = noteNotifier.noteDB.replyEventIds?.length ?? 0;
    if (newReplyNum > replyList.length) {
      _getReplyList();
    }
  }

  Future<void> _handleLikeTap() async {
    final noteDB = _currentModel?.noteDB;
    if (noteDB == null) return;

    // Prevent double tap
    if (noteDB.reactionCountByMe > 0) return;

    bool isSuccess = false;
    try {
      OKEvent event = await RelayGroup.sharedInstance.sendGroupNoteReaction(
        noteDB.noteId,
      );
      isSuccess = event.status;
    } catch (e) {
      debugPrint('Error sending reaction: $e');
      isSuccess = false;
    }

    _dealWithReaction(isSuccess);
  }

  void _dealWithReaction(bool isSuccess) {
    if (isSuccess) {
      _updateNoteDB();
      CommonToast.instance.show(context, 'Like success tips',toastType:ToastType.success);
    } else {
      CommonToast.instance.show(context, 'Like fail tips',toastType:ToastType.failed);
    }
  }

  void _handleCommentTap() async {
    if (_currentModel == null) return;

    // Navigate to comment page
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                FeedReplyPage(notedUIModel: _currentModel!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      ),
    );

    if (result != null && result) {
      _updateNoted();
      // Also update the model to get latest replyCountByMe
      _updateNotedModel();
    }
  }

  void _handleZapTap() {
    if (_currentModel == null) return;

    // Show zap dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Send Zap'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Send a zap to support this post?'),
              SizedBox(height: 16),
              Text(
                'Current zap amount: \$${(_currentModel!.noteDB.zapAmount / 100000000.0).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                CommonToast.instance.show(
                  context,
                  'Zap functionality coming soon',
                    toastType:ToastType.info
                );
                // You can implement zap functionality here
              },
              child: Text('Send Zap'),
            ),
          ],
        );
      },
    );
  }

  void _updateNoteDB() async {
    if (_currentModel == null) return;

    try {
      NotedUIModel? noteNotifier =
          await ChuChuFeedCacheManager.getValueNotifierNoted(
            _currentModel!.noteDB.noteId,
            isUpdateCache: true,
            notedUIModel: _currentModel,
          );

      if (noteNotifier != null && mounted) {
        setState(() {
          _currentNotedUIModel = noteNotifier;
        });
      }
    } catch (e) {
      debugPrint('Error updating note DB: $e');
    }
  }

  Future _getReplyList() async {
    _getReplyFromDB();
    _getReplyFromRelay();
  }

  void _getReplyFromRelay() async {
    if (_currentModel == null) return;
    String notedId = _currentModel!.noteDB.noteId;
    await Feed.sharedInstance.loadNoteActions(
      notedId,
      actionsCallBack: (result) async {
        NotedUIModel? noteNotifier =
            await ChuChuFeedCacheManager.getValueNotifierNoted(
              notedId,
              isUpdateCache: true,
              notedUIModel: _currentModel,
            );
        if (noteNotifier == null) return;
        _getReplyFromDB();
      },
    );
  }

  void _getReplyFromDB() async {
    if (_currentModel == null) return;
    String noteId = _currentModel!.noteDB.noteId;

    NotedUIModel? preNoteNotifier =
        ChuChuFeedCacheManager.getValueNotifierNoteToCache(noteId);

    if (preNoteNotifier == null) {
      preNoteNotifier = await ChuChuFeedCacheManager.getValueNotifierNoted(
        noteId,
        isUpdateCache: true,
      );
      if (preNoteNotifier == null) return;
    }

    List<String>? replyEventIds = preNoteNotifier.noteDB.replyEventIds;
    if (replyEventIds == null) return;

    List<NotedUIModel?> resultList = [];
    for (String noteId in replyEventIds) {
      NotedUIModel? noteNotifier =
          await ChuChuFeedCacheManager.getValueNotifierNoted(
            noteId,
            isUpdateCache: true,
          );
      if (noteNotifier != null) resultList.add(noteNotifier);
    }

    replyList = resultList;

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).requestFocus(FocusNode());
      },
      child: Scaffold(
        backgroundColor: kBgLight,
        appBar: AppBar(
          leadingWidth: 30,
          title: Row(
            children: [
              GestureDetector(
                onTap: () {
                  // if(notedUIModel != null){
                  //   ChuChuNavigator.pushPage(context, (context) => FeedPersonalPage(userPubkey: notedUIModel!.noteDB.author,));
                  // }
                },
                child: ValueListenableBuilder<UserDBISAR>(
                  valueListenable: Account.sharedInstance.getUserNotifier(
                    _currentModel?.noteDB.author ?? '',
                  ),
                  builder: (context, value, child) {
                    return FeedWidgetsUtils.clipImage(
                      borderRadius: 32,
                      imageSize: 32,
                      child: ChuChuCachedNetworkImage(
                        imageUrl: value.picture ?? '',
                        fit: BoxFit.cover,
                        placeholder:
                            (_, __) =>
                                FeedWidgetsUtils.badgePlaceholderImage(),
                        errorWidget:
                            (_, __, ___) =>
                                FeedWidgetsUtils.badgePlaceholderImage(),
                        width: 32,
                        height: 32,
                      ),
                    );
                  },
                ),
              ).setPaddingOnly(right: 12.0),
              Expanded(
                child: ValueListenableBuilder<RelayGroupDBISAR>(
                  valueListenable: RelayGroup.sharedInstance
                      .getRelayGroupNotifier(
                        _currentModel?.noteDB.author ?? '',
                      ),
                  builder: (context, value, child) {
                    return Text(
                      value.name,
                      style: GoogleFonts.inter(
                        color: kTitleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
            ],
          ),
          backgroundColor: kBgLight,
          foregroundColor: theme.colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        body: SizedBox(
          height: double.infinity,
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        width: 0.5,
                        color: Theme.of(
                          context,
                        ).dividerColor.withOpacity(0.2),
                      ),
                    ),
                  ),
                  padding: EdgeInsets.only(bottom: 120,top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NotificationListener<SizeChangedLayoutNotification>(
                        onNotification: (notification) {
                          final RenderBox renderBox =
                              _containerKey.currentContext?.findRenderObject()
                                  as RenderBox;
                          final size = renderBox.size;
                          _scrollToPosition(size.height - 15);
                          return true;
                        },
                        child: SizeChangedLayoutNotifier(
                          child: Container(
                            key: _containerKey,
                            child: MomentRootNotedWidget(
                              notedUIModel: _currentModel,
                              isShowReply: widget.isShowReply,
                            ),
                          ),
                        ),
                      ).setPadding(EdgeInsets.symmetric(horizontal: 24.0)),
                      FeedWidget(
                        isShowAllContent: true,
                        isShowReply: false,
                        notedUIModel: _currentModel,
                        isShowBottomBorder: false,
                        feedWidgetLayout: EFeedWidgetLayout.fullScreen,
                        isShowOption: false,
                      ).setPadding(
                        EdgeInsets.only(left: 12.0, right: 24.0, top: 8.0),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 0.5,
                              color: Colors.grey.withOpacity(.2),
                            ),
                          ),
                        ),
                      ),
                      if (replyList.isNotEmpty)
                        Container(
                          padding: EdgeInsets.only(left: 16, top: 16),
                          child: Text(
                            '${replyList.length} comments',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      _showReplyList(),
                      _noDataWidget(),
                      SizedBox(height: 500),
                    ],
                  ),
                ),
              ),
              _isShowMaskWidget(),
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _showReplyList() {
    if (replyList.isEmpty) return const SizedBox();

    List<Widget> list =
        replyList.map((NotedUIModel? notedUIModelDraft) {
          if (notedUIModelDraft == null) {
            return const SizedBox();
          }
          int index = replyList.indexOf(notedUIModelDraft);
          NoteDBISAR? draftModel = notedUIModelDraft.noteDB;
          NoteDBISAR? currentModelDB = _currentModel?.noteDB;

          if (draftModel.noteId == currentModelDB?.noteId && index != 0) {
            return const SizedBox();
          }
          if (!draftModel.isFirstLevelReply(currentModelDB?.noteId)) {
            return const SizedBox();
          }
          return MomentReplyWrapWidget(
            index: index,
            notedUIModel: notedUIModelDraft,
          );
        }).toList();

    return Container(
      key: _replyListContainerKey,
      child: Column(
        children:
            list.map((widget) {
              return Container(
                padding: EdgeInsets.only(top: 12.0),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 0.5,
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                    ),
                  ),
                ),
                child: widget,
              );
            }).toList(),
      ),
    );
  }

  Widget _isShowMaskWidget() {
    if (!_isShowMask) return const SizedBox();
    return Container(
      height: double.infinity,
      width: double.infinity,
      color: Colors.transparent,
    );
  }

  Widget _noDataWidget() {
    if (replyList.isNotEmpty) return const SizedBox();
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            CommonImage(iconName: 'no_reply_ill_icon.png', size: 220),
            const SizedBox(height: 24),
            Text(
              'No comments yet',
              style: GoogleFonts.inter(
                fontSize: 25,
                color: kTitleColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share your thoughts',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    if (_currentModel == null) return const SizedBox();

    final noteDB = _currentModel!.noteDB;
    final likeCount = noteDB.reactionCount;
    final commentCount = noteDB.replyCount;
    final zapAmount = noteDB.zapAmount / 100000000.0; // Convert sats to BTC

    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    bool isLikeByMe = noteDB.reactionCountByMe > 0;
    bool isReplyByMe = noteDB.replyCountByMe > 0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Message button
                // GestureDetector(
                //   onTap: _handleMessageTap,
                //   child: Container(
                //     width: 200,
                //     height: 48,
                //     decoration: BoxDecoration(
                //       color: Colors.grey.withOpacity(0.1),
                //       borderRadius: BorderRadius.circular(24),
                //     ),
                //     child: Center(
                //       child: Text(
                //         'Message',
                //         style: TextStyle(
                //           color: Colors.grey.shade700,
                //           fontSize: 16,
                //           fontWeight: FontWeight.w500,
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildEngagementItem(
                        type: EFeedOptionType.like,
                        isSelect: isLikeByMe,
                        iconName:
                            isLikeByMe ? 'liked_icon.png' : 'like_icon.png',
                        value: likeCount.toString(),
                        onTap: _handleLikeTap,
                      ),
                      SizedBox(width: 16),
                      _buildEngagementItem(
                        type: EFeedOptionType.reply,
                        isSelect: isReplyByMe,
                        iconName: isReplyByMe ? 'replyed_icon.png' : 'reply_icon.png',
                        value: commentCount.toString(),
                        onTap: _handleCommentTap,
                      ),
                      SizedBox(width: 16),
                      _buildEngagementItem(
                        type: EFeedOptionType.zaps,
                        iconName: 'zap_icon.png',
                        value: '0',
                        isMonetary: true,
                        onTap: () {
                          CommonToast.instance.show(context, 'Zap coming soon',toastType:ToastType.info);
                        },
                        // _handleZapTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementItem({
    required EFeedOptionType type,
    required String iconName,
    required String value,
    bool isSelect = false,
    bool isMonetary = false,
    VoidCallback? onTap,
  }) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CommonImage(
          iconName: iconName,
          size: 20,
          color: isSelect ? null : Theme.of(context).colorScheme.onSurface,
        ),
        SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            color:
                isSelect ? type.selectColor : Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: content,
        ),
      );
    }

    return content;
  }
}

class MomentRootNotedWidget extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  final bool isShowReply;
  const MomentRootNotedWidget({
    super.key,
    required this.notedUIModel,
    required this.isShowReply,
  });

  @override
  State<MomentRootNotedWidget> createState() => MomentRootNotedWidgetState();
}

class MomentRootNotedWidgetState extends State<MomentRootNotedWidget> {
  List<NotedUIModel?>? notedReplyList;

  @override
  void initState() {
    super.initState();
    _dealWithNoted();
  }

  void _dealWithNoted() async {
    if (widget.notedUIModel == null || widget.notedUIModel == null) return;
    await Future.delayed(Duration.zero);
    if (mounted) {
      setState(() {});
    }

    notedReplyList = [];
    await _getReplyNoted(widget.notedUIModel!);
  }

  Future _getReplyNoted(NotedUIModel? model) async {
    String replyId = model?.noteDB.getReplyId ?? '';
    if (replyId.isNotEmpty) {
      NotedUIModel? replyNotifier =
          await ChuChuFeedCacheManager.getValueNotifierNoted(
            replyId,
            isUpdateCache: true,
            notedUIModel: model,
          );
      notedReplyList = [
        ...[replyNotifier],
        ...notedReplyList!,
      ];
      _getReplyNoted(replyNotifier);
    } else {
      _updateReply(notedReplyList ?? []);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _updateReply(List<NotedUIModel?> notedReplyList) async {
    if (notedReplyList.isEmpty) return;
    for (NotedUIModel? noted in notedReplyList) {
      if (noted == null) {
        continue;
      }
      String notedId = noted.noteDB.noteId;
      await Feed.sharedInstance.loadNoteActions(
        notedId,
        actionsCallBack: (result) async {},
      );
      NotedUIModel? noteNotifier =
          await ChuChuFeedCacheManager.getValueNotifierNoted(
            notedId,
            isUpdateCache: true,
            notedUIModel: noted,
          );

      if (noteNotifier == null) return;
      noted = noteNotifier;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showContentWidget();
  }

  Widget _showContentWidget() {
    if (widget.notedUIModel == null || notedReplyList == null) {
      return const SizedBox();
    }

    String replyId = widget.notedUIModel?.noteDB.getReplyId ?? '';
    if (notedReplyList!.isEmpty && replyId.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FeedWidgetsUtils.emptyNoteMomentWidget(null, 100),
          Container(
            margin: EdgeInsets.only(left: 20),
            width: 1,
            height: 20,
            color: Colors.grey.withOpacity(.5),
          ),
        ],
      );
    }

    return Column(
      children:
          notedReplyList!.map((model) {
            return _showMomentWidget(model);
          }).toList(),
    );
  }

  Widget _showMomentWidget(NotedUIModel? modelNotifier) {
    if (modelNotifier == null) {
      return FeedWidgetsUtils.emptyNoteMomentWidget(null, 100);
    }
    return FeedWidget(
      isShowAllContent: true,
      isShowReply: false,
      isShowBottomBorder: false,
      clickMomentCallback: (NotedUIModel? notedUIModel) async {
        await ChuChuNavigator.pushPage(
          context,
          (context) => FeedInfoPage(notedUIModel: notedUIModel),
        );
      },
      notedUIModel: modelNotifier,
    ).setPaddingOnly(top: 8.0);
  }
}

class MomentReplyWrapWidget extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  final int index;

  const MomentReplyWrapWidget({
    super.key,
    required this.notedUIModel,
    required this.index,
  });

  @override
  State<MomentReplyWrapWidget> createState() => MomentReplyWrapWidgetState();
}

class MomentReplyWrapWidgetState extends State<MomentReplyWrapWidget> {
  NotedUIModel? firstReplyNoted;
  NotedUIModel? secondReplyNoted;
  NotedUIModel? thirdReplyNoted;

  bool isShowRepliesWidget = false;

  @override
  void initState() {
    super.initState();
    _getReplyList(widget.notedUIModel, 0);
  }

  void _getReplyList(NotedUIModel? noteModelDraft, int index) async {
    _getReplyFromDB(noteModelDraft, index);
    _getReplyFromRelay(noteModelDraft, index);
  }

  void _getReplyFromRelay(NotedUIModel? notedUIModelDraft, int index) async {
    String? noteId = notedUIModelDraft?.noteDB.noteId;
    if (noteId == null) return;
    await Feed.sharedInstance.loadNoteActions(
      noteId,
      actionsCallBack: (result) async {
        NotedUIModel? noteNotifier =
            await ChuChuFeedCacheManager.getValueNotifierNoted(
              noteId,
              isUpdateCache: true,
              notedUIModel: notedUIModelDraft,
            );

        if (noteNotifier == null) return;

        if (mounted) {
          setState(() {});
        }
        _getReplyFromDB(noteNotifier, index);
      },
    );
  }

  void _getReplyFromDB(NotedUIModel? notedUIModelDraft, int index) async {
    List<String>? replyEventIds = notedUIModelDraft?.noteDB.replyEventIds;
    if (replyEventIds == null || replyEventIds.isEmpty) return;

    String noteId = replyEventIds[0];

    NotedUIModel? replyNotifier =
        ChuChuFeedCacheManager.getValueNotifierNoteToCache(noteId);

    replyNotifier ??= await ChuChuFeedCacheManager.getValueNotifierNoted(
      noteId,
      isUpdateCache: true,
    );

    if (replyNotifier == null) return;

    if (index == 0) {
      firstReplyNoted = replyNotifier;
      _getReplyList(firstReplyNoted!, 1);
    }

    if (index == 1) {
      secondReplyNoted = replyNotifier;
      isShowRepliesWidget = true;
      _getReplyList(secondReplyNoted!, 2);
    }

    if (index == 2) {
      thirdReplyNoted = replyNotifier;
      _getReplyList(thirdReplyNoted!, 3);
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MomentReplyWidget(
          notedUIModel: widget.notedUIModel,
          isShowLink: firstReplyNoted != null,
        ),
        Container(
          padding: EdgeInsets.only(left: 50.0),
          child: Column(
            children: [
              _firstReplyWidget(),
              _secondReplyWidget(),
              _thirdReplyWidget(),
              _showRepliesWidget(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _firstReplyWidget() {
    if (firstReplyNoted == null) return const SizedBox();
    return MomentReplyWidget(
      notedUIModel: firstReplyNoted!,
      isShowLink: secondReplyNoted != null,
    );
  }

  Widget _secondReplyWidget() {
    if (secondReplyNoted == null || isShowRepliesWidget) {
      return const SizedBox();
    }

    return MomentReplyWidget(
      notedUIModel: secondReplyNoted!,
      isShowLink: thirdReplyNoted != null,
    );
  }

  Widget _thirdReplyWidget() {
    if (thirdReplyNoted == null || isShowRepliesWidget) return const SizedBox();
    return MomentReplyWidget(notedUIModel: thirdReplyNoted!);
  }

  Widget _showRepliesWidget() {
    if (!isShowRepliesWidget) return const SizedBox();
    return GestureDetector(
      onTap: () {
        isShowRepliesWidget = false;
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.only(left: 30, bottom: 24, top: 8),
        child: Row(
          children: [
            Icon(
              Icons.more_vert,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Text(
              'Show reply',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MomentReplyWidget extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  final bool isShowLink;

  const MomentReplyWidget({
    super.key,
    required this.notedUIModel,
    this.isShowLink = false,
  });

  @override
  State<MomentReplyWidget> createState() => _MomentReplyWidgetState();
}

class _MomentReplyWidgetState extends State<MomentReplyWidget> {
  @override
  void initState() {
    super.initState();
    _getMomentUserInfo();
  }

  @override
  Widget build(BuildContext context) {
    return _momentItemWidget();
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notedUIModel != oldWidget.notedUIModel) {
      _getMomentUserInfo();
    }
  }

  void _getMomentUserInfo() async {
    if (widget.notedUIModel == null) return;
    String pubKey = widget.notedUIModel!.noteDB.author;
    await Account.sharedInstance.getUserInfo(pubKey);
  }

  Widget _momentItemWidget() {
    if (widget.notedUIModel == null) return const SizedBox();
    String pubKey = widget.notedUIModel!.noteDB.author;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () async {
        ChuChuNavigator.pushPage(
          context,
          (context) => FeedInfoPage(
            notedUIModel: widget.notedUIModel,
            isShowReply: false,
          ),
        );
      },
      child: IntrinsicHeight(
        child: ValueListenableBuilder<UserDBISAR>(
          valueListenable: Account.sharedInstance.getUserNotifier(pubKey),
          builder: (context, value, child) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    FeedWidgetsUtils.clipImage(
                      borderRadius: 40,
                      imageSize: 40,
                      child: GestureDetector(
                        onTap: () {},
                        child: ChuChuCachedNetworkImage(
                          imageUrl: value.picture ?? '',
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  FeedWidgetsUtils.badgePlaceholderImage(),
                          errorWidget:
                              (context, url, error) =>
                                  FeedWidgetsUtils.badgePlaceholderImage(),
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                    // if (widget.isShowLink)
                    //   Expanded(
                    //     child: Container(
                    //       margin: EdgeInsets.symmetric(vertical: 4.px),
                    //       width: 1.0,
                    //       color: Theme.of(context).dividerColor.withOpacity(0.3),
                    //     ),
                    //   ),
                  ],
                ).setPaddingOnly(right: 8.0),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 0.5,
                          color: Theme.of(
                            context,
                          ).dividerColor.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _momentUserInfoWidget(value),
                              const SizedBox(height: 17,),
                              FeedWidget(
                                feedWidgetLayout: EFeedWidgetLayout.fullScreen,
                                isShowAllContent: false,
                                isShowBottomBorder: false,
                                isShowReply: false,
                                isShowSimpleReplyBtn: true,
                                notedUIModel: widget.notedUIModel,
                                isShowUserInfo: false,
                                isShowOption: false,
                                isShowContentLeftPadding:false,
                                clickMomentCallback: (
                                  NotedUIModel? notedUIModel,
                                ) async {
                                  await ChuChuNavigator.pushPage(
                                    context,
                                    (context) => FeedInfoPage(
                                      notedUIModel: widget.notedUIModel,
                                      isShowReply: false,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        ReusableInteractionButtons(
                          notedUIModel: widget.notedUIModel,
                          iconSize: 16,
                          fontSize: 14,
                          textColor: Theme.of(context).colorScheme.outline,
                          showComment: false,
                          showZap: false,
                          showBookmark: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).setPaddingOnly(left: 18.0, right: 18.0, top: 12.0);
  }

  Widget _momentUserInfoWidget(UserDBISAR userDB) {
    if (widget.notedUIModel == null) return const SizedBox();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                userDB.name ?? '--',
                style: GoogleFonts.inter(
                  color: kTitleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Text(
          FeedUtils.getUserMomentInfo(
            userDB,
            widget.notedUIModel!.createAtStr,
          )[1],
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
