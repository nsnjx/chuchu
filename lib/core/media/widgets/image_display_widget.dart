import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:flutter/material.dart';
import 'upload_status_badge.dart';

class ImageDisplayWidget extends StatelessWidget {
  final List<File> selectedImages;
  final List<String> uploadedUrls;
  final Map<int, bool> uploadingStatus;
  final void Function(int index) onRemove;
  final double? singleImageAspectRatio;
  final Widget Function(File file, {BoxFit fit})? imageBuilder;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double carouselHeight;
  final double carouselItemWidth;

  const ImageDisplayWidget({
    super.key,
    required this.selectedImages,
    required this.uploadedUrls,
    required this.uploadingStatus,
    required this.onRemove,
    this.singleImageAspectRatio,
    this.imageBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.borderRadius = 12,
    this.carouselHeight = 130,
    this.carouselItemWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedImages.isEmpty) return const SizedBox();

    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: selectedImages.length == 1
              ? _buildSingleImage(context, selectedImages[0], 0)
              : _buildImageCarousel(context),
        ),
      ),
    );
  }

  Widget _buildSingleImage(BuildContext context, File image, int index) {
    final isUploaded = index < uploadedUrls.length;
    final isUploading = uploadingStatus[index] ?? false;

    return Stack(
      key: const ValueKey('single'),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              _buildImage(image),
              if (isUploading) _buildUploadingOverlay(),
            ],
          ),
        ),
        _buildRemoveButton(index, top: 12, right: 24),
        if (isUploaded) const UploadStatusBadge(text: 'Uploaded', left: 20),
      ],
    );
  }

  Widget _buildImageCarousel(BuildContext context) {
    return SizedBox(
      key: const ValueKey('multi'),
      height: carouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: selectedImages.length,
        itemBuilder: (context, index) {
          final image = selectedImages[index];
          final isUploaded = index < uploadedUrls.length;
          final isUploading = uploadingStatus[index] ?? false;

          return Stack(
            children: [
              Container(
                width: carouselItemWidth,
                height: carouselItemWidth,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    SizedBox.expand(child: _buildImage(image)),
                    if (isUploading) _buildUploadingOverlay(small: true),
                    if (isUploaded) const UploadStatusBadge(text: 'Done'),
                  ],
                ),
              ),
              _buildRemoveButton(index, top: 6, right: 14, small: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImage(File file) {
    if (imageBuilder != null) {
      return imageBuilder!(file, fit: BoxFit.cover);
    }
    return Image.file(file as dynamic, fit: BoxFit.cover);
  }

  Widget _buildUploadingOverlay({bool small = false}) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(small ? 12 : 16),
          color: Colors.black54,
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: small ? 2 : 4,
          ),
        ),
      ),
    );
  }

  Widget _buildRemoveButton(
    int index, {
    required double top,
    required double right,
    bool small = false,
  }) {
    return Positioned(
      top: top,
      right: right,
      child: GestureDetector(
        onTap: () => onRemove(index),
        child: CircleAvatar(
          radius: small ? 12 : 14,
          backgroundColor: Colors.black54,
          child: Icon(Icons.close, color: Colors.white, size: small ? 14 : 16),
        ),
      ),
    );
  }
}
