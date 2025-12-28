import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for dart:io classes
import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:chuchu/core/utils/string_util.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../utils/aes_encrypt_utils.dart';
import '../widgets/chuchu_Loading.dart';
import 'blossom_server_manager.dart';
import 'file_type.dart';

class UploadUtils {
  static Future<UploadResult> uploadFile({
    BuildContext? context,
    params,
    String? encryptedKey,
    String? encryptedNonce,
    required File file,
    required String filename,
    required FileType fileType,
    bool showLoading = false,
    bool autoStoreImage = true,
    Function(double progress)? onProgress,
  }) async {
    // On web platform, file encryption is not supported
    if (kIsWeb && encryptedKey != null && encryptedKey.isNotEmpty) {
      return UploadResult.error('File encryption is not supported on web platform');
    }

    File uploadFile = file;
    File? encryptedFile;
    if (!kIsWeb && encryptedKey != null && encryptedKey.isNotEmpty) {
      String directoryPath = '';
      if (Platform.isAndroid) {
        dynamic extDir = await getExternalStorageDirectory();
        Directory? externalStorageDirectory = extDir as Directory?;
        if (externalStorageDirectory == null) {
          return UploadResult.error('Storage function abnormal');
        }
        directoryPath = externalStorageDirectory.path;
      } else if (Platform.isIOS || Platform.isMacOS) {
        dynamic tempDir = await getTemporaryDirectory();
        Directory temporaryDirectory = tempDir as Directory;
        directoryPath = temporaryDirectory.path;
      }
      encryptedFile = createFolderAndFile(directoryPath + "/encrytedfile", filename);
      // Type cast for non-web platforms where types match
      await AesEncryptUtils.encryptFileInIsolate(
          file as dynamic,
          encryptedFile as dynamic,
          encryptedKey,
          nonce: encryptedNonce,
          mode: AESMode.gcm
      );
      uploadFile = encryptedFile;
    }
    String? url = '';
    if (showLoading) ChuChuLoading.show();
    try {
      url = await BlossomServerManager.shared.uploadWithAutoSwitch(
        filePath: uploadFile.path,
        fileName: filename,
        onProgress: onProgress,
      );
      if (showLoading) ChuChuLoading.dismiss();
      
      if (url == null || url.isEmpty) {
        return UploadResult.error('All Blossom servers failed to upload');
      }
    } catch (e, s) {
      if (showLoading) ChuChuLoading.dismiss();
      return UploadExceptionHandler.handleException(e, s);
    }

    if (encryptedFile != null && encryptedFile.existsSync()) {
      encryptedFile.delete();
    }

    return UploadResult.success(url, encryptedKey, encryptedNonce);
  }

}

File createFolderAndFile(String folderPath, String fileName) {
  Directory folder = Directory(folderPath);
  if (!folder.existsSync()) {
    folder.createSync(recursive: true);
    print('Folder created: $folderPath');
  } else {
    print('Folder already exists: $folderPath');
  }

  File file = File('$folderPath/$fileName');
  if (!file.existsSync()) {
    file.createSync();
    print('File created: $fileName');
  } else {
    print('File already exists: $fileName');
  }
  return file;
}

class UploadResult {
  final bool isSuccess;
  final String url;
  final String? errorMsg;
  final String? encryptedKey;
  final String? encryptedNonce;

  UploadResult({required this.isSuccess, required this.url, this.errorMsg, this.encryptedKey, this.encryptedNonce});

  factory UploadResult.success(String url, String? encryptedKey, String? encryptedNonce) {
    return UploadResult(isSuccess: true, url: url, encryptedKey: encryptedKey, encryptedNonce: encryptedNonce);
  }

  factory UploadResult.error(String errorMsg) {
    return UploadResult(isSuccess: false, url: '', errorMsg: errorMsg);
  }

  @override
  String toString() {
    return '${super.toString()}, url: $url, isSuccess: $isSuccess, errorMsg: $errorMsg';
  }
}

class UploadExceptionHandler {
  static const errorMessage = 'Unable to connect to the file storage server.';

  static UploadResult handleException(dynamic e, [dynamic s]) {
    print('Upload File Exception Handler: $e\r\n$s');
    return UploadResult.error(errorMessage);
    // if (e is ClientException) {
    //   return UploadResult.error(e.message);
    // } else if (e is MinioError) {
    //   return UploadResult.error(e.message ?? errorMessage);
    // } else if (e is DioException) {
    //   if (e.type == DioExceptionType.badResponse) {
    //     String errorMsg = '';
    //     dynamic data = e.response?.data;
    //     if (data != null) {
    //       if (data is Map) {
    //         errorMsg = data['message'];
    //       }
    //       if (data is String) {
    //         errorMsg = data;
    //       }
    //     }
    //     return UploadResult.error(errorMsg);
    //   }
    //   return UploadResult.error(parseError(e));
    // } else if (e is UploadException) {
    //   return UploadResult.error(e.message);
    // } else {
    //   return UploadResult.error(errorMessage);
    // }
  }

  static String parseError(dynamic e) {
    String errorMsg = e.message ?? errorMessage;
    if (e.error is SocketException) {
      SocketException socketException = e.error as SocketException;
      errorMsg = socketException.message;
    }
    if (e.error is HttpException) {
      HttpException httpException = e.error as HttpException;
      errorMsg = httpException.message;
    }
    return errorMsg;
  }
}

class UploadManager {
  static final UploadManager shared = UploadManager._internal();
  UploadManager._internal() {}

  // Key: _cacheKey(uploadId, pubkey)
  Map<String, StreamController<double>> uploadStreamMap = {};

  // Key: _cacheKey(uploadId, pubkey)
  Map<String, UploadResult> uploadResultMap = {};

  StreamController prepareUploadStream(String uploadId, String? pubkey) {
    return uploadStreamMap.putIfAbsent(
      _cacheKey(uploadId, pubkey),
          () => StreamController<double>.broadcast(),
    );
  }

  Future<void> uploadFile({
    required FileType fileType,
    required String filePath,
    required uploadId,
    required String? receivePubkey,
    String? encryptedKey,
    String? encryptedNonce,
    bool autoStoreImage = true,
    Function(UploadResult, bool isFromCache)? completeCallback,
  }) async {
    final cacheKey = _cacheKey(uploadId, receivePubkey);
    final result = uploadResultMap[cacheKey];
    if (result != null && result.isSuccess) {
      completeCallback?.call(result, true);
      return;
    }

    final streamController = prepareUploadStream(uploadId, receivePubkey);
    streamController.add(0.0);
    uploadResultMap.remove(cacheKey);

    final file = File(filePath);
    UploadUtils.uploadFile(
      file: file,
      filename: '${Uuid().v1()}.${filePath.getFileExtension()}',
      fileType: fileType,
      encryptedKey: encryptedKey,
      encryptedNonce: encryptedNonce,
      autoStoreImage: autoStoreImage,
      onProgress: (progress) {
        streamController.add(progress);
      },
    ).then((result) {
      uploadResultMap[cacheKey] = result;
      completeCallback?.call(result, false);
    });
  }

  Stream<double>? getUploadProgress(String uploadId, String? pubkey) {
    final controller = uploadStreamMap[_cacheKey(uploadId, pubkey)];
    if (controller == null) {
      return null;
    }
    return controller.stream;
  }

  UploadResult? getUploadResult(String uploadId, String? receivePubkey) =>
      uploadResultMap[_cacheKey(uploadId, receivePubkey)];

  String _cacheKey(String uploadId, String? pubkey) => '$uploadId-CacheKey-${pubkey ?? ''}';
}
