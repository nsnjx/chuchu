import 'package:video_player/video_player.dart';

VideoPlayerController createVideoControllerFromPath(String path) {
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
