import 'package:chuchu/core/feed/feed+load.dart';
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:chuchu/core/widgets/chuchu_Loading.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import '../../../core/config/config.dart';
import '../../../core/feed/feed.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import 'package:nostr_core_dart/src/ok.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../data/enum/feed_enum.dart';
import '../../../data/models/feed_extension_model.dart';
import '../../../data/models/noted_ui_model.dart';
import '../pages/feed_reply_page.dart';

class FeedOptionWidget extends StatefulWidget {

  final NotedUIModel? notedUIModel;

  const FeedOptionWidget({super.key,this.notedUIModel});
  @override
  State createState() => _FeedOptionWidgetState();
}

class _FeedOptionWidgetState extends State<FeedOptionWidget> {
  bool _reactionTag = false;
  bool _isLiking = false; // Track like operation loading state

  late NotedUIModel? notedUIModel;

  final List<EFeedOptionType> feedOptionTypeList = [
    EFeedOptionType.reply,
    EFeedOptionType.like,
    EFeedOptionType.zaps,
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(FeedOptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update when notedUIModel changes (including noteId or replyCount changes)
    if (widget.notedUIModel?.noteDB.noteId != oldWidget.notedUIModel?.noteDB.noteId ||
        widget.notedUIModel?.noteDB.replyCount != oldWidget.notedUIModel?.noteDB.replyCount ||
        widget.notedUIModel?.noteDB.reactionCount != oldWidget.notedUIModel?.noteDB.reactionCount) {
      _init(isUpdate: false);
    }
  }

  void _init({bool isUpdate = false}) async{
    if(widget.notedUIModel == null) return;
    if(!isUpdate){
      notedUIModel = widget.notedUIModel;
    }else{
      NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(widget.notedUIModel!.noteDB.noteId, relays: Config.sharedInstance.recommendGroupRelays);
      if(note != null){
        notedUIModel = NotedUIModel(noteDB: note);
      }
    }


    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {},
      child: Row(
        children: [
          Flexible(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: feedOptionTypeList.map((EFeedOptionType type) {
                return _showItemWidget(type);
              }).toList(),
            ),
          ),
          Flexible(
            flex: 1, // 25%
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _onBookmarkTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CommonImage(iconName: 'bookmark_icon.png',size: 18,),
                ),
              ),
            ),
          ),
        ]
      ),
    );
  }

  Widget _showItemWidget(EFeedOptionType type) {
    Widget iconTextWidget = _iconTextWidget(
      type: type,
      isSelect: _isClickByMe(type),
      onTap: () => _onTapCallback(type)(),
      onLongPress: () => _onLongPress(type)(),
      clickNum: _getClickNum(type),
    );

    return iconTextWidget;
  }

  GestureTapCallback _onTapCallback(EFeedOptionType type) {
    NoteDBISAR? noteDB = notedUIModel?.noteDB;
    if(noteDB == null) return (){};
    switch (type) {
      case EFeedOptionType.reply:
        return () async {
         final result = await  Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => FeedReplyPage(notedUIModel:notedUIModel!),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;

                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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

         if(result != null && result){
           _init(isUpdate: true);
         }
        };
      case EFeedOptionType.like:
        return () async {
          // Prevent loading state
          if (_isLiking) return;
          
          // Check if already liked
          if (noteDB.reactionCountByMe > 0 || _reactionTag) {
            CommonToast.instance.show(context, 'You have already liked this post', toastType: ToastType.info);
            return;
          }
          
          // Show loading
          setState(() {
            _isLiking = true;
          });
          ChuChuLoading.show();
          
          bool isSuccess = false;
          try {
            OKEvent event = await RelayGroup.sharedInstance.sendGroupNoteReaction(noteDB.noteId);
            isSuccess = event.status;
          } catch (e) {
            debugPrint('Error sending reaction: $e');
            isSuccess = false;
          } finally {
            // Hide loading
            ChuChuLoading.dismiss();
            if (mounted) {
              setState(() {
                _isLiking = false;
              });
            }
          }
          _dealWithReaction(isSuccess);
        };
      case EFeedOptionType.zaps:
        return (){
          CommonToast.instance.show(context, 'Zap coming soon',toastType:ToastType.info);

        };
    }
  }

  void _dealWithReaction(bool isSuccess){
    if (isSuccess) {
      // Only update state after loading is dismissed
      if (mounted) {
        setState(() {
          _reactionTag = true;
        });
      }
      _updateNoteDB();
      CommonToast.instance.show(context, 'Like success tips',toastType:ToastType.success);
    }else{
      CommonToast.instance.show(context, 'Like fail tips',toastType:ToastType.failed);
    }
  }

  void _onBookmarkTap() {
    CommonToast.instance.show(context, 'Bookmarks coming soon',toastType:ToastType.info);
    // setState(() {
    //   _bookmarkTag = !_bookmarkTag;
    // });
    //
    // if (_bookmarkTag) {
    //   CommonToast.instance.show(context, 'Bookmarked');
    // } else {
    //   CommonToast.instance.show(context, 'Bookmark removed');
    // }
  }


  void _updateNoteDB() async {
    if(notedUIModel == null)  return;
    NotedUIModel? noteNotifier = await ChuChuFeedCacheManager.getValueNotifierNoted(
      notedUIModel!.noteDB.noteId,
      isUpdateCache: true,
      notedUIModel: notedUIModel,
    );

    if(noteNotifier == null) return;
    if(mounted){
      notedUIModel = noteNotifier;
    }

  }

  GestureLongPressCallback _onLongPress(EFeedOptionType type) {
    return () => {};
  }

  Widget _iconTextWidget({
    required EFeedOptionType type,
    required bool isSelect,
    GestureTapCallback? onTap,
    GestureLongPressCallback? onLongPress,
    int? clickNum,
  }) {
    final content =
        clickNum == null || clickNum == 0 ? '' : clickNum.toString();
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.translucent,
      onTap: () => onTap?.call(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 7.0),
            child: CommonImage(iconName: _mapIconData(type, isSelect),  size: 18,),
          ),
          Text(
            content,
            style: GoogleFonts.inter(
              color: isSelect ? type.selectColor : Theme.of(context).colorScheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _getClickNum(EFeedOptionType type) {
    // Use widget.notedUIModel as primary source (from parent's notesList)
    // If internal state exists and has newer data (after user action), use it temporarily
    // until parent updates notesList through didNewNotesCallBackCallBack
    NoteDBISAR? noteDB = widget.notedUIModel?.noteDB;
    
    // If we have internal state with same noteId and it might be newer, check it
    if (notedUIModel != null && 
        noteDB != null && 
        notedUIModel!.noteDB.noteId == noteDB.noteId) {
      // Compare counts to see if internal state is newer
      int widgetCount = 0;
      int internalCount = 0;
      switch(type){
        case EFeedOptionType.like:
          widgetCount = noteDB.reactionCount;
          internalCount = notedUIModel!.noteDB.reactionCount;
          break;
        case EFeedOptionType.zaps:
          widgetCount = noteDB.zapAmount;
          internalCount = notedUIModel!.noteDB.zapAmount;
          break;
        case EFeedOptionType.reply:
          widgetCount = noteDB.replyCount;
          internalCount = notedUIModel!.noteDB.replyCount;
          break;
      }
      // Use internal if it has higher count (user action updated it)
      if (internalCount > widgetCount) {
        noteDB = notedUIModel!.noteDB;
      }
    }
    
    if(noteDB == null) return 0;
    switch(type){
      case EFeedOptionType.like:
        return noteDB.reactionCount;
      case EFeedOptionType.zaps:
        return noteDB.zapAmount;
      case EFeedOptionType.reply:
        return noteDB.replyCount;
    }
  }

  bool _isClickByMe(EFeedOptionType type) {
    // Always use widget.notedUIModel as the source of truth
    NoteDBISAR? noteDB = widget.notedUIModel?.noteDB;
    if(noteDB == null) return false;
    switch(type){
      case EFeedOptionType.like:
        // Don't show as liked during loading
        if (_isLiking) return false;
        return _reactionTag ? _reactionTag : noteDB.reactionCountByMe > 0;
      case EFeedOptionType.zaps:
        return noteDB.zapAmountByMe > 0;
      case EFeedOptionType.reply:
        return noteDB.replyCountByMe > 0;
    }
  }

  String _mapIconData(EFeedOptionType type, bool isSelect) {
    switch (type) {
      case EFeedOptionType.reply:
        return isSelect ? EFeedOptionType.reply.getSelectIconName : EFeedOptionType.reply.getIconName;
      case EFeedOptionType.like:
        return isSelect ? EFeedOptionType.like.getSelectIconName : EFeedOptionType.like.getIconName;
      case EFeedOptionType.zaps:
        return isSelect ? EFeedOptionType.zaps.getSelectIconName : EFeedOptionType.zaps.getIconName;
    }
  }
}

/// Reusable like button component that can be used across different pages
class ReusableLikeButton extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  final double? iconSize;
  final double? fontSize;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool showCount;

  const ReusableLikeButton({
    super.key,
    required this.notedUIModel,
    this.iconSize = 24,
    this.fontSize = 18,
    this.textColor,
    this.onTap,
    this.showCount = true,
  });

  @override
  State<ReusableLikeButton> createState() => _ReusableLikeButtonState();
}

class _ReusableLikeButtonState extends State<ReusableLikeButton> {
  bool _reactionTag = false;
  bool _isLiking = false; // Track like operation loading state

  @override
  void initState() {
    super.initState();
    _initReactionState();
  }

  void _initReactionState() {
    if (widget.notedUIModel?.noteDB.reactionCountByMe != null) {
      _reactionTag = widget.notedUIModel!.noteDB.reactionCountByMe > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = _isLiked();
    final likeCount = _getLikeCount();

    return GestureDetector(
      onTap: widget.onTap ?? _handleLikeTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: widget.showCount ? 2.0 : 0.0),
            child: CommonImage(
              iconName: isLiked ? 'liked_icon.png' : 'like_icon.png',
              size: widget.iconSize ?? 16,
            ),
          ),
          if (widget.showCount)
            Text(
              likeCount.toString(),
              style: GoogleFonts.inter(
                fontSize: widget.fontSize ?? 12,
                color: isLiked ? kPrimary : Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  bool _isLiked() {
    final noteDB = widget.notedUIModel?.noteDB;
    if (noteDB == null) return false;
    // Don't show as liked during loading
    if (_isLiking) return false;
    return _reactionTag || noteDB.reactionCountByMe > 0;
  }

  int _getLikeCount() {
    final noteDB = widget.notedUIModel?.noteDB;
    return noteDB?.reactionCount ?? 0;
  }

  Future<void> _handleLikeTap() async {
    final noteDB = widget.notedUIModel?.noteDB;
    if (noteDB == null) return;

    // Prevent loading state
    if (_isLiking) return;

    // Check if already liked
    if (noteDB.reactionCountByMe > 0 || _reactionTag) {
      CommonToast.instance.show(context, 'You have already liked this post', toastType: ToastType.info);
      return;
    }

    // Show loading
    setState(() {
      _isLiking = true;
    });
    ChuChuLoading.show();

    bool isSuccess = false;
    try {
      OKEvent event = await RelayGroup.sharedInstance.sendGroupNoteReaction(noteDB.noteId);
      isSuccess = event.status;
    } catch (e) {
      debugPrint('Error sending reaction: $e');
      isSuccess = false;
    } finally {
      // Hide loading
      ChuChuLoading.dismiss();
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }

    _dealWithReaction(isSuccess);
  }

  void _dealWithReaction(bool isSuccess) {
    if (isSuccess) {
      // Only update state after loading is dismissed
      if (mounted) {
        setState(() {
          _reactionTag = true;
        });
      }
      _updateNoteDB();
      CommonToast.instance.show(context, 'Like success tips',toastType:ToastType.success);
    } else {
      CommonToast.instance.show(context, 'Like fail tips',toastType:ToastType.failed);
    }
  }

  void _updateNoteDB() async {
    if (widget.notedUIModel == null) return;

    try {
      NotedUIModel? noteNotifier = await ChuChuFeedCacheManager.getValueNotifierNoted(
        widget.notedUIModel!.noteDB.noteId,
        isUpdateCache: true,
        notedUIModel: widget.notedUIModel,
      );

      if (noteNotifier != null && mounted) {
        // Update the widget's notedUIModel if possible
        // Note: This might need to be handled by parent widget
      }
    } catch (e) {
      debugPrint('Error updating note DB: $e');
    }
  }
}

/// Reusable interaction buttons component that can be used across different pages
class ReusableInteractionButtons extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  final double? iconSize;
  final double? fontSize;
  final Color? textColor;
  final bool showLike;
  final bool showComment;
  final bool showZap;
  final bool showBookmark;
  final VoidCallback? onCommentTap;
  final VoidCallback? onZapTap;
  final VoidCallback? onBookmarkTap;

  const ReusableInteractionButtons({
    super.key,
    required this.notedUIModel,
    this.iconSize = 24,
    this.fontSize = 18,
    this.textColor,
    this.showLike = true,
    this.showComment = true,
    this.showZap = true,
    this.showBookmark = true,
    this.onCommentTap,
    this.onZapTap,
    this.onBookmarkTap,
  });

  @override
  State<ReusableInteractionButtons> createState() => _ReusableInteractionButtonsState();
}

class _ReusableInteractionButtonsState extends State<ReusableInteractionButtons> {
  bool _bookmarkTag = false;

  late NotedUIModel? draftNotedUIModel;

  @override
  void initState() {
    super.initState();
    _initBookmarkState();
  }

  void _initBookmarkState() {
    // Initialize bookmark state if needed
    _bookmarkTag = false;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.showLike)
          ReusableLikeButton(
            notedUIModel: widget.notedUIModel,
            iconSize: widget.iconSize,
            fontSize: widget.fontSize,
            textColor: widget.textColor,
          ),
        if (widget.showLike && widget.showComment)
          SizedBox(width: 16),
        if (widget.showComment)
          _buildCommentButton(),
        if (widget.showComment && widget.showZap)
          SizedBox(width: 16),
        if (widget.showZap)
          _buildZapButton(),
        if (widget.showZap && widget.showBookmark)
          SizedBox(width: 16),
        if (widget.showBookmark)
          _buildBookmarkButton(),
      ],
    );
  }

  Widget _buildCommentButton() {
    final commentCount = widget.notedUIModel?.noteDB.replyCount ?? 0;

    return GestureDetector(
      onTap: widget.onCommentTap ?? _handleCommentTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: CommonImage(
              iconName: 'reply_icon.png',
              size: widget.iconSize ?? 18,
            ),
          ),
          Text(
            commentCount.toString(),
            style: TextStyle(
              color: widget.textColor ?? Theme.of(context).colorScheme.outline,
              fontSize: widget.fontSize ?? 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZapButton() {
    final zapAmount = widget.notedUIModel?.noteDB.zapAmount ?? 0;
    return GestureDetector(
      onTap: widget.onZapTap ?? _handleZapTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: CommonImage(
              iconName: 'zap_icon.png',
              size: widget.iconSize ?? 19,
            ),
          ),
          Text(
            zapAmount.toString(),
            style: TextStyle(
              color: widget.textColor ?? Theme.of(context).colorScheme.outline,
              fontSize: widget.fontSize ?? 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkButton() {
    return GestureDetector(
      onTap: widget.onBookmarkTap ?? _handleBookmarkTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: CommonImage(
              iconName: _bookmarkTag ? 'bookmarked_icon.png' : 'bookmark_icon.png',
              size: widget.iconSize ?? 18,
            ),
          ),
        ],
      ),
    );
  }

  void _handleCommentTap() async {
    // Navigate to comment page or show comment dialog
    if (widget.notedUIModel != null) {
      final result = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FeedReplyPage(notedUIModel: widget.notedUIModel!),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
      if(result != null && result){
      }
    }
  }

  void _handleZapTap() {
    // Handle zap functionality
    CommonToast.instance.show(context, 'Zap functionality coming soon',toastType:ToastType.info);
  }

  void _handleBookmarkTap() {
    setState(() {
      _bookmarkTag = !_bookmarkTag;
    });

    if (_bookmarkTag) {
      CommonToast.instance.show(context, 'Bookmarked',toastType:ToastType.success);
    } else {
      CommonToast.instance.show(context, 'Bookmark removed',toastType:ToastType.success);
    }
  }
}
