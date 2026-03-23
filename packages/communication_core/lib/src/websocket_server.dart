import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models/chat_message.dart';
import 'models/connection_status.dart';
import 'crypto_helper.dart';
import 'pairing_service.dart';

class WebSocketServer {
  final PairingService _pairingService;

  WebSocketServer() : _pairingService = PairingService();

  // ── Public state streams ──────────────────────────────────────────────────

  late final PairingCredentials credentials;

  final _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final _messagesController =
      StreamController<ChatMessage>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<ChatMessage> get messagesStream => _messagesController.stream;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _status;

  // ── Private state ─────────────────────────────────────────────────────────

  HttpServer? _httpServer;
  WebSocket? _socket;
  CryptoHelper? _crypto;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> start() async {
    credentials = _pairingService.generateCredentials();
    _crypto = CryptoHelper(credentials.sharedSecret);

    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);//0 = random free
    _httpServer!.listen(_handleRequest);
  }

  int get actualPort => _httpServer!.port;

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    await _socket?.close();
    await _httpServer?.close();
    await _statusController.close();
    await _messagesController.close();
  }

  // ── Outbound ──────────────────────────────────────────────────────────────

  void send(String text) {
    if (_socket == null || _status != ConnectionStatus.connected) return;
    final encrypted = _crypto!.encrypt(jsonEncode({'message': text}));
    _socket!.add(encrypted);
    _messagesController.add(ChatMessage.local(text));
  }

  // ── Request routing ───────────────────────────────────────────────────────

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final query = request.uri.queryParameters;

    if (path != '/ws' && path != '/connect') {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
      return;
    }

    final isPairing = query['requestPairing'] == 'true';
    final token = query['token'];

    if (!isPairing && token != credentials.sessionToken) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
      return;
    }

    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);

    if (isPairing) {
      await _handlePairing(socket);
    } else {
      _attachSocket(socket);
    }
  }

  // ── Pairing ───────────────────────────────────────────────────────────────

Future<void> _handlePairing(WebSocket socket) async {
  _emit(ConnectionStatus.pairing);
  socket.add(_pairingService.buildPairingPayload(credentials));
  await Future.delayed(const Duration(milliseconds: 300));
  await socket.close();
}

  // ── Socket management ─────────────────────────────────────────────────────

  void _attachSocket(WebSocket socket) {
    socket.pingInterval = const Duration(seconds: 5);
    _socket = socket;
    _reconnectAttempts = 0;
    _emit(ConnectionStatus.connected);

    socket.listen(
      _handleIncoming,
      onDone: _onSocketClosed,
      onError: (_) => _onSocketClosed(),
    );
  }

  void _handleIncoming(dynamic data) {
    try {
      final decrypted = _crypto!.decrypt(data as String);
      final decoded = jsonDecode(decrypted) as Map<String, dynamic>;
      _messagesController.add(ChatMessage.remote(decoded['message'] as String));
    } catch (_) {
      // Malformed or tampered message — silently drop
    }
  }

  void _onSocketClosed() {
    _socket = null;
    _emit(ConnectionStatus.disconnected);
    _scheduleReconnectWindow();
  }

  void _scheduleReconnectWindow() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _emit(ConnectionStatus.error);
      return;
    }
    _reconnectAttempts++;
    _reconnectTimer = Timer(const Duration(seconds: 30), () {
      if (_socket == null) {
        _reconnectAttempts = 0;
        _emit(ConnectionStatus.disconnected);
      }
    });
  }

  void _emit(ConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }
}