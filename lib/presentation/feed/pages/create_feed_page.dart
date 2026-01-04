import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart' hide Filter;
import 'package:nostr_core_dart/nostr.dart';
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/core/services/blossom_server_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/feed/model/feedDraftDB_isar.dart';
import '../../../core/manager/chuchu_feed_manager.dart';
import 'package:nostr_core_dart/src/ok.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/services/file_type.dart';
import '../../../core/services/upload_utils.dart';
import '../../../core/utils/feed_utils.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/widgets/chuchu_Loading.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/database/db_isar.dart';
import 'package:chuchu/core/account/web_file_registry_stub.dart'
    if (dart.library.html) 'package:chuchu/core/account/web_file_registry.dart'
    as web_file_registry;

import 'package:path/path.dart' as Path;

class CreateFeedPage extends StatefulWidget {
  final NotedUIModel? notedUIModel;
  const CreateFeedPage({super.key, this.notedUIModel});

  @override
  State createState() => _CreateFeedPageState();
}

class _CreateFeedPageState extends State<CreateFeedPage>
    with ChuChuFeedObserver, ChuChuUIRefreshMixin {
  final TextEditingController _controller = TextEditingController();
  List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  final Map<int, bool> _uploadingStatus =
      {};

  List<File> _selectedVideos = [];
  final List<String> _uploadedVideoUrls = [];
  final Map<int, bool> _videoUploadingStatus =
      {};
  final Map<int, Uint8List?> _videoThumbnails = {};

  Map<String, UserDBISAR> draftCueUserMap = {};

  bool _postFeedTag = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraft();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  Future<bool> _checkFileSize(File file) async {
    try {
      int fileSize;
      if (kIsWeb || file.path.startsWith('webfile://')) {
        final bytes = web_file_registry.getWebFileData(file.path);
        if (bytes == null) return false;
        fileSize = bytes.length;
      } else {
        fileSize = await file.length();
      }
      const maxSize = 20 * 1024 * 1024;
      return fileSize > maxSize;
    } catch (e) {
      return false;
    }
  }

  Future<bool?> _showSaveDraftDialog() async {
    return await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Save Draft Dialog',
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            Center(
              child: SafeArea(
                child: AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 18.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: theme.dialogTheme.backgroundColor ??
                      theme.colorScheme.surface,
                  actionsPadding: const EdgeInsets.only(
                    right: 24,
                    bottom: 24,
                    top: 8,
                  ),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/draft_icon.png',
                        width: 28,
                        height: 28,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Save Draft?',
                        style: GoogleFonts.inter(
                          color: kTitleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'You have unsaved changes. Do you want to save as draft?',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 50,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).pop(false);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                        
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Discard',
                                    style: GoogleFonts.inter(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 50,
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  Navigator.of(context).pop(true);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: getBrandGradientHorizontal(),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Save',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlatformImage(File image, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      final data = web_file_registry.getWebFileData(image.path);
      if (data != null) {
        return Image.memory(
          data,
          fit: fit,
          errorBuilder:
              (context, error, stackTrace) => Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              ),
        );
      }
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported),
      );
    }
    return Image.file(image as dynamic, fit: fit);
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      final filesToAdd = <File>[];
      for (final image in picked) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final virtualPath = web_file_registry.createVirtualFilePath(
            image.name,
          );
          web_file_registry.registerWebFileData(virtualPath, bytes);
          filesToAdd.add(File(virtualPath));
        } else {
          filesToAdd.add(File(image.path));
        }
      }
      setState(() {
        _selectedImages.addAll(filesToAdd);
        for (
          int i = _uploadedImageUrls.length;
          i < _selectedImages.length;
          i++
        ) {
          if (!_uploadingStatus.containsKey(i)) {
            _uploadingStatus[i] = false;
          }
        }
      });


      WidgetsBinding.instance.addPostFrameCallback((_) {
        _uploadNewImages();
      });
    }
  }

  Future<void> _pickVideos() async {
    final picker = ImagePicker();

    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      File videoFile;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final virtualPath = web_file_registry.createVirtualFilePath(
          picked.name,
        );
        web_file_registry.registerWebFileData(virtualPath, bytes);
        videoFile = File(virtualPath);
      } else {
        videoFile = File(picked.path);
      }
      setState(() {
        _selectedVideos.add(videoFile);
        final index = _selectedVideos.length - 1;
        if (!_videoUploadingStatus.containsKey(index)) {
          _videoUploadingStatus[index] = false;
        }
        _generateVideoThumbnail(videoFile, index);
      });


      WidgetsBinding.instance.addPostFrameCallback((_) {
        _uploadNewVideos();
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      final removedImage = _selectedImages.removeAt(index);
      final wasUploading = _uploadingStatus[index] == true;
      _uploadingStatus.remove(index);
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
      if (kIsWeb) {
        web_file_registry.unregisterWebFileData(removedImage.path);
      }
      final newStatus = <int, bool>{};
      _uploadingStatus.forEach((key, value) {
        if (key > index) {
          newStatus[key - 1] = value;
        } else if (key < index) {
          newStatus[key] = value;
        }
      });
      _uploadingStatus.clear();
      _uploadingStatus.addAll(newStatus);
      if (wasUploading && !_isAnyUploading()) {
        _isUploading = false;
      }
      
    });
  }

  void _removeVideo(int index) {
    setState(() {
      final removedVideo = _selectedVideos.removeAt(index);
      final wasUploading = _videoUploadingStatus[index] == true;
      _videoUploadingStatus.remove(index);
      _videoThumbnails.remove(index);
      if (index < _uploadedVideoUrls.length) {
        _uploadedVideoUrls.removeAt(index);
      }
      if (kIsWeb) {
        web_file_registry.unregisterWebFileData(removedVideo.path);
      }
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
      if (wasUploading && !_isAnyUploading()) {
        _isUploading = false;
      }
      
    });
  }

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
    }
  }

  Future<void> _uploadNewImages() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final indicesToUpload = <int>[];
      for (int i = _uploadedImageUrls.length; i < _selectedImages.length; i++) {
        indicesToUpload.add(i);
      }

      final failedIndices = <int>[];
      for (int i in indicesToUpload) {
        if (!mounted) return;

        final imageFile = _selectedImages[i];

        try {
          final exceedsSize = await _checkFileSize(imageFile);
          if (exceedsSize) {
            if (mounted) {
              CommonToast.instance.show(
                context,
                'File size exceeds the maximum allowed size of 20 MiB',
                  toastType:ToastType.success
              );
              failedIndices.add(i);
            }
            continue;
          }

          if (mounted) {
            setState(() {
              _uploadingStatus[i] = true;
            });
          }

          String uploadFilePath;
          String fileName;

          if (kIsWeb || imageFile.path.startsWith('webfile://')) {
            uploadFilePath = imageFile.path;
            fileName = uploadFilePath.split('/').last;
          } else {
            final processedImageFile = await removeExifWithCompress(imageFile);
            if (processedImageFile == null) {
              throw Exception('Failed to process image');
            }
            uploadFilePath = processedImageFile.path;
            fileName = uploadFilePath.split('/').last;
          }

          final imageUrl = await BlossomServerManager.shared.uploadWithAutoSwitch(
            filePath: uploadFilePath,
            fileName: fileName,
            onProgress: (_) {},
          );
          if (imageUrl != null && imageUrl.isNotEmpty) {
            if (mounted) {
              setState(() {
                _uploadedImageUrls.add(imageUrl);
                _uploadingStatus[i] = false;
              });
            }
          } else {
            throw Exception('All Blossom servers failed to upload');
          }
        } catch (e) {
          if (mounted) {
            final errorMessage = e.toString();
            CommonToast.instance.show(context, errorMessage, toastType:ToastType.failed);

            failedIndices.add(i);
          }
        }
      }

      if (mounted && failedIndices.isNotEmpty) {
        failedIndices.sort((a, b) => b.compareTo(a));
        for (int index in failedIndices) {
          _removeImage(index);
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

  Future<void> _uploadNewVideos() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final indicesToUpload = <int>[];
      for (int i = _uploadedVideoUrls.length; i < _selectedVideos.length; i++) {
        indicesToUpload.add(i);
      }

      final failedIndices = <int>[];
      for (int i in indicesToUpload) {
        if (!mounted) return;

        final file = _selectedVideos[i];

        try {
          final exceedsSize = await _checkFileSize(file);
          if (exceedsSize) {
            if (mounted) {
              CommonToast.instance.show(
                context,
                'File size exceeds the maximum allowed size of 20 MiB',
                  toastType:ToastType.failed
              );
              failedIndices.add(i);
            }
            continue;
          }

          if (mounted) {
            setState(() {
              _videoUploadingStatus[i] = true;
            });
          }

          final currentTime = DateTime.now().microsecondsSinceEpoch.toString();
          String fileName =
              '$currentTime${Path.basenameWithoutExtension(file.path)}.mp4';

          UploadResult result = await UploadUtils.uploadFile(
            context: context,
            fileType: FileType.video,
            file: file,
            filename: fileName,
          );

          if (result.isSuccess && result.url.isNotEmpty) {
            if (mounted) {
              setState(() {
                _uploadedVideoUrls.add(result.url);
                _videoUploadingStatus[i] = false;
              });
            }
          } else {
            throw Exception('Upload failed: ${result.errorMsg}');
          }
        } catch (e) {
          if (mounted) {
            final errorMessage = e.toString();
            CommonToast.instance.show(context, errorMessage,toastType:ToastType.failed);

            failedIndices.add(i);
          }
        }
      }

      if (mounted && failedIndices.isNotEmpty) {
        failedIndices.sort((a, b) => b.compareTo(a));
        for (int index in failedIndices) {
          _removeVideo(index);
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

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        if (_controller.text.isEmpty &&
            _selectedImages.isEmpty &&
            _selectedVideos.isEmpty &&
            _uploadedImageUrls.isEmpty &&
            _uploadedVideoUrls.isEmpty) {
          return true;
        }

        final shouldSave = await _showSaveDraftDialog();

        if (shouldSave == true) {
          await _saveDraft();
        } else {
          await _deleteDraft();
        }

        return true;
      },
      child: Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: TextButton(
          onPressed: _handleCancel,
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
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      _buildTextInputArea(),
                      _buildImageDisplayArea(),
                      _buildVideoDisplayArea(),
                      _buildMediaToolbar(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputArea() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<UserDBISAR>(
            valueListenable: Account.sharedInstance.getUserNotifier(
              Account.sharedInstance.currentPubkey,
            ),
            builder: (context, user, child) {
              return Container(
                child: FeedWidgetsUtils.clipImage(
                  borderRadius: 40,
                  imageSize: 40,
                  child: ChuChuCachedNetworkImage(
                    imageUrl: user.picture ?? '',
                    fit: BoxFit.cover,
                    placeholder:
                        (_, __) => FeedWidgetsUtils.badgePlaceholderImage(),
                    errorWidget:
                        (_, __, ___) =>
                            FeedWidgetsUtils.badgePlaceholderImage(),
                    width: 40,
                    height: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: "What's new?",
                hintStyle: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaToolbar() {
    if (_selectedVideos.isNotEmpty) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: _buildMediaButtons()),
        ],
      ),
    );
  }

  Widget _buildMediaButtons() {
    final theme = Theme.of(context);

    final bool hideVideoButton = _selectedImages.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        if (!hideVideoButton) const SizedBox(width: 12),
        if (!hideVideoButton)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      ],
    );
  }

  Widget _buildImageDisplayArea() {
    if (_selectedImages.isEmpty && _uploadedImageUrls.isEmpty) return const SizedBox();

    if (_selectedImages.isEmpty && _uploadedImageUrls.isNotEmpty) {
      return _buildUploadedImagesDisplay();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Container(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child:
                _selectedImages.length == 1
                    ? _buildSingleImage(
                      _selectedImages[0],
                      0,
                      key: const ValueKey('single'),
                    )
                    : _buildImageCarousel(key: const ValueKey('multi')),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadedImagesDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _uploadedImageUrls.length == 1
            ? _buildSingleUploadedImage(_uploadedImageUrls[0], 0)
            : _buildUploadedImageCarousel(),
      ),
    );
  }

  Widget _buildSingleUploadedImage(String url, int index) {
    final isNetworkUrl = url.startsWith('http://') || url.startsWith('https://');
    
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.hardEdge,
          child: isNetworkUrl
              ? ChuChuCachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                )
              : _buildPlatformImage(File(url), fit: BoxFit.cover),
        ),
        Positioned(
          top: 12,
          right: 24,
          child: GestureDetector(
            onTap: () => _removeUploadedImage(index),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 20,
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
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Uploaded',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadedImageCarousel() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _uploadedImageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == _uploadedImageUrls.length - 1 ? 0 : 8,
            ),
            child: _buildSingleUploadedImage(_uploadedImageUrls[index], index),
          );
        },
      ),
    );
  }

  void _removeUploadedImage(int index) {
    setState(() {
      _uploadedImageUrls.removeAt(index);
    });
  }

  Widget _buildVideoDisplayArea() {
    if (_selectedVideos.isEmpty && _uploadedVideoUrls.isEmpty) return const SizedBox();

    if (_selectedVideos.isEmpty && _uploadedVideoUrls.isNotEmpty) {
      return _buildUploadedVideosDisplay();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child:
                _selectedVideos.length == 1
                    ? _buildSingleVideo(
                      _selectedVideos[0],
                      0,
                      key: const ValueKey('single_video'),
                    )
                    : _buildVideoCarousel(key: const ValueKey('multi_video')),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadedVideosDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _uploadedVideoUrls.length == 1
            ? _buildSingleUploadedVideo(_uploadedVideoUrls[0], 0)
            : _buildUploadedVideoCarousel(),
      ),
    );
  }

  Widget _buildSingleUploadedVideo(String url, int index) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.hardEdge,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'Video uploaded',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 24,
          child: GestureDetector(
            onTap: () => _removeUploadedVideo(index),
            child: const CircleAvatar(
              radius: 14,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          left: 20,
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
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Uploaded',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadedVideoCarousel() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _uploadedVideoUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == _uploadedVideoUrls.length - 1 ? 0 : 8,
            ),
            child: _buildSingleUploadedVideo(_uploadedVideoUrls[index], index),
          );
        },
      ),
    );
  }

  void _removeUploadedVideo(int index) {
    setState(() {
      _uploadedVideoUrls.removeAt(index);
    });
  }

  Widget _buildSingleImage(File image, int index, {required Key key}) {
    final isUploaded = index < _uploadedImageUrls.length;
    final isUploading = _uploadingStatus[index] ?? false;

    return Stack(
      key: key,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              _buildPlatformImage(image, fit: BoxFit.cover),
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
            onTap: () => _removeImage(index),
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
            left: 20,
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

  Widget _buildImageCarousel({required Key key}) {
    return SizedBox(
      key: key,
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _selectedImages.length,
        itemBuilder: (context, index) {
          final image = _selectedImages[index];
          final isUploaded = index < _uploadedImageUrls.length;
          final isUploading = _uploadingStatus[index] ?? false;

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
                    SizedBox.expand(
                      child: _buildPlatformImage(image, fit: BoxFit.cover),
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

  Widget _buildSingleVideo(File video, int index, {required Key key}) {
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

  Widget _buildVideoCarousel({required Key key}) {
    return SizedBox(
      key: key,
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
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

  void _postMoment() async {
    if (_postFeedTag) return;
    _postFeedTag = true;

    ChuChuLoading.show();

    try {
      if (_selectedImages.isNotEmpty &&
          _uploadedImageUrls.length < _selectedImages.length) {
        await _uploadNewImages();
      }

      if (_selectedVideos.isNotEmpty &&
          _uploadedVideoUrls.length < _selectedVideos.length) {
        await _uploadNewVideos();
      }

      final inputText = _controller.text;

      String mediaContent = '';
      if (_uploadedImageUrls.isNotEmpty) {
        mediaContent += ' ${_uploadedImageUrls.join(' ')}';
      }
      if (_uploadedVideoUrls.isNotEmpty) {
        mediaContent += ' ${_uploadedVideoUrls.join(' ')}';
      }

      String content =
          '${FeedUtils.changeAtUserToNpub(draftCueUserMap, inputText)}$mediaContent';
      if (content.trim().isEmpty) {
        CommonToast.instance.show(context, 'Content empty tips',toastType:ToastType.failed);
        return;
      }
      List<String> previous = Nip29.getPrevious([
        [Account.sharedInstance.currentPubkey],
      ]);
      OKEvent? eventStatus = await RelayGroup.sharedInstance.sendGroupNotes(
        Account.sharedInstance.currentPubkey,
        content,
        previous,
      );

      if (eventStatus.status) {
        await _deleteDraft();
        CommonToast.instance.show(context, 'Sent successfully',toastType:ToastType.success);
        Navigator.pop(context);
      } else {
        CommonToast.instance.show(context, 'Failed to send',toastType:ToastType.failed);
      }
    } catch (e) {
      CommonToast.instance.show(context, 'Post failed: $e',toastType:ToastType.failed);
    } finally {
      ChuChuLoading.dismiss();
      _postFeedTag = false;
    }
  }

  Future<File?> removeExifWithCompress(File file) async {
    if (kIsWeb) {
      return file;
    }

    final targetPath = Path.join(
      Path.dirname(file.path),
      '${Path.basenameWithoutExtension(file.path)}_noexif.jpg',
    );

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 95,
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> _loadDraft() async {
    try {
      final currentPubkey = Account.sharedInstance.currentPubkey;
      if (currentPubkey.isEmpty) {
        return;
      }

      final isar = DBISAR.sharedInstance.isar;
      final draft = isar.feedDraftDBISARs.where().authorEqualTo(currentPubkey).findFirst();
      
      if (draft == null) {
        return;
      }

      if (mounted) {
        _controller.value = TextEditingValue(
          text: draft.content,
          selection: TextSelection.collapsed(offset: draft.content.length),
        );
      }

      if (draft.draftCueUserMapJson != null && draft.draftCueUserMapJson!.isNotEmpty) {
        try {
          final mapData = jsonDecode(draft.draftCueUserMapJson!) as Map<String, dynamic>;
          draftCueUserMap = {};
          mapData.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              final user = UserDBISAR.fromMap(value);
              draftCueUserMap[key] = user;
            }
          });
        } catch (e) {
          // Ignore parsing errors
        }
      }

      _restoreMediaUrls(draft);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // Ignore loading errors
    }
  }

  void _restoreMediaUrls(FeedDraftDBISAR draft) {
    if (draft.imageUrls != null && draft.imageUrls!.isNotEmpty) {
      _uploadedImageUrls.clear();
      _uploadedImageUrls.addAll(draft.imageUrls!);
    }

    if (draft.videoUrls != null && draft.videoUrls!.isNotEmpty) {
      _uploadedVideoUrls.clear();
      _uploadedVideoUrls.addAll(draft.videoUrls!);
    }
  }

  Future<void> _saveDraft() async {
    try {
      final currentPubkey = Account.sharedInstance.currentPubkey;
      if (currentPubkey.isEmpty) {
        return;
      }

      final content = _controller.text;
      if (content.isEmpty && _uploadedImageUrls.isEmpty && _uploadedVideoUrls.isEmpty) {
        await _deleteDraft();
        return;
      }

      String? draftCueUserMapJson;
      if (draftCueUserMap.isNotEmpty) {
        try {
          final mapData = <String, Map<String, dynamic>>{};
          draftCueUserMap.forEach((key, user) {
            mapData[key] = {
              'pubKey': user.pubKey,
              'name': user.name,
              'nickName': user.nickName,
              'picture': user.picture,
              'dns': user.dns,
              'about': user.about,
            };
          });
          draftCueUserMapJson = jsonEncode(mapData);
        } catch (e) {
          // Ignore encoding errors
        }
      }

      final draft = FeedDraftDBISAR(
        author: currentPubkey,
        content: content,
        imageUrls: _uploadedImageUrls.isNotEmpty ? List<String>.from(_uploadedImageUrls) : null,
        videoUrls: _uploadedVideoUrls.isNotEmpty ? List<String>.from(_uploadedVideoUrls) : null,
        draftCueUserMapJson: draftCueUserMapJson,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await DBISAR.sharedInstance.saveToDB(draft);
    } catch (e) {
      // Ignore saving errors
    }
  }

  Future<void> _deleteDraft() async {
    try {
      final currentPubkey = Account.sharedInstance.currentPubkey;
      if (currentPubkey.isEmpty) {
        return;
      }

      final isar = DBISAR.sharedInstance.isar;
      await isar.write((isar) async {
        isar.feedDraftDBISARs
            .where()
            .authorEqualTo(currentPubkey)
            .deleteAll();
      });
    } catch (e) {
      // Ignore deletion errors
    }
  }

  void _handleCancel() async {
    if (_controller.text.isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideos.isEmpty &&
        _uploadedImageUrls.isEmpty &&
        _uploadedVideoUrls.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final shouldSave = await _showSaveDraftDialog();

    if (shouldSave == true) {
      await _saveDraft();
    } else {
      await _deleteDraft();
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}
