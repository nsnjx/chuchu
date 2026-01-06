import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as Path;
import 'package:chuchu/core/account/web_file_registry_stub.dart'
    if (dart.library.html) 'package:chuchu/core/account/web_file_registry.dart'
    as web_file_registry;

import 'media_state.dart';

class MediaUploadConfig {
  final bool supportWeb;
  final int maxFileSizeMB;
  final bool checkFileSize;
  final int imageQuality;

  const MediaUploadConfig({
    this.supportWeb = true,
    this.maxFileSizeMB = 20,
    this.checkFileSize = true,
    this.imageQuality = 95,
  });
}

mixin MediaUploadMixin<T extends StatefulWidget> on State<T> {
  MediaUploadState get mediaState;
  MediaUploadConfig get mediaConfig => const MediaUploadConfig();
  void onMediaStateChanged();
  Future<String?> uploadImage(String filePath, String fileName);
  Future<String?> uploadVideo(String filePath, String fileName);

  void onUploadError(String message) {
    debugPrint('Upload error: $message');
  }

  bool isAnyUploading() => mediaState.isAnyUploading;

  Future<bool> checkFileSize(File file) async {
    if (!mediaConfig.checkFileSize) return false;

    try {
      int fileSize;
      if (kIsWeb || file.path.startsWith('webfile://')) {
        final bytes = web_file_registry.getWebFileData(file.path);
        if (bytes == null) return false;
        fileSize = bytes.length;
      } else {
        fileSize = await file.length();
      }
      final maxSize = mediaConfig.maxFileSizeMB * 1024 * 1024;
      return fileSize > maxSize;
    } catch (e) {
      return false;
    }
  }

  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage();
      if (picked.isEmpty || !mounted) return;

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

      mediaState.selectedImages.addAll(filesToAdd);

      for (int i = mediaState.uploadedImageUrls.length;
          i < mediaState.selectedImages.length;
          i++) {
        if (!mediaState.imageUploadingStatus.containsKey(i)) {
          mediaState.imageUploadingStatus[i] = false;
        }
      }

      onMediaStateChanged();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        uploadNewImages();
      });
    } catch (e) {
      debugPrint('pick images error: $e');
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= mediaState.selectedImages.length) return;

    final removedImage = mediaState.selectedImages.removeAt(index);
    final wasUploading = mediaState.imageUploadingStatus[index] == true;
    mediaState.imageUploadingStatus.remove(index);

    if (index < mediaState.uploadedImageUrls.length) {
      mediaState.uploadedImageUrls.removeAt(index);
    }

    if (kIsWeb) {
      web_file_registry.unregisterWebFileData(removedImage.path);
    }

    _reindexMap(mediaState.imageUploadingStatus, index);

    if (wasUploading && !isAnyUploading()) {
      mediaState.isUploading = false;
    }

    onMediaStateChanged();
  }

  Future<void> pickVideos() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null || !mounted) return;

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

      mediaState.selectedVideos.add(videoFile);

      final index = mediaState.selectedVideos.length - 1;
      if (!mediaState.videoUploadingStatus.containsKey(index)) {
        mediaState.videoUploadingStatus[index] = false;
      }

      generateVideoThumbnail(videoFile, index);

      onMediaStateChanged();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        uploadNewVideos();
      });
    } catch (e) {
      debugPrint('pick video error: $e');
    }
  }

  void removeVideo(int index) {
    if (index < 0 || index >= mediaState.selectedVideos.length) return;

    final removedVideo = mediaState.selectedVideos.removeAt(index);
    final wasUploading = mediaState.videoUploadingStatus[index] == true;
    mediaState.videoUploadingStatus.remove(index);
    mediaState.videoThumbnails.remove(index);

    if (index < mediaState.uploadedVideoUrls.length) {
      mediaState.uploadedVideoUrls.removeAt(index);
    }

    if (kIsWeb) {
      web_file_registry.unregisterWebFileData(removedVideo.path);
    }

    _reindexMap(mediaState.videoUploadingStatus, index);
    _reindexMapNullable(mediaState.videoThumbnails, index);

    if (wasUploading && !isAnyUploading()) {
      mediaState.isUploading = false;
    }

    onMediaStateChanged();
  }

  Future<void> generateVideoThumbnail(File videoFile, int index) async {
    try {
      final thumbnail = await VideoThumbnail.thumbnailData(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );

      if (thumbnail != null && mounted) {
        mediaState.videoThumbnails[index] = thumbnail;
        onMediaStateChanged();
      }
    } catch (e) {
      debugPrint('generate video thumbnail error: $e');
    }
  }

  Future<void> uploadNewImages() async {
    if (mediaState.isUploading) return;

    mediaState.isUploading = true;
    onMediaStateChanged();

    final indicesToUpload = <int>[];
    for (int i = mediaState.uploadedImageUrls.length;
        i < mediaState.selectedImages.length;
        i++) {
      indicesToUpload.add(i);
    }

    final failedIndices = <int>[];

    try {
      for (int i in indicesToUpload) {
        if (!mounted) return;

        final imageFile = mediaState.selectedImages[i];

        try {
          final exceedsSize = await checkFileSize(imageFile);
          if (exceedsSize) {
            onUploadError(
              'File size exceeds the maximum allowed size of ${mediaConfig.maxFileSizeMB} MiB',
            );
            failedIndices.add(i);
            continue;
          }

          if (mounted) {
            mediaState.imageUploadingStatus[i] = true;
            onMediaStateChanged();
          }

          String uploadFilePath;
          String fileName;

          if (kIsWeb || imageFile.path.startsWith('webfile://')) {
            uploadFilePath = imageFile.path;
            fileName = uploadFilePath.split('/').last;
          } else {
            final processedImageFile = await compressImage(imageFile);
            if (processedImageFile == null) {
              throw Exception('Failed to process image');
            }
            uploadFilePath = processedImageFile.path;
            fileName = uploadFilePath.split('/').last;
          }

          final imageUrl = await uploadImage(uploadFilePath, fileName);

          if (imageUrl != null && imageUrl.isNotEmpty) {
            if (mounted) {
              mediaState.uploadedImageUrls.add(imageUrl);
              mediaState.imageUploadingStatus[i] = false;
              onMediaStateChanged();
            }
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            mediaState.imageUploadingStatus[i] = false;
            onMediaStateChanged();
            onUploadError('Image ${i + 1} upload failed: $e');
            failedIndices.add(i);
          }
        }
      }

      if (mounted && failedIndices.isNotEmpty) {
        failedIndices.sort((a, b) => b.compareTo(a));
        for (int index in failedIndices) {
          removeImage(index);
        }
      }
    } finally {
      if (mounted) {
        mediaState.isUploading = false;
        onMediaStateChanged();
      }
    }
  }

  Future<void> uploadNewVideos() async {
    if (mediaState.isUploading) return;

    mediaState.isUploading = true;
    onMediaStateChanged();

    final indicesToUpload = <int>[];
    for (int i = mediaState.uploadedVideoUrls.length;
        i < mediaState.selectedVideos.length;
        i++) {
      indicesToUpload.add(i);
    }

    final failedIndices = <int>[];

    try {
      for (int i in indicesToUpload) {
        if (!mounted) return;

        final file = mediaState.selectedVideos[i];

        try {
          final exceedsSize = await checkFileSize(file);
          if (exceedsSize) {
            onUploadError(
              'File size exceeds the maximum allowed size of ${mediaConfig.maxFileSizeMB} MiB',
            );
            failedIndices.add(i);
            continue;
          }

          if (mounted) {
            mediaState.videoUploadingStatus[i] = true;
            onMediaStateChanged();
          }

          final currentTime = DateTime.now().microsecondsSinceEpoch.toString();
          String fileName =
              '$currentTime${Path.basenameWithoutExtension(file.path)}.mp4';

          final videoUrl = await uploadVideo(file.path, fileName);

          if (videoUrl != null && videoUrl.isNotEmpty) {
            if (mounted) {
              mediaState.uploadedVideoUrls.add(videoUrl);
              mediaState.videoUploadingStatus[i] = false;
              onMediaStateChanged();
            }
          } else {
            throw Exception('Upload failed');
          }
        } catch (e) {
          if (mounted) {
            mediaState.videoUploadingStatus[i] = false;
            onMediaStateChanged();
            onUploadError('Video ${i + 1} upload failed: $e');
            failedIndices.add(i);
          }
        }
      }

      if (mounted && failedIndices.isNotEmpty) {
        failedIndices.sort((a, b) => b.compareTo(a));
        for (int index in failedIndices) {
          removeVideo(index);
        }
      }
    } finally {
      if (mounted) {
        mediaState.isUploading = false;
        onMediaStateChanged();
      }
    }
  }

  Future<File?> compressImage(File file) async {
    if (kIsWeb) {
      return file;
    }

    try {
      final targetPath = Path.join(
        Path.dirname(file.path),
        '${Path.basenameWithoutExtension(file.path)}_noexif.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: mediaConfig.imageQuality,
      );

      return result != null ? File(result.path) : null;
    } catch (_) {
      return null;
    }
  }

  Widget buildPlatformImage(File image, {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      final data = web_file_registry.getWebFileData(image.path);
      if (data != null) {
        return Image.memory(
          data,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Container(
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

  void _reindexMap<V>(Map<int, V> map, int removedIndex) {
    final newMap = <int, V>{};
    map.forEach((key, value) {
      if (key > removedIndex) {
        newMap[key - 1] = value;
      } else if (key < removedIndex) {
        newMap[key] = value;
      }
    });
    map.clear();
    map.addAll(newMap);
  }

  void _reindexMapNullable<V>(Map<int, V?> map, int removedIndex) {
    final newMap = <int, V?>{};
    map.forEach((key, value) {
      if (key > removedIndex) {
        newMap[key - 1] = value;
      } else if (key < removedIndex) {
        newMap[key] = value;
      }
    });
    map.clear();
    map.addAll(newMap);
  }
}
