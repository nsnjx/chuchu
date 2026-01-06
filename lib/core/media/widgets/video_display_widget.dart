import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'upload_status_badge.dart';

class VideoDisplayWidget extends StatelessWidget {
  final List<File> selectedVideos;
  final List<String> uploadedUrls;
  final Map<int, bool> uploadingStatus;
  final Map<int, Uint8List?> thumbnails;
  final void Function(int index) onRemove;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double singleVideoHeight;
  final double carouselHeight;
  final double carouselItemWidth;

  const VideoDisplayWidget({
    super.key,
    required this.selectedVideos,
    required this.uploadedUrls,
    required this.uploadingStatus,
    required this.thumbnails,
    required this.onRemove,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.borderRadius = 12,
    this.singleVideoHeight = 200,
    this.carouselHeight = 130,
    this.carouselItemWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedVideos.isEmpty) return const SizedBox();

    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
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
            child: selectedVideos.length == 1
                ? _buildSingleVideo(context, selectedVideos[0], 0)
                : _buildVideoCarousel(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleVideo(BuildContext context, File video, int index) {
    final isUploaded = index < uploadedUrls.length;
    final isUploading = uploadingStatus[index] ?? false;
    final thumbnail = thumbnails[index];

    return Stack(
      key: const ValueKey('single_video'),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              if (thumbnail != null)
                Image.memory(
                  thumbnail,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: singleVideoHeight,
                )
              else
                Container(
                  width: double.infinity,
                  height: singleVideoHeight,
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (isUploading) _buildUploadingOverlay(),
            ],
          ),
        ),
        _buildRemoveButton(index, top: 12, right: 24),
        if (isUploaded) const UploadStatusBadge(text: 'Uploaded', left: 16),
      ],
    );
  }

  Widget _buildVideoCarousel(BuildContext context) {
    return SizedBox(
      key: const ValueKey('multi_video'),
      height: carouselHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: selectedVideos.length,
        itemBuilder: (context, index) {
          final isUploaded = index < uploadedUrls.length;
          final isUploading = uploadingStatus[index] ?? false;
          final thumbnail = thumbnails[index];

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
                    if (thumbnail != null)
                      Image.memory(
                        thumbnail,
                        fit: BoxFit.cover,
                        width: carouselItemWidth,
                        height: carouselItemWidth,
                      )
                    else
                      Container(
                        width: carouselItemWidth,
                        height: carouselItemWidth,
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                      ),
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
