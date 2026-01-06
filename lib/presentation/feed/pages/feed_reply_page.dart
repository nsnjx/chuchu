import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/services/blossom_server_manager.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import 'package:nostr_core_dart/src/nips/nip_029.dart';
import 'package:nostr_core_dart/src/ok.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feed_content_analyze_utils.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/widgets/chuchu_Loading.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../data/models/noted_ui_model.dart';
import '../widgets/feed_widget.dart';
import 'feed_info_page.dart';

// Media upload components
import '../../../core/media/media_state.dart';
import '../../../core/media/media_upload_mixin.dart';
import '../../../core/media/widgets/media_toolbar_widget.dart';
import '../../../core/media/widgets/image_display_widget.dart';
import '../../../core/media/widgets/video_display_widget.dart';

class FeedReplyPage extends StatefulWidget {
  final NotedUIModel notedUIModel;
  const FeedReplyPage({super.key, required this.notedUIModel});

  @override
  State<FeedReplyPage> createState() => _FeedReplyPageState();
}

class _FeedReplyPageState extends State<FeedReplyPage>
    with ChuChuUIRefreshMixin, MediaUploadMixin {
  final TextEditingController _textController = TextEditingController();
  bool _postMomentTag = false;

  // Media upload state managed by MediaUploadMixin
  final MediaUploadState _mediaState = MediaUploadState();

  @override
  MediaUploadState get mediaState => _mediaState;

  @override
  void onMediaStateChanged() => setState(() {});

  @override
  Future<String?> uploadImage(String filePath, String fileName) {
    return BlossomServerManager.shared.uploadWithAutoSwitch(
      filePath: filePath,
      fileName: fileName,
      onProgress: (_) {},
    );
  }

  @override
  Future<String?> uploadVideo(String filePath, String fileName) {
    return BlossomServerManager.shared.uploadWithAutoSwitch(
      filePath: filePath,
      fileName: fileName,
      onProgress: (_) {},
    );
  }

  @override
  void onUploadError(String message) {
    CommonToast.instance.show(context, message, toastType: ToastType.failed);
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAnyUploading() ? null : _postMoment,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                        isAnyUploading() ? null : getBrandGradientHorizontal(),
                    color:
                        isAnyUploading()
                            ? theme.colorScheme.outline.withOpacity(0.3)
                            : null,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Text(
                    'Publish',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isAnyUploading()
                              ? theme.colorScheme.onSurface.withOpacity(0.5)
                              : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _momentItemWidget(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          // vertical: 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<UserDBISAR>(
                              valueListenable: Account.sharedInstance
                                  .getUserNotifier(
                                    Account.sharedInstance.currentPubkey,
                                  ),
                              builder: (context, value, child) {
                                return FeedWidgetsUtils.clipImage(
                                  borderRadius: 32,
                                  imageSize: 32,
                                  child: ChuChuCachedNetworkImage(
                                    imageUrl: value.picture ?? '',
                                    fit: BoxFit.cover,
                                    placeholder:
                                        (context, url) =>
                                            FeedWidgetsUtils.badgePlaceholderImage(
                                              size: 32,
                                            ),
                                    errorWidget:
                                        (context, url, error) =>
                                            FeedWidgetsUtils.badgePlaceholderImage(
                                              size: 32,
                                            ),
                                    width: 32,
                                    height: 32,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _textController,
                                maxLines: null,
                                minLines: 2,
                                style: GoogleFonts.inter(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Post your reply',
                                  hintStyle: GoogleFonts.inter(
                                    color: theme.colorScheme.outline,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (mediaState.selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ImageDisplayWidget(
                          selectedImages: mediaState.selectedImages,
                          uploadedUrls: mediaState.uploadedImageUrls,
                          uploadingStatus: mediaState.imageUploadingStatus,
                          onRemove: removeImage,
                          imageBuilder: buildPlatformImage,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
                      if (mediaState.selectedVideos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        VideoDisplayWidget(
                          selectedVideos: mediaState.selectedVideos,
                          uploadedUrls: mediaState.uploadedVideoUrls,
                          uploadingStatus: mediaState.videoUploadingStatus,
                          thumbnails: mediaState.videoThumbnails,
                          onRemove: removeVideo,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 18),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: MediaToolbarWidget(
              onPickImages: pickImages,
              onPickVideos: pickVideos,
              hideVideoButton: mediaState.selectedImages.isNotEmpty,
              hideToolbar: mediaState.selectedVideos.isNotEmpty,
            ),
          ),
        ),
      ),
    );
  }

  Widget _momentItemWidget() {
    String pubKey = widget.notedUIModel.noteDB.author;
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
                    ValueListenableBuilder<UserDBISAR>(
                      valueListenable: Account.sharedInstance.getUserNotifier(
                        pubKey,
                      ),
                      builder: (context, value, child) {
                        return FeedWidgetsUtils.clipImage(
                          borderRadius: 32,
                          imageSize: 32,
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
                              width: 32,
                              height: 32,
                            ),
                          ),
                        );
                      },
                    ),

                    Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        width: 1.0,
                        color: Theme.of(context).dividerColor.withOpacity(0.3),
                      ),
                    ),
                  ],
                ).setPaddingOnly(right: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _momentUserInfoWidget(),
                      const SizedBox(height: 8),
                      FeedWidget(
                        isShowContentLeftPadding:false,
                        isShowOption: false,
                        feedWidgetLayout: EFeedWidgetLayout.fullScreen,
                        isShowAllContent: false,
                        isShowBottomBorder: false,
                        isShowReply: false,
                        notedUIModel: widget.notedUIModel,
                        isShowUserInfo: false,
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
                      Row(
                        children: [
                          Text(
                            'Reply ',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _momentReplyName(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).setPaddingOnly(left: 18.0, right: 18.0);
  }

  Widget _momentReplyName() {
    if (widget.notedUIModel.noteDB.root == null ||
        widget.notedUIModel.noteDB.root!.isEmpty) {
      return ValueListenableBuilder<RelayGroupDBISAR>(
        valueListenable: RelayGroup.sharedInstance.getRelayGroupNotifier(
          widget.notedUIModel.noteDB.groupId,
        ),
        builder: (context, value, child) {
          return Text(
            '@${value.name}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          );
        },
      );
    } else {
      return ValueListenableBuilder<UserDBISAR>(
        valueListenable: Account.sharedInstance.getUserNotifier(
          widget.notedUIModel.noteDB.groupId,
        ),
        builder: (context, value, child) {
          return Text(
            '@${value.name}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          );
        },
      );
    }
  }

  Widget _momentUserInfoWidget() {
    if (widget.notedUIModel.noteDB.root == null ||
        widget.notedUIModel.noteDB.root!.isEmpty) {
      return ValueListenableBuilder<RelayGroupDBISAR>(
        valueListenable: RelayGroup.sharedInstance.getRelayGroupNotifier(
          widget.notedUIModel.noteDB.groupId,
        ),
        builder: (context, value, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    value.name,
                    style: GoogleFonts.inter(
                      color: kTitleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                widget.notedUIModel.createAtStr,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );
        },
      );
    } else {
      return ValueListenableBuilder<UserDBISAR>(
        valueListenable: Account.sharedInstance.getUserNotifier(
          widget.notedUIModel.noteDB.groupId,
        ),
        builder: (context, value, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    value.name ?? '--',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                widget.notedUIModel.createAtStr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          );
        },
      );
    }
  }

  void _postMoment() async {
    if (_textController.text.isEmpty &&
        mediaState.selectedImages.isEmpty &&
        mediaState.selectedVideos.isEmpty) {
      CommonToast.instance.show(context, 'Please enter your reply or add media', toastType: ToastType.failed);
      return;
    }
    if (_postMomentTag) return;
    _postMomentTag = true;
    await ChuChuLoading.show();

    try {
      // Wait for all images to complete upload
      if (mediaState.selectedImages.isNotEmpty &&
          mediaState.uploadedImageUrls.length < mediaState.selectedImages.length) {
        await uploadNewImages();
      }

      // Wait for all videos to complete upload
      if (mediaState.selectedVideos.isNotEmpty &&
          mediaState.uploadedVideoUrls.length < mediaState.selectedVideos.length) {
        await uploadNewVideos();
      }

      final inputText = _textController.text;

      // Build content with image and video URLs
      String mediaContent = '';
      if (mediaState.uploadedImageUrls.isNotEmpty) {
        mediaContent += ' ${mediaState.uploadedImageUrls.join(' ')}';
      }
      if (mediaState.uploadedVideoUrls.isNotEmpty) {
        mediaContent += ' ${mediaState.uploadedVideoUrls.join(' ')}';
      }

      String content = '$inputText$mediaContent';
      List<String> hashTags =
          FeedContentAnalyzeUtils(content).getMomentHashTagList;

      OKEvent? event = await _sendNoteReply(
        content: content,
        hashTags: hashTags,
        getReplyUser: null,
      );

      if (event != null && event.status) {
        CommonToast.instance.show(context, 'Sent successfully',toastType:ToastType.success);
        ChuChuNavigator.pop(context, true);
      } else {
        CommonToast.instance.show(context, 'Failed to send',toastType:ToastType.failed);
      }
    } finally {
      await ChuChuLoading.dismiss();
      _postMomentTag = false;
    }
  }

  Future<OKEvent?> _sendNoteReply({
    required String content,
    required List<String> hashTags,
    List<String>? getReplyUser,
  }) async {
    NoteDBISAR noteDB = widget.notedUIModel.noteDB;
    String groupId = noteDB.groupId;
    List<String> previous = Nip29.getPrevious([
      [groupId],
    ]);
    return await RelayGroup.sharedInstance.sendGroupNoteReply(
      noteDB.noteId,
      content,
      previous,
      hashTags: hashTags,
      mentions: getReplyUser,
    );
  }


}
