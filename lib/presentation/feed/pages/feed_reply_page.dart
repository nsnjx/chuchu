import 'dart:async';
// Conditional import for File class
import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as Path;
import 'package:video_thumbnail/video_thumbnail.dart';
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
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../data/models/noted_ui_model.dart';
import '../widgets/feed_widget.dart';
import 'feed_info_page.dart';

class FeedReplyPage extends StatefulWidget {
  final NotedUIModel notedUIModel;
  const FeedReplyPage({super.key, required this.notedUIModel});

  @override
  State<FeedReplyPage> createState() => _FeedReplyPageState();
}

class _FeedReplyPageState extends State<FeedReplyPage>
    with ChuChuUIRefreshMixin {
  final TextEditingController _textController = TextEditingController();
  // Align with create_feed_page: store selected images as File and support removal
  final List<File> _selectedImages = [];
  double? _singleImageAspectRatio;
  bool _postMomentTag = false;
  // Upload state
  final List<String> _uploadedImageUrls = [];
  final Map<int, bool> _uploadingStatus = {}; // index -> uploading

  // Video related state
  final List<File> _selectedVideos = [];
  final List<String> _uploadedVideoUrls = []; // Store uploaded video URLs
  final Map<int, bool> _videoUploadingStatus =
      {}; // Track upload status for each video
  final Map<int, Uint8List?> _videoThumbnails = {}; // Store video thumbnails
  bool _isUploading = false; // Track overall upload status

  bool _isAnyUploading() {
    for (int i = 0; i < _selectedImages.length; i++) {
      if (_uploadingStatus[i] == true) {
        return true;
      }
    }
    for (int i = 0; i < _selectedVideos.length; i++) {
      if (_videoUploadingStatus[i] == true) {
        return true;
      }
    }
    return false;
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
                onTap: _isAnyUploading() ? null : _postMoment,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                        _isAnyUploading() ? null : getBrandGradientHorizontal(),
                    color:
                        _isAnyUploading()
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
                          _isAnyUploading()
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
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildReplyImageDisplayArea(),
                        ),
                      ],
                      if (_selectedVideos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildReplyVideoDisplayArea(),
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
            child: _buildMediaToolbar(),
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
        _selectedImages.isEmpty &&
        _selectedVideos.isEmpty) {
      CommonToast.instance.show(context, 'Please enter your reply or add media', toastType: ToastType.failed);
      return;
    }
    if (_postMomentTag) return;
    _postMomentTag = true;
    await ChuChuLoading.show();

    try {
      // Wait for all images to complete upload
      if (_selectedImages.isNotEmpty &&
          _uploadedImageUrls.length < _selectedImages.length) {
        await _uploadNewImages();
      }

      // Wait for all videos to complete upload
      if (_selectedVideos.isNotEmpty &&
          _uploadedVideoUrls.length < _selectedVideos.length) {
        await _uploadNewVideos();
      }

      final inputText = _textController.text;

      // Build content with image and video URLs
      String mediaContent = '';
      if (_uploadedImageUrls.isNotEmpty) {
        mediaContent += ' ${_uploadedImageUrls.join(' ')}';
      }
      if (_uploadedVideoUrls.isNotEmpty) {
        mediaContent += ' ${_uploadedVideoUrls.join(' ')}';
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

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _selectedImages.addAll(files.map((f) => File(f.path)));
        for (
          int i = _uploadedImageUrls.length;
          i < _selectedImages.length;
          i++
        ) {
          _uploadingStatus[i] = false;
        }
      });
      // compute aspect ratio for single image
      if (_selectedImages.length == 1) {
        final ratio = await _computeAspectRatio(_selectedImages.first);
        if (mounted)
          setState(() {
            _singleImageAspectRatio = ratio;
          });
      } else {
        if (mounted) {
          setState(() {
            _singleImageAspectRatio = null;
          });
        }
      }
      // Wait for the next frame to ensure state is updated before uploading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _uploadNewImages();
      });
    } catch (e) {
      debugPrint('pick medias error: $e');
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      final wasUploading = _uploadingStatus[index] == true;
      _selectedImages.removeAt(index);
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
      _uploadingStatus.remove(index);
      final newStatus = <int, bool>{};
      _uploadingStatus.forEach((k, v) {
        newStatus[k > index ? k - 1 : k] = v;
      });
      _uploadingStatus
        ..clear()
        ..addAll(newStatus);
      // If we removed an uploading image and no other images are uploading, update _isUploading flag
      if (wasUploading && !_isAnyUploading()) {
        _isUploading = false;
      }
    });
    if (_selectedImages.length == 1) {
      _computeAspectRatio(_selectedImages.first).then((ratio) {
        if (mounted)
          setState(() {
            _singleImageAspectRatio = ratio;
          });
      });
    } else {
      setState(() {
        _singleImageAspectRatio = null;
      });
    }
  }

  // Build media toolbar with image and video buttons
  Widget _buildMediaToolbar() {
    final theme = Theme.of(context);

    // Hide media toolbar if video is selected
    if (_selectedVideos.isNotEmpty) {
      return const SizedBox();
    }

    // Hide video button if images are selected
    final bool hideVideoButton = _selectedImages.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: _pickImages,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CommonImage(iconName: 'image_bg_icon.png', size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Add images',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!hideVideoButton) const SizedBox(width: 12),
        if (!hideVideoButton)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GestureDetector(
                onTap: _pickVideos,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CommonImage(iconName: 'video_bg_icon.png', size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Add video',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickVideos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final videoFile = File(picked.path);
        if (!mounted) return;
        setState(() {
          _selectedVideos.add(videoFile);
          // Initialize upload status for new video
          final index = _selectedVideos.length - 1;
          if (!_videoUploadingStatus.containsKey(index)) {
            _videoUploadingStatus[index] = false;
          }
          // Generate thumbnail
          _generateVideoThumbnail(videoFile, index);
        });

        // Wait for the next frame to ensure state is updated before uploading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _uploadNewVideos();
        });
      }
    } catch (e) {
      debugPrint('pick video error: $e');
    }
  }

  void _removeVideo(int index) {
    if (index < 0 || index >= _selectedVideos.length) return;
    setState(() {
      final wasUploading = _videoUploadingStatus[index] == true;
      _selectedVideos.removeAt(index);
      // Remove corresponding upload status, URL and thumbnail
      _videoUploadingStatus.remove(index);
      _videoThumbnails.remove(index);
      if (index < _uploadedVideoUrls.length) {
        _uploadedVideoUrls.removeAt(index);
      }
      // Re-adjust status indices for remaining videos
      final newStatus = <int, bool>{};
      final newThumbnails = <int, Uint8List?>{};
      _videoUploadingStatus.forEach((key, value) {
        if (key > index) {
          newStatus[key - 1] = value;
        } else if (key < index) {
          newStatus[key] = value;
        }
      });
      _videoThumbnails.forEach((key, value) {
        if (key > index) {
          newThumbnails[key - 1] = value;
        } else if (key < index) {
          newThumbnails[key] = value;
        }
      });
      _videoUploadingStatus.clear();
      _videoThumbnails.clear();
      _videoUploadingStatus.addAll(newStatus);
      _videoThumbnails.addAll(newThumbnails);
      // If we removed an uploading video and no other videos are uploading, update _isUploading flag
      if (wasUploading && !_isAnyUploading()) {
        _isUploading = false;
      }
    });
  }

  /// Generate video thumbnail
  Future<void> _generateVideoThumbnail(File videoFile, int index) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );

      if (thumbnail != null && mounted) {
        setState(() {
          _videoThumbnails[index] = thumbnail;
        });
      }
    } catch (e) {
      // Thumbnail generation failed, continue without thumbnail
      debugPrint('generate video thumbnail error: $e');
    }
  }

  /// Upload newly selected videos
  Future<void> _uploadNewVideos() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload videos that haven't been uploaded yet
      for (int i = _uploadedVideoUrls.length; i < _selectedVideos.length; i++) {
        if (!mounted) return;

        final file = _selectedVideos[i];

        try {
          // Set upload status to true
          if (mounted) {
            setState(() {
              _videoUploadingStatus[i] = true;
            });
          }

          final currentTime = DateTime.now().microsecondsSinceEpoch.toString();
          String fileName =
              '$currentTime${Path.basenameWithoutExtension(file.path)}.mp4';

          final url = await BlossomServerManager.shared.uploadWithAutoSwitch(
            filePath: file.path,
            fileName: fileName,
            onProgress: (progress) {
              // Optional: update UI with progress
            },
          );

          if (url != null && url.isNotEmpty && mounted) {
            setState(() {
              _uploadedVideoUrls.add(url);
              _videoUploadingStatus[i] = false; // Upload completed
            });
          } else if (mounted) {
            setState(() {
              _videoUploadingStatus[i] = false; // Reset upload status
            });
            CommonToast.instance.show(
              context,
              'Video ${i + 1} upload failed',
              toastType: ToastType.failed,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _videoUploadingStatus[i] = false; // Reset upload status
            });
            CommonToast.instance.show(
              context,
              'Video ${i + 1} upload failed: $e',
              toastType: ToastType.failed,
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // --- UI helpers aligned with create_feed_page ---
  Widget _buildReplyImageDisplayArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child:
            _selectedImages.length == 1
                ? _buildReplySingleImage(
                  _selectedImages[0],
                  key: const ValueKey('reply_single'),
                )
                : _buildReplyImageCarousel(key: const ValueKey('reply_multi')),
      ),
    );
  }

  Widget _buildReplySingleImage(File image, {required Key key}) {
    final aspect = _singleImageAspectRatio ?? (16 / 9);
    return AspectRatio(
      key: key,
      aspectRatio: aspect,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                image as dynamic,
                fit: BoxFit.cover,
              ), // Type cast for conditional import compatibility
            ),
          ),
          if ((_uploadingStatus[0] ?? false))
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 12,
            child: GestureDetector(
              onTap: () => _removeImage(0),
              child: const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          if (_uploadedImageUrls.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: kGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Uploaded',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyImageCarousel({required Key key}) {
    return SizedBox(
      key: key,
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          final image = _selectedImages[index];
          return Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.file(
                        image as dynamic,
                        fit: BoxFit.cover,
                      ), // Type cast for conditional import compatibility
                    ),
                    if (_uploadingStatus[index] ?? false)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    if (index < _uploadedImageUrls.length)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 14,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyVideoDisplayArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child:
            _selectedVideos.length == 1
                ? _buildReplySingleVideo(
                  _selectedVideos[0],
                  0,
                  key: const ValueKey('reply_single_video'),
                )
                : _buildReplyVideoCarousel(
                  key: const ValueKey('reply_multi_video'),
                ),
      ),
    );
  }

  Widget _buildReplySingleVideo(File video, int index, {required Key key}) {
    final isUploaded = index < _uploadedVideoUrls.length;
    final isUploading = _videoUploadingStatus[index] ?? false;
    final thumbnail = _videoThumbnails[index];

    return Stack(
      key: key,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Show thumbnail if available, otherwise show play icon
              if (thumbnail != null)
                Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black54,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 24,
          child: GestureDetector(
            onTap: () => _removeVideo(index),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        if (isUploaded)
          Positioned(
            bottom: 8,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: kGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Uploaded',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyVideoCarousel({required Key key}) {
    return SizedBox(
      key: key,
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _selectedVideos.length,
        itemBuilder: (context, index) {
          final isUploaded = index < _uploadedVideoUrls.length;
          final isUploading = _videoUploadingStatus[index] ?? false;
          final thumbnail = _videoThumbnails[index];

          return Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    // Show thumbnail if available, otherwise show play icon
                    if (thumbnail != null)
                      Image.memory(
                        thumbnail,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      )
                    else
                      Container(
                        width: 120,
                        height: 120,
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    if (isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black54,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    if (isUploaded)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 10),
                              SizedBox(width: 2),
                              Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 14,
                child: GestureDetector(
                  onTap: () => _removeVideo(index),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<double> _computeAspectRatio(File file) async {
    try {
      final bytes =
          await (file as dynamic).readAsBytes()
              as Uint8List; // Type cast for conditional import compatibility
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) => completer.complete(img));
      final img = await completer.future;
      return img.width / img.height;
    } catch (_) {
      return 16 / 9; // fallback
    }
  }

  Future<void> _uploadNewImages() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      // Set upload status to true for all images that need to be uploaded
      for (int i = _uploadedImageUrls.length; i < _selectedImages.length; i++) {
        _uploadingStatus[i] = true;
      }
    });

    try {
      // Upload images that haven't been uploaded yet
      for (int i = _uploadedImageUrls.length; i < _selectedImages.length; i++) {
        if (!mounted) return;
        final original = _selectedImages[i];
        final processed = await _removeExifWithCompress(original);
        final filePath = (processed ?? original).path;
        try {
          final url = await BlossomServerManager.shared.uploadWithAutoSwitch(
            filePath: filePath,
            fileName: Path.basename(filePath),
            onProgress: (progress) {
              // Optional: update UI with progress
            },
          );
          if (url != null && url.isNotEmpty && mounted) {
            setState(() {
              _uploadedImageUrls.add(url);
              _uploadingStatus[i] = false;
            });
          } else if (mounted) {
            setState(() {
              _uploadingStatus[i] = false;
            });
            CommonToast.instance.show(
              context,
              'Image ${i + 1} upload failed',
              toastType: ToastType.failed,
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _uploadingStatus[i] = false;
            });
            CommonToast.instance.show(
              context,
              'Image ${i + 1} upload failed: $e',
              toastType: ToastType.failed,
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<File?> _removeExifWithCompress(File file) async {
    try {
      final targetPath = Path.join(
        Path.dirname(file.path),
        '${Path.basenameWithoutExtension(file.path)}_noexif.jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        (file as dynamic)
            .absolute
            .path, // Type cast for conditional import compatibility
        targetPath,
        quality: 95,
      );
      return result != null ? File(result.path) : null;
    } catch (_) {
      return null;
    }
  }
}
