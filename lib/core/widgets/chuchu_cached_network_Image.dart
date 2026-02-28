import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:chuchu/core/utils/num_utils.dart';
import 'package:chuchu/core/utils/string_util.dart';
import 'package:flutter/material.dart';

import 'local_image_provider_io.dart' if (dart.library.html) 'local_image_provider_web.dart' as local_image_provider;
import 'package:crypto/crypto.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../manager/common_file_cache_manager.dart';
import '../utils/adapt.dart';

class ChuChuCachedNetworkImage extends StatelessWidget {

  /// See [CachedNetworkImage.imageUrl]
  final String imageUrl;

  /// See [CachedNetworkImage.fit]
  final BoxFit? fit;

  /// See [CachedNetworkImage.width]
  final double? width;

  /// See [CachedNetworkImage.height]
  final double? height;

  /// See [CachedNetworkImage.placeholder]
  final PlaceholderWidgetBuilder? placeholder;

  /// See [CachedNetworkImage.errorWidget]
  final LoadingErrorWidgetBuilder? errorWidget;

  final bool isThumb;

  ChuChuCachedNetworkImage({
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.isThumb = false,
  });

  @override
  Widget build(BuildContext context) {

    final ratio = MediaQuery.of(context).devicePixelRatio;

    int? memCacheWidth;
    if (width != null && width != double.infinity) {
      memCacheWidth = (width! * ratio).round();
    }

    int? memCacheHeight;
    if (memCacheWidth == null && height != null && height != double.infinity) {
      memCacheHeight = (height! * ratio).round();
    }

    String? cacheKey;
    int? maxWidthDiskCache;
    int? maxHeightDiskCache;
    if (isThumb) {
      cacheKey = '$imageUrl\_thumb';
      maxWidthDiskCache = (80.px * ratio).round();
      maxHeightDiskCache = (80.px * ratio).round();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: placeholder,
      errorWidget: errorWidget,
      cacheManager: ChuChuFileCacheManager.get(),
      cacheKey: cacheKey,
      maxWidthDiskCache: maxWidthDiskCache,
      maxHeightDiskCache: maxHeightDiskCache,
    );
  }
}

extension ChuChuCachedImageProviderEx on CachedNetworkImageProvider {

  static Map<String, Size> sizeCache = {};

  static String _cacheKeyWithBase64(String imageBase64) {
    return md5.convert(utf8.encode(imageBase64)).toString();
  }

  static Size? getImageSizeWithBase64(String imageBase64) {
    final cacheKey = _cacheKeyWithBase64(imageBase64);
    final size = sizeCache[cacheKey];
    if (size != null) return size;

    decodeImageFromList(_base64ToBytes(imageBase64)).then((image) {
      final size = Size(image.width.toDouble(), image.height.toDouble());
      sizeCache[cacheKey] = size;
    });

    return null;
  }

  static ImageProvider create(String uri, {
    double? width,
    double? height,
    double? maxWidth,
    double? maxHeight,
    Map<String, String>? headers,
    BaseCacheManager? cacheManager,
    String? decryptedKey,
    String? decryptedNonce,
  }) {
    final pixelRatio = Adapt.devicePixelRatio;

    final double defaultWidth = Adapt.screenW;
    final double defaultHeight = Adapt.screenH;

    bool widthValid = width?.isValid() ?? false;
    bool heightValid = height?.isValid() ?? false;

    if (!widthValid && maxWidth != null) {
      width = defaultWidth;
      widthValid = true;
    } else if (!heightValid && maxHeight != null) {
      height = defaultHeight;
      heightValid = true;
    } else if (!widthValid && !heightValid) {
      width = defaultWidth;
      widthValid = true;
    }

    final double? maxPixelWidth = maxWidth != null ? maxWidth * pixelRatio : null;
    final double? maxPixelHeight = maxHeight != null ? maxHeight * pixelRatio : null;

    int? resizeWidth;
    int? resizeHeight;
    double? widthFactor;
    double? heightFactor;

    if (widthValid && width != null) {
      final int tempWidth = (width * pixelRatio).round();
      resizeWidth = tempWidth;
      if (maxPixelWidth != null && tempWidth > 0) {
        widthFactor = maxPixelWidth / tempWidth;
      }
    }
    if (heightValid && height != null && height != double.infinity) {
      final int tempHeight = (height * pixelRatio).round();
      resizeHeight = tempHeight;
      if (maxPixelHeight != null && tempHeight > 0) {
        heightFactor = maxPixelHeight / tempHeight;
      }
    }

    final factor = min(widthFactor ?? 1, heightFactor ?? 1);
    if (factor > 0.0 && factor < 1.0) {
      resizeWidth = (resizeWidth?.toDouble() * factor)?.toInt();
      resizeHeight = (resizeHeight?.toDouble() * factor)?.toInt();
    }

    ImageProvider provider;
    if (uri.isImageBase64) {
      provider = MemoryImage(_base64ToBytes(uri));
    } else if (uri.isRemoteURL) {
      provider = CachedNetworkImageProvider(
        uri,
        headers: headers,
        cacheManager: cacheManager ?? ChuChuFileCacheManager.get(encryptKey: decryptedKey, encryptNonce: decryptedNonce),
      );
    } else {
      provider = local_image_provider.createLocalFileImageProvider(uri);
    }

    return ResizeImage.resizeIfNeeded(
      resizeWidth,
      resizeHeight,
      provider,
    );
  }

  static Uint8List _base64ToBytes(String imageBase64) {
    final base64String = imageBase64.split(',').last;
    return base64.decode(base64String);
  }
}