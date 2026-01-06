/// Configuration for media upload functionality
class MediaUploadConfig {
  /// Whether to check file size before uploading
  final bool checkFileSize;
  
  /// Maximum file size in bytes (default: 20 MiB)
  final int maxFileSize;
  
  /// Whether to support web platform
  final bool supportWeb;
  
  /// Whether to automatically remove failed uploads
  final bool autoRemoveFailed;
  
  /// Image processing quality (0-100)
  final int imageQuality;
  
  /// Whether to remove EXIF data from images
  final bool removeExif;

  const MediaUploadConfig({
    this.checkFileSize = false,
    this.maxFileSize = 20 * 1024 * 1024, // 20 MiB
    this.supportWeb = false,
    this.autoRemoveFailed = false,
    this.imageQuality = 95,
    this.removeExif = true,
  });

  /// Default config for create feed page
  static const MediaUploadConfig createFeed = MediaUploadConfig(
    checkFileSize: true,
    supportWeb: true,
    autoRemoveFailed: true,
  );

  /// Default config for reply page
  static const MediaUploadConfig reply = MediaUploadConfig(
    checkFileSize: false,
    supportWeb: false,
    autoRemoveFailed: false,
  );
}


