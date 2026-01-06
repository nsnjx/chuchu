import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'dart:typed_data';

class MediaUploadState {
  final List<File> selectedImages;
  final List<String> uploadedImageUrls;
  final Map<int, bool> imageUploadingStatus;
  final List<File> selectedVideos;
  final List<String> uploadedVideoUrls;
  final Map<int, bool> videoUploadingStatus;
  final Map<int, Uint8List?> videoThumbnails;
  bool isUploading;

  MediaUploadState({
    List<File>? selectedImages,
    List<String>? uploadedImageUrls,
    Map<int, bool>? imageUploadingStatus,
    List<File>? selectedVideos,
    List<String>? uploadedVideoUrls,
    Map<int, bool>? videoUploadingStatus,
    Map<int, Uint8List?>? videoThumbnails,
    this.isUploading = false,
  })  : selectedImages = selectedImages ?? [],
        uploadedImageUrls = uploadedImageUrls ?? [],
        imageUploadingStatus = imageUploadingStatus ?? {},
        selectedVideos = selectedVideos ?? [],
        uploadedVideoUrls = uploadedVideoUrls ?? [],
        videoUploadingStatus = videoUploadingStatus ?? {},
        videoThumbnails = videoThumbnails ?? {};

  bool get isAnyUploading {
    for (var status in imageUploadingStatus.values) {
      if (status) return true;
    }
    for (var status in videoUploadingStatus.values) {
      if (status) return true;
    }
    return false;
  }

  bool get hasImages =>
      selectedImages.isNotEmpty || uploadedImageUrls.isNotEmpty;

  bool get hasVideos =>
      selectedVideos.isNotEmpty || uploadedVideoUrls.isNotEmpty;

  bool get allImagesUploaded =>
      selectedImages.isEmpty ||
      uploadedImageUrls.length >= selectedImages.length;

  bool get allVideosUploaded =>
      selectedVideos.isEmpty ||
      uploadedVideoUrls.length >= selectedVideos.length;

  void clear() {
    selectedImages.clear();
    uploadedImageUrls.clear();
    imageUploadingStatus.clear();
    selectedVideos.clear();
    uploadedVideoUrls.clear();
    videoUploadingStatus.clear();
    videoThumbnails.clear();
    isUploading = false;
  }
}
