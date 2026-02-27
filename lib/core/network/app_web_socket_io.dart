import 'dart:io' if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';

import 'app_web_socket_interface.dart';

class IOAppWebSocket implements AppWebSocket {
  final WebSocket _socket;

  IOAppWebSocket(this._socket);

  @override
  Stream<dynamic> get stream => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  void add(dynamic data) => _socket.add(data);

  @override
  Future<void> close() => _socket.close();
}

Future<AppWebSocket> connectAppWebSocket(String url) async {
  final socket = await WebSocket.connect(url);
  return IOAppWebSocket(socket);
}
