import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models/chat_message.dart';
import 'models/connection_status.dart';
import 'crypto_helper.dart';
import 'pairing_service.dart';

class WebSocketClient {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messagesController = StreamController<ChatMessage>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<ChatMessage> get messagesStream => _messagesController.stream;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _status;

  WebSocket? _socket;
  CryptoHelper? _crypto;
  String? _serverUrl;
  bool _isUpgrading = false;

  Future<void> connectFromUrl(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    final secret = uri.queryParameters['secret'] ?? PairingService.pairingSecret;
    final wsUrl = _toWsUrl(rawUrl);
    await _connect(wsUrl, CryptoHelper(secret));
  }

  Future<void> connectFromMdns(String ip, int port) async {
    final wsUrl = 'ws://$ip:$port/ws?requestPairing=true';
    await _connect(wsUrl, CryptoHelper(PairingService.pairingSecret));
  }

  void send(String text) {
    if (_socket == null || _status != ConnectionStatus.connected) return;
    _socket!.add(_crypto!.encrypt(jsonEncode({'message': text})));
    _messagesController.add(ChatMessage.local(text));
  }

  void _emit(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Future<void> disconnect() async {
    _isUpgrading = false;
    await _socket?.close();
    _socket = null;
    _emit(ConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _messagesController.close();
  }

  Future<void> _connect(String wsUrl, CryptoHelper crypto) async {
    _emit(ConnectionStatus.pairing);
    try {
      final socket = await WebSocket.connect(wsUrl)
          .timeout(const Duration(seconds: 10));
      _attachSocket(socket, wsUrl, crypto);
    } catch (e) {
      _emit(ConnectionStatus.error);
      rethrow;
    }
  }

  void _attachSocket(WebSocket socket, String url, CryptoHelper crypto) {
    _socket = socket;
    _serverUrl = url;
    _crypto = crypto;
    _emit(ConnectionStatus.connected);

    socket.listen(
      // ← sync callback, schedules async work via unawaited
      (data) => unawaited(_handleIncoming(data)),
      onDone: () {
        if (!_isUpgrading) {
          _socket = null;
          _emit(ConnectionStatus.disconnected);
        }
      },
      onError: (_) {
        if (!_isUpgrading) {
          _socket = null;
          _emit(ConnectionStatus.error);
        }
      },
      cancelOnError: false,
    );
  }

  Future<void> _handleIncoming(dynamic data) async {
    try {
      final decoded = jsonDecode(_crypto!.decrypt(data as String))
          as Map<String, dynamic>;

      if (decoded['secret'] != null && decoded['token'] != null) {
        await _upgradeToPairedConnection(
          decoded['secret'] as String,
          decoded['token'] as String,
        );
        return;
      }

      _messagesController.add(ChatMessage.remote(decoded['message'] as String));
    } catch (_) {
      // malformed — drop silently
    }
  }

  Future<void> _upgradeToPairedConnection(
      String newSecret, String token) async {
    final uri = Uri.parse(_serverUrl!);
    final newUrl = 'ws://${uri.host}:${uri.port}/ws?token=$token';

    // Set flag BEFORE anything async so onDone can see it immediately
    _isUpgrading = true;

    final oldSocket = _socket;
    _socket = null; // detach before close so onDone guard works

    await oldSocket?.close();

    try {
      await _connect(newUrl, CryptoHelper(newSecret));
    } finally {
      _isUpgrading = false;
    }
  }

  String _toWsUrl(String url) => url
      .replaceFirst('http://', 'ws://')
      .replaceFirst('/connect', '/ws');
}