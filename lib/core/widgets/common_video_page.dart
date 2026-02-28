import 'dart:async';
import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';

import 'package:chewie/chewie.dart';
import 'package:chuchu/core/utils/adapt.dart';
import 'package:chuchu/core/widgets/common_toast.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'video_controller_from_path_io.dart' if (dart.library.html) 'video_controller_from_path_web.dart' as video_controller_factory;
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../utils/navigator/navigator.dart';
import '../manager/common_file_cache_manager.dart';
import 'chuchu_Loading.dart';
import 'common_image.dart';


class CommonVideoPage extends StatefulWidget {
  final String videoUrl;
  const CommonVideoPage({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<CommonVideoPage> createState() => _CommonVideoPageState();

  static show(String videoUrl, {BuildContext? context}) {
    return ChuChuNavigator.presentPage(
      context,
          (context) => CommonVideoPage(videoUrl: videoUrl),
      fullscreenDialog: true,
    );
  }
}

class _CommonVideoPageState extends State<CommonVideoPage> {
  final GlobalKey<_CustomControlsState> _customControlsKey = GlobalKey<_CustomControlsState>();
  ChewieController? _chewieController;
  late VideoPlayerController _videoPlayerController;

  static const Color _bgColor = Color(0xFF5B5B5B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializePlayer();
    });
  }

  @override
  void dispose() {
    ChuChuLoading.dismiss();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _onVideoTap() {
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
      _customControlsKey.currentState?.showControls();
    } else {
      _videoPlayerController.play();
      _customControlsKey.currentState?.showControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideoReady = _chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized;
        
    if (!isVideoReady) {
      ChuChuLoading.show();
      return Container(
        color: _bgColor,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            Positioned(
              top: 70,
              left: 10,
              child: GestureDetector(
                onTap: () => ChuChuNavigator.pop(context),
                child: CommonImage(
                  iconName: 'circle_close_icon.png',
                  size: 24.px,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    ChuChuLoading.dismiss();
    return Container(
      color: _bgColor,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _onVideoTap,
            child: SafeArea(
              child: Chewie(
                controller: _chewieController!,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 70),
            padding: EdgeInsets.symmetric(horizontal: 10.px),
            height: 40,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => ChuChuNavigator.pop(context),
                  child: CommonImage(
                    iconName: 'video_del_icon.png',
                    size: 24.px,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => ChuChuNavigator.pop(context),
                      child: CommonImage(
                        iconName: 'setting_icon.png',
                        size: 24.px,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Future<void> initializePlayer() async {
    try {
      if (RegExp(r'https?:\/\/').hasMatch(widget.videoUrl)) {
        final fileInfo = await ChuChuFileCacheManager.get().getFileFromCache(widget.videoUrl);
        if (fileInfo != null && !kIsWeb) {
          _videoPlayerController = video_controller_factory.createVideoControllerFromPath(fileInfo.file.path);
          print('Video loaded from cache: ${fileInfo.file.path}');
        } else {
          _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
          _startCaching();
        }
      } else {
        _videoPlayerController = video_controller_factory.createVideoControllerFromPath(widget.videoUrl);
      }
      
      await Future.wait([_videoPlayerController.initialize()]);
      _createChewieController();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startCaching() {
    _cacheVideo();
  }

  Future<void> _cacheVideo() async {
    try {
      print('Starting video cache process...');
      await ChuChuFileCacheManager.get().downloadFile(widget.videoUrl);
      print('Video cached successfully');
    } catch (e) {
      print('Error caching video: $e');
    }
  }

  void _createChewieController() {
    _chewieController = ChewieController(
      customControls: CustomControls(
        key: _customControlsKey,
        videoPlayerController: _videoPlayerController,
        videoUrl: widget.videoUrl,
      ),
      showControls: true,
      videoPlayerController: _videoPlayerController,
      hideControlsTimer: const Duration(seconds: 3),
      autoPlay: true,
      looping: false,
    );
  }


}

class CustomControlsOption {
  final bool isDragging;
  final bool isVisible;
  
  const CustomControlsOption({
    required this.isDragging, 
    required this.isVisible,
  });
}

class CustomControls extends StatefulWidget {
  final VideoPlayerController videoPlayerController;
  final String videoUrl;
  
  const CustomControls({
    Key? key, 
    required this.videoPlayerController, 
    required this.videoUrl,
  }) : super(key: key);

  @override
  _CustomControlsState createState() => _CustomControlsState();
}

class _CustomControlsState extends State<CustomControls> {
  ValueNotifier<CustomControlsOption> customControlsStatus =
      ValueNotifier(const CustomControlsOption(
        isVisible: true,
        isDragging: false,
      ));

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.videoPlayerController.addListener(() {
      if (!widget.videoPlayerController.value.isPlaying &&
          !customControlsStatus.value.isDragging) {
        customControlsStatus.value = CustomControlsOption(
          isVisible: true,
          isDragging: false,
        );
      }
      if (mounted) {
        setState(() {});
      }
    });
    hideControlsAfterDelay();
  }

  void hideControlsAfterDelay() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      customControlsStatus.value = CustomControlsOption(
        isVisible: false,
        isDragging: customControlsStatus.value.isDragging,
      );
    });
  }

  void showControls() {
    customControlsStatus.value = CustomControlsOption(
      isVisible: true,
      isDragging: customControlsStatus.value.isDragging,
    );
    hideControlsAfterDelay();
  }

  void _toggleControls() {
    final isVisible = customControlsStatus.value.isVisible;
    final isPlaying = widget.videoPlayerController.value.isPlaying;
    
    if (isVisible && isPlaying) {
      hideControlsAfterDelay();
    } else {
      customControlsStatus.value = CustomControlsOption(
        isVisible: false,
        isDragging: customControlsStatus.value.isDragging,
      );
      _hideTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: _toggleControls,
            child: Container(),
          ),
        ),
        _buildProgressBar(),
        _buildBottomOption(),
      ],
    );
  }

  Widget _buildBottomOption() {
    return ValueListenableBuilder<CustomControlsOption>(
      valueListenable: customControlsStatus,
      builder: (context, value, child) {
        if (!value.isVisible) return Container();
        return Positioned(
          bottom: 10.0,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _downloadVideo,
                child: CommonImage(
                  iconName: 'icon_download.png',
                  size: 24.px,
                ),
              ),
              _buildPlayPause(),
              Container(
                width: 24,
                height: 24,
              ),
              // GestureDetector(
              //   onTap: toggleFullScreen,
              //   child: CommonImage(
              //     iconName: 'video_screen_icon.png',
              //     size: 24.px,
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }

  void toggleFullScreen() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  Widget _buildPlayPause() {
    return ValueListenableBuilder<CustomControlsOption>(
      valueListenable: customControlsStatus,
      builder: (context, value, child) {
        final isPlaying = widget.videoPlayerController.value.isPlaying;
        final isDragging = value.isDragging;
        final isVisible = value.isVisible;
        
        final iconName = (isPlaying || isDragging || !isVisible) 
            ? 'video_stop_icon.png' 
            : 'video_palyer_icon.png';
            
        return GestureDetector(
          onTap: () {
            if (isPlaying) {
              widget.videoPlayerController.pause();
              showControls();
            } else {
              widget.videoPlayerController.play();
              hideControlsAfterDelay();
            }
          },
          child: CommonImage(
            iconName: iconName,
            size: 30.px,
          ),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder<CustomControlsOption>(
      valueListenable: customControlsStatus,
      builder: (context, value, child) {
        if (!value.isVisible) return Container();
        return Positioned(
          bottom: 40.0,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.px),
                child: CustomVideoProgressIndicator(
                  controller: widget.videoPlayerController,
                  callback: _progressCallback,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: EdgeInsets.only(left: 10.px),
                    width: 45.px,
                    child: Text(
                      _formatDuration(widget.videoPlayerController.value.position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    width: 45.px,
                    margin: EdgeInsets.only(right: 10.px),
                    child: Text(
                      _formatDuration(widget.videoPlayerController.value.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _progressCallback(bool isStart) {
    if (isStart) {
      _hideTimer?.cancel();
      if (widget.videoPlayerController.value.isPlaying) {
        widget.videoPlayerController.pause();
      }
    } else {
      if (!widget.videoPlayerController.value.isPlaying) {
        widget.videoPlayerController.play();
      }
      hideControlsAfterDelay();
    }
    
    customControlsStatus.value = CustomControlsOption(
      isDragging: isStart,
      isVisible: customControlsStatus.value.isVisible,
    );
  }

  Future<void> _downloadVideo() async {
    try {
      if (widget.videoUrl.isEmpty) {
        _showToast('Invalid video URL');
        return;
      }
      
      ChuChuLoading.show(status: 'Downloading...');

      String fileName;
      String? videoPath;

      if (widget.videoUrl.startsWith('http')) {
        try {
          final fileInfo = await ChuChuFileCacheManager.get().getFileFromCache(widget.videoUrl);
          if (fileInfo != null) {
            videoPath = fileInfo.file.path;
          } else {
            final downloadedFile = await ChuChuFileCacheManager.get().downloadFile(widget.videoUrl);
            videoPath = downloadedFile.file.path;
          }

          final uri = Uri.parse(widget.videoUrl);
          fileName = uri.pathSegments.last;
          if (fileName.isEmpty || !fileName.contains('.')) {
            fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          } else {
            if (!fileName.toLowerCase().endsWith('.mp4')) {
              fileName = '${fileName.split('.').first}.mp4';
            }
          }
        } catch (e) {
          print('Error downloading video: $e');
          ChuChuLoading.dismiss();
          _showToast('Download failed, please check network connection');
          return;
        }
      } else {
        if (kIsWeb) {
          ChuChuLoading.dismiss();
          _showToast('Saving local video is not supported on web');
          return;
        }
        final localFile = File(widget.videoUrl);
        if (await localFile.exists()) {
          videoPath = widget.videoUrl;
          fileName = widget.videoUrl.split('/').last;
          if (fileName.isEmpty) {
            fileName = 'local_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
          } else {
            if (!fileName.toLowerCase().endsWith('.mp4')) {
              fileName = '${fileName.split('.').first}.mp4';
            }
          }
        } else {
          ChuChuLoading.dismiss();
          _showToast('Local video file not found');
          return;
        }
      }

      if (videoPath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        String uniqueFileName;
        
        if (fileName.contains('.')) {
          final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
          final extension = fileName.substring(fileName.lastIndexOf('.'));
          final cleanName = nameWithoutExt.replaceAll(RegExp(r'[^\w\s-]'), '');
          uniqueFileName = cleanName.isNotEmpty 
            ? '${cleanName}_$timestamp$extension'
            : 'video_$timestamp$extension';
        } else {
          final cleanName = fileName.replaceAll(RegExp(r'[^\w\s-]'), '');
          uniqueFileName = cleanName.isNotEmpty 
            ? '${cleanName}_$timestamp.mp4'
            : 'video_$timestamp.mp4';
        }
        
        final result = await ImageGallerySaverPlus.saveFile(
          videoPath,
          name: uniqueFileName,
        );

        ChuChuLoading.dismiss();

        if (result['isSuccess'] == true) {
          _showToast('Video saved to gallery: $uniqueFileName');
        } else {
          _showToast('Failed to save to gallery');
        }
      } else {
        ChuChuLoading.dismiss();
        _showToast('Invalid video file path');
      }

    } catch (e) {
      ChuChuLoading.dismiss();
      print('Error saving video to gallery: $e');
      _showToast('Save failed: $e');
    }
  }



  void _showToast(String message) {
    CommonToast.instance.show(context, message);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    return duration.inHours > 0 
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class CustomVideoProgressIndicator extends StatelessWidget {
  final VideoPlayerController controller;
  final Function callback;

  const CustomVideoProgressIndicator(
      {super.key, required this.controller, required this.callback});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: controller.position.asStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container();
        }
        
        final position = snapshot.data ?? Duration.zero;
        final totalDuration = controller.value.duration.inMilliseconds;
        final progress = totalDuration != 0 
            ? position.inMilliseconds / totalDuration 
            : 0.0;
            
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                callback(true);
                _dragUpdate(context, constraints, details);
              },
              onHorizontalDragEnd: (details) {
                callback(false);
              },
              onHorizontalDragUpdate: (details) =>
                  _dragUpdate(context, constraints, details),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 5,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                    Positioned(
                      left: constraints.maxWidth * progress - 10,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            _dragUpdate(context, constraints, details),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _dragUpdate(context, constraints, details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.globalToLocal(details.globalPosition);
    double newProgress = offset.dx / constraints.maxWidth;
    newProgress = newProgress.clamp(0.0, 1.0);
    controller.seekTo(controller.value.duration * newProgress);
  }
}
