// Stub file for non-web platforms
// This file provides stub implementations when dart:html is not available

class AnchorElement {
  String? href;
  String? target;
  String? download;
  
  AnchorElement({this.href, this.target, this.download});
  
  void click() {
    throw UnsupportedError('AnchorElement.click() is not supported on this platform');
  }
  
  void remove() {
    // No-op on non-web platforms
  }
}

class Document {
  static final Document _instance = Document._();
  factory Document() => _instance;
  Document._();
  
  BodyElement? get body => null;
}

final document = Document();

class BodyElement {
  void append(dynamic element) {
    throw UnsupportedError('BodyElement.append() is not supported on this platform');
  }
}
