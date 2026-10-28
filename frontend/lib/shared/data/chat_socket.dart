import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/api_config.dart';
import 'message_service.dart';

/// Receive-only push channel for chat. Messages are still *sent* through
/// [MessageService.sendMessage]; the server then pushes the saved message as
/// `message:new` to both parties (and to the sender's other devices).
///
/// Socket.IO reconnects on its own after the phone drops its connection. A
/// push that happened while disconnected is gone, so every [connects] event
/// tells listeners to catch up over REST with `?after=<last message id>`.
abstract final class ChatSocket {
  static io.Socket? _socket;

  static final _messages = StreamController<MessageRecord>.broadcast();
  static final _connects = StreamController<void>.broadcast();

  /// Every message saved on any of the signed-in user's threads.
  static Stream<MessageRecord> get messages => _messages.stream;

  /// Fires on every (re)connect, including the first one.
  static Stream<void> get connects => _connects.stream;

  /// Opens the socket for [token]. The token rides in the handshake `auth`
  /// field rather than the URL so it never ends up in server logs.
  static void connect(String token) {
    disconnect();
    final socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    socket.onConnect((_) => _connects.add(null));
    socket.on('message:new', (data) {
      if (data is Map) _messages.add(MessageRecord.fromJson(Map<String, dynamic>.from(data)));
    });
    socket.connect();
    _socket = socket;
  }

  static void disconnect() {
    _socket
      ?..clearListeners()
      ..dispose();
    _socket = null;
  }
}
