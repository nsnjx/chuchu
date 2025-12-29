import 'dart:io';

import 'package:chuchu/core/utils/adapt.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_video_page.dart';


class FeedVideoWidget extends StatefulWidget {
  final String videoUrl;

  const FeedVideoWidget({super.key, required this.videoUrl});

  @override
  _FeedVideoWidgetState createState() => _FeedVideoWidgetState();
}

class _FeedVideoWidgetState extends State<FeedVideoWidget> {
  File? _thumbnailFile;
  bool _isLoadingThumbnail = false;
  String? _thumbnailPath;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }



  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl != oldWidget.videoUrl) {
      if (mounted) {
        _thumbnailFile = null;
        _thumbnailPath = null;
        _generateThumbnail();
      }
    }
  }

  @override
  void dispose() {
    // Clean up temporary thumbnail file if needed
    if (_thumbnailPath != null && _thumbnailPath!.contains('temp_')) {
      try {
        File(_thumbnailPath!).delete();
      } catch (e) {
        // Ignore errors when deleting file
      }
    }
    super.dispose();
  }

  Future<void> _generateThumbnail() async {
    if (widget.videoUrl.isEmpty || _isLoadingThumbnail) return;

    setState(() {
      _isLoadingThumbnail = true;
    });

    try {
      // Check if thumbnail is already cached
      final cachedThumbnail = await _getCachedThumbnail();
      if (cachedThumbnail != null && mounted) {
        setState(() {
          _thumbnailPath = cachedThumbnail.path;
          _thumbnailFile = cachedThumbnail;
          _isLoadingThumbnail = false;
        });
        return;
      }

      // Generate new thumbnail
      final thumbnailFile = await _createThumbnail();
      if (thumbnailFile != null && mounted) {
        setState(() {
          _thumbnailPath = thumbnailFile.path;
          _thumbnailFile = thumbnailFile;
          _isLoadingThumbnail = false;
        });
        
        // Cache the thumbnail
        await _cacheThumbnail(thumbnailFile);
      } else {
        setState(() {
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
        });
      }
      print('Error generating thumbnail: $e');
    }
  }

  Future<File?> _getCachedThumbnail() async {
    try {
      final cacheKey = _getThumbnailCacheKey();
      final cacheDir = await getTemporaryDirectory();
      final thumbnailPath = '${cacheDir.path}/$cacheKey.jpg';
      final thumbnailFile = File(thumbnailPath);
      
      if (await thumbnailFile.exists()) {
        print('Thumbnail loaded from cache: $thumbnailPath');
        return thumbnailFile;
      }
      return null;
    } catch (e) {
      print('Error getting cached thumbnail: $e');
      return null;
    }
  }

  Future<File?> _createThumbnail() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // Generate thumbnail with better quality and consistent naming
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: widget.videoUrl,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 300,
        maxWidth: 400,
        quality: 85,
        timeMs: 1000, // Take thumbnail at 1 second
      );

      if (thumbnailFile != null) {
        return File(thumbnailFile);
      }
      return null;
    } catch (e) {
      print('Error creating thumbnail: $e');
      return null;
    }
  }

  Future<void> _cacheThumbnail(File thumbnailFile) async {
    try {
      final cacheKey = _getThumbnailCacheKey();
      final cacheDir = await getTemporaryDirectory();
      final cachedPath = '${cacheDir.path}/$cacheKey.jpg';
      
      // Copy thumbnail to cache location
      await thumbnailFile.copy(cachedPath);
      print('Thumbnail cached: $cachedPath');
    } catch (e) {
      print('Error caching thumbnail: $e');
    }
  }

  String _getThumbnailCacheKey() {
    // Create a unique cache key based on video URL and dimensions
    final videoHash = widget.videoUrl.hashCode.toString();
    return 'video_thumb_${videoHash}_300x400';
  }

  @override
  Widget build(BuildContext context) {
    return videoMoment();
  }

  Widget videoMoment() {
    return Container(
      margin: EdgeInsets.only(
        bottom: 10.px,
      ),
      child: GestureDetector(
        onTap: () {
          CommonVideoPage.show(widget.videoUrl);
        },
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Background container
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.all(
                  Radius.circular(
                    Adapt.px(12),
                  ),
                ),
              ),
              width: double.infinity,
            ),
            
            // Thumbnail image
            _getPicWidget(),
            
            // Loading indicator
            if (_isLoadingThumbnail)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      Adapt.px(12),
                    ),
                  ),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              ),
            
            // Play button
            CommonImage(
              iconName: 'play_feed_icon.png',
              size: 60.0.px,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getPicWidget() {
    if (_thumbnailFile == null) return const SizedBox();

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xFFC8DBEF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(Adapt.px(12)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/video_unavailable_icon.png',
                width: 28,
                height: 28,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Video unavailable',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
