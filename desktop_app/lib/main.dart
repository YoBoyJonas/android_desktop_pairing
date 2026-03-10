import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:desktop_android_pairing/crypto_helper.dart';

void main() => runApp(DesktopApp());

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desktop Server',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ServerScreen(),
    );
  }
}

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  HttpServer? _server;
  WebSocket? _connectedClient;
  String? _ipAddress;
  String? _sessionToken;
  String _connectionStatus = 'Not connected';
  bool _isServerRunning = false;
  String _sharedSecret = '';
  late CryptoHelper _crypto;
  final List<String> _messages = [];
  // Add these fields
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;


  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    _sessionToken = _generateToken();   
    _crypto = CryptoHelper(_sharedSecret); 
    _ipAddress = await _getLocalIp();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

    setState(() => _isServerRunning = true);
    //websocket
    _server!.listen((HttpRequest request) async {
      final token = request.uri.queryParameters['token'];
      if (token != _sessionToken) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
        return;
      }

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _onClientConnected(socket);
      }
    });
  }

  void _onClientConnected(WebSocket socket) {
  setState(() {
    _connectedClient = socket;
    _connectionStatus = 'Phone connected!';
  });

  socket.listen(
    (data) {
      final decrypted = _crypto.decrypt(data);
      final decoded = jsonDecode(decrypted);
      setState(() => _messages.add('📱 ${decoded['message']}'));
    },
    onDone: () {
      setState(() {
        _connectedClient = null;
        _connectionStatus = 'Disconnected — waiting for reconnect...';
      });
      _scheduleReconnectWindow(); // ← add this
    },
    onError: (e) {
      setState(() {
        _connectedClient = null;
        _connectionStatus = 'Error: $e';
      });
      _scheduleReconnectWindow(); // ← add this
    },
  );

  socket.add(_crypto.encrypt(jsonEncode({'message': 'Hello from Desktop!'})));
}

void _scheduleReconnectWindow() {
  if (_reconnectAttempts >= _maxReconnectAttempts) {
    setState(() => _connectionStatus = 'Max reconnects reached. Restart app.');
    return;
  }
  _reconnectAttempts++;
  // Server doesn't reconnect — it just stays open listening.
  // Reset status after a delay so UI doesn't stay on "Disconnected" forever.
  _reconnectTimer = Timer(Duration(seconds: 30), () {
    if (_connectedClient == null) {
      setState(() {
        _connectionStatus = 'Not connected';
        _reconnectAttempts = 0;
      });
    }
  });
}

  void _sendToPhone(String message) {
    if (_connectedClient != null) {
      final encrypted = _crypto.encrypt(jsonEncode({'message': message}));
      _connectedClient!.add(encrypted); // send encrypted string
      setState(() => _messages.add('🖥️ $message'));
    }
  }

  Future<String?> _getLocalIp() async {
    final info = NetworkInfo();
    return await info.getWifiIP() ?? 'localhost';
  }

  String _generateToken() {
    final random = Random.secure();
    final tokenBytes = List<int>.generate(16, (i) => random.nextInt(256));
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
  
    _sharedSecret = base64.encode(keyBytes); // store for QR
    return tokenBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _connectedClient?.close();
    _server?.close();
    super.dispose();
  }

  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (!_isServerRunning || _ipAddress == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final url = 'ws://$_ipAddress:8080/ws?token=$_sessionToken';
    final qrUrl = 'http://$_ipAddress:8080/connect?token=$_sessionToken&secret=$_sharedSecret';

    return Scaffold(
      appBar: AppBar(title: Text('Desktop Server')),
      body: Row(
        children: [
          // Left: QR + status
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Scan to connect', style: TextStyle(fontSize: 18)),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(data: qrUrl, version: QrVersions.auto, size: 250),
                ),
                SizedBox(height: 16),
                SelectableText(qrUrl, style: TextStyle(fontSize: 11, color: Colors.grey)),
                SizedBox(height: 12),
                Text(
                  'Status: $_connectionStatus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _connectedClient != null ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          // Right: chat panel
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(_messages[i]),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: 'Send message to phone...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (v) {
                            _sendToPhone(v);
                            _textController.clear();
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _connectedClient == null
                            ? null
                            : () {
                                _sendToPhone(_textController.text);
                                _textController.clear();
                              },
                        child: Text('Send'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}