// Conditional export: use NIP-07 bridge on web, stub elsewhere.
export 'nip07_stub.dart' if (dart.library.html) 'nip07_bridge.dart';
