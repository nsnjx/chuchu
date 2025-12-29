import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:chuchu/core/utils/adapt.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'image_viewer_page.dart';

class CarouselWidget extends StatefulWidget {
  final List<String> items;

  const CarouselWidget({
    super.key,
    required this.items,
  });

  @override
  State<CarouselWidget> createState() => _CarouselWidgetState();
}

class _CarouselWidgetState extends State<CarouselWidget> {
  late PageController _pageController;
  int _currentIndex = 0;
  Map<int, bool> _imageLoadErrors = {}; // Track image loading errors
  Map<int, int> _imageRetryCount = {}; // Track retry count

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }



  // Add image retry method
  void _retryImageLoad(int index) {
    if (_imageRetryCount[index] == null) {
      _imageRetryCount[index] = 0;
    }
    
    if (_imageRetryCount[index]! < 3) { // Max 3 retries
      _imageRetryCount[index] = _imageRetryCount[index]! + 1;
      setState(() {
        _imageLoadErrors[index] = false;
      });
      // Retry image loading
    } else {
      // Max retry attempts reached
    }
  }

  // Build image widget
  Widget _buildImageWidget(String imageUrl, int index) {
    if (_imageLoadErrors[index] == true) {
      // Show retry button
      return Container(
        color: Color(0xFFC8DBEF).withOpacity(0.2),
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
                  'assets/images/image_error_icon.png',
                  width: 28,
                  height: 28,
                ),
              ),

              SizedBox(height: 8),
              Text(
                'Failed to load image',
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

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.grey[600]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(height: 300);
    }

    return Column(
      children: [
        // Carousel content
        Container(
          height: 300,
          child: Stack(
            children: [
              GestureDetector(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final imageUrl = widget.items[index];
                    return GestureDetector(
                      onTap: () {
                        showImageViewer(
                          context: context,
                          images: widget.items,
                          initialIndex: index,
                        );
                      },
                      child: Container(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              // Background image
                              Positioned.fill(
                                child: Container(
                                  child: _buildImageWidget(imageUrl, index),
                                ),
                              ),
                              // Image counter
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.photo_library,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${_currentIndex + 1}/${widget.items.length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              

                              

                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Navigation buttons
              if (widget.items.length > 1) ...[
                // Left button
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentIndex > 0) {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _pageController.animateToPage(
                            widget.items.length - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          color: kTitleColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Right button
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_currentIndex < widget.items.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: kTitleColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ).setPaddingOnly(bottom: 16.0);
  }
}

 