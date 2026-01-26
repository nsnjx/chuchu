import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chuchu/core/utils/adapt.dart';
import 'package:chuchu/core/utils/ui_refresh_mixin.dart';
import '../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageViewerPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ImageViewerPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> with ChuChuUIRefreshMixin {
  late PageController _pageController;
  late int _currentIndex;

  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const Curve _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: _animationDuration,
        curve: _animationCurve,
      );
    } else {
      _pageController.animateToPage(
        widget.images.length - 1,
        duration: _animationDuration,
        curve: _animationCurve,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: _animationDuration,
        curve: _animationCurve,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: _animationDuration,
        curve: _animationCurve,
      );
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    // On web, use transparent background so barrierColor shows through
    // On mobile, use semi-transparent black
    final backgroundColor = kIsWeb ? Colors.transparent : Colors.black.withOpacity(0.5);
    
    return Material(
      color: backgroundColor,
      child: Stack(
        children: [
          _buildMainImageViewer(),
          if (widget.images.length > 1) _buildImageCounter(),
          if (widget.images.length > 1) ..._buildNavigationArrows(),
          // Only show bottom gradient overlay on mobile, not on web
          if (!kIsWeb) _buildBottomGradientOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainImageViewer() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // Clickable background to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // Image content
              Center(
                child: GestureDetector(
                  onTap: () {}, // Prevent tap from propagating to background
                  child: kIsWeb
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 1200,
                            maxHeight: double.infinity,
                          ),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 3.0,
                            child: CachedNetworkImage(
                              imageUrl: widget.images[index],
                              fit: BoxFit.contain,
                              placeholder: (context, url) => _buildPlaceholder(),
                              errorWidget: (context, url, error) => _buildErrorWidget(),
                              cacheKey: '${widget.images[index]}#viewer_full',
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        )
                      : InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 3.0,
                          child: CachedNetworkImage(
                            imageUrl: widget.images[index],
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => _buildPlaceholder(),
                            errorWidget: (context, url, error) => _buildErrorWidget(),
                            cacheKey: '${widget.images[index]}#viewer_full',
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.white.withOpacity(0.7),
            size: 64.px,
          ),
          SizedBox(height: 16.px),
          Text(
            'Failed to load image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18.px,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCounter() {
    return Positioned(
      bottom: 30.px,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16.px,
            vertical: 8.px,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20.px),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library,
                color: Colors.white,
                size: 18.px,
              ),
              SizedBox(width: 8.px),
              Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.px,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavigationArrows() {
    return [
      _buildNavigationArrow(
        isLeft: true,
        onTap: _previousPage,
        icon: Icons.chevron_left,
      ),
      _buildNavigationArrow(
        isLeft: false,
        onTap: _nextPage,
        icon: Icons.chevron_right,
      ),
    ];
  }

  Widget _buildNavigationArrow({
    required bool isLeft,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Positioned(
      left: isLeft ? 16.px : null,
      right: isLeft ? null : 16.px,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48.px,
            height: 48.px,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: kTitleColor,
              size: 28.px,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 100.px,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
      ),
    );
  }
}

void showImageViewer({
  required BuildContext context,
  required List<String> images,
  required int initialIndex,
}) {
  if (kIsWeb) {
    // On web, use showGeneralDialog to break out of width constraints
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Image Viewer',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ImageViewerPage(
            images: images,
            initialIndex: initialIndex,
          ),
        );
      },
    );
  } else {
    // On mobile, use Navigator.push
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageViewerPage(
            images: images,
            initialIndex: initialIndex,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      ),
    );
  }
} 