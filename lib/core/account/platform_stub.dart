// Stub file for web platform
// This file is used when dart:io is not available (web platform)

import 'dart:typed_data';

import 'web_file_registry.dart' as web_file_registry;

class Platform {
  static String get operatingSystem => 'web';
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isLinux => false;
  static bool get isWindows => false;
  static bool get isFuchsia => false;
  static String get version => 'web';
  static String get operatingSystemVersion => 'web';
}

// Stub classes for File and Directory (not functional on web)
class File {
  final String path;
  File(this.path);
  
  File get absolute => this;
  
  bool existsSync() => web_file_registry.getWebFileData(path) != null;
  Future<bool> exists() async => existsSync();
  Future<File> create({bool recursive = false}) async => this;
  File createSync({bool recursive = false}) => this;
  Future<void> delete({bool recursive = false}) async {}
  void deleteSync({bool recursive = false}) {}
  String readAsStringSync({Encoding encoding = Encoding.utf8}) => '';
  Future<String> readAsString({Encoding encoding = Encoding.utf8}) async => '';
  Future<File> writeAsString(String contents, {Encoding encoding = Encoding.utf8, FileMode mode = FileMode.write}) async {
    throw UnsupportedError('File write operations not supported on web');
  }
  File writeAsStringSync(String contents, {Encoding encoding = Encoding.utf8, FileMode mode = FileMode.write}) {
    throw UnsupportedError('File write operations not supported on web');
  }
  Future<File> copy(String newPath) async {
    throw UnsupportedError('File copy operations not supported on web');
  }
  File copySync(String newPath) {
    throw UnsupportedError('File copy operations not supported on web');
  }
  // Note: Uint8List is from dart:typed_data, available on all platforms
  // Using dynamic to avoid import issues
  Future<dynamic> readAsBytes() async => _readBytes();
  dynamic readAsBytesSync() => _readBytes();

  // Get file size in bytes
  Future<int> length() async {
    final data = web_file_registry.getWebFileData(path);
    if (data == null) {
      throw UnsupportedError('File operations not supported on web');
    }
    return data.length;
  }

  Uint8List _readBytes() {
    final data = web_file_registry.getWebFileData(path);
    if (data == null) {
      throw UnsupportedError('File operations not supported on web');
    }
    return data;
  }
}

class Directory {
  final String path;
  Directory(this.path);
  
  Directory get absolute => this;
  
  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<Directory> create({bool recursive = false}) async => this;
  Directory createSync({bool recursive = false}) => this;
  Future<void> delete({bool recursive = false}) async {}
  void deleteSync({bool recursive = false}) {}
  
  Stream<dynamic> list({bool recursive = false, bool followLinks = true}) {
    return Stream.empty();
  }
}

// Stub for HttpOverrides (can be extended like the real one)
class HttpOverrides {
  static HttpOverrides? global;
  
  // Stub method that would be overridden in subclasses
  // Using dynamic to match both stub and real dart:io signatures
  HttpClient createHttpClient(SecurityContext? context) => HttpClient();
  String findProxyFromEnvironment(Uri uri, Map<String, String>? environment) => 'DIRECT';
}

// Stub for HttpClient
class HttpClient {
  dynamic badCertificateCallback;
  Future<HttpClientRequest> getUrl(Uri url) async => throw UnimplementedError();
  void close({bool force = false}) {}
}

// Stub for HttpClientRequest
class HttpClientRequest {
  Future<HttpClientResponse> close() async => throw UnimplementedError();
}

// Stub for HttpClientResponse
class HttpClientResponse {
  int get statusCode => 200;
  Stream<List<int>> get stream => const Stream.empty();
}

// Stub for SecurityContext
class SecurityContext {
  SecurityContext();
}

// Stub for X509Certificate
class X509Certificate {
  X509Certificate();
}

// Stub for exceptions
class SocketException implements Exception {
  final String message;
  SocketException(this.message);
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
}

// Stub for FileMode
enum FileMode {
  read,
  write,
  append,
  writeOnly,
  writeOnlyAppend,
}

// Stub for Encoding
abstract class Encoding {
  static const Encoding utf8 = _Utf8Codec();
  
  String decode(List<int> bytes, {bool allowInvalid = false});
  List<int> encode(String input);
  String get name;
}

class _Utf8Codec implements Encoding {
  const _Utf8Codec();
  
  @override
  String decode(List<int> bytes, {bool allowInvalid = false}) => '';
  
  @override
  List<int> encode(String input) => [];
  
  @override
  String get name => 'utf-8';
}

