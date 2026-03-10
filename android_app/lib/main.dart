import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_app/crypto_helper.dart';

void main() => runApp(AndroidApp());

class AndroidApp extends StatelessWidget {
  const AndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Client',
      theme: ThemeData(primarySwatch: Colors.green),
      home: ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  WebSocket? _socket;
  bool _isConnected = false;
  final List<String> _messages = [];
  final _textController = TextEditingController();
  String _sharedSecret = '';        
  CryptoHelper? _crypto;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  String? _lastUrl; // remember last URL to reconnect to 
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    await Permission.camera.request();
  }

  // Converts http://host/connect?token=X  →  ws://host/ws?token=X
  String _toWsUrl(String scannedUrl) {
    return scannedUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/connect', '/ws');
  }

// Add timer field (you already have these declared, just unused)
// _reconnectTimer, _reconnectAttempts, _isReconnecting, _lastUrl — already in your code!

Future<void> _connectToServer(String rawUrl) async {
  _lastUrl = rawUrl;
  final uri = Uri.parse(rawUrl);
  final secret = uri.queryParameters['secret']!;
  _sharedSecret = secret;
  _crypto = CryptoHelper(secret);

  final wsUrl = _toWsUrl(rawUrl);
  try {
    final socket = await WebSocket.connect(wsUrl);
    setState(() {
      _socket = socket;
      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0; // reset on success
    });

    socket.listen(
      (data) {
        final decrypted = _crypto!.decrypt(data);
        final decoded = jsonDecode(decrypted);
        setState(() => _messages.add('🖥️ ${decoded['message']}'));
      },
      onDone: () {
        setState(() {
          _isConnected = false;
          _socket = null;
        });
        _scheduleReconnect(); // ← only change here
      },
      onError: (e) {
        setState(() {
          _isConnected = false;
          _socket = null;
        });
        _scheduleReconnect(); // ← and here
      },
    );
  } catch (e) {
    _scheduleReconnect(); // ← and here
  }
}

void _scheduleReconnect() {
  if (_lastUrl == null) return;
  if (_reconnectAttempts >= _maxReconnectAttempts) {
    setState(() => _isReconnecting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not reconnect after $_maxReconnectAttempts attempts')));
    return;
  }

  setState(() => _isReconnecting = true);
  _reconnectAttempts++;

  final delay = Duration(seconds: _reconnectAttempts * 2); // 2s, 4s, 6s...
  _reconnectTimer = Timer(delay, () => _connectToServer(_lastUrl!));
}

// Update _disconnect() to cancel any pending reconnect
void _disconnect() {
  _reconnectTimer?.cancel();
  _reconnectAttempts = _maxReconnectAttempts; // prevent auto-reconnect
  _socket?.close();
  setState(() {
    _socket = null;
    _isConnected = false;
    _isReconnecting = false;
    _messages.clear();
    _lastUrl = null;
  });
}

  void _sendMessage(String message) {
    if (_socket != null) {
      final encrypted = _crypto!.encrypt(jsonEncode({'message': message}));
      _socket!.add(encrypted); // send encrypted
      setState(() => _messages.add('📱 $message'));
    }
  }

  void _showManualEntryDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manual Entry'),
        content: TextField(
          controller: textController,
          decoration: InputDecoration(hintText: 'Paste URL from desktop'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (textController.text.isNotEmpty) {
                controller.stop();
                _connectToServer(textController.text);
              }
            },
            child: Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isReconnecting
      ? 'Reconnecting... ($_reconnectAttempts/$_maxReconnectAttempts)'
      : 'Connected'),
          actions: [
            IconButton(icon: Icon(Icons.close), onPressed: _disconnect),
          ],
        ),
        body: Column(
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
                        hintText: 'Send message to desktop...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (v) {
                        _sendMessage(v);
                        _textController.clear();
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _sendMessage(_textController.text);
                      _textController.clear();
                    },
                    child: Text('Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
        actions: [
          IconButton(icon: Icon(Icons.keyboard), onPressed: _showManualEntryDialog),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              controller.stop();
              _connectToServer(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _socket?.close();
    _textController.dispose();
    super.dispose();
  }
}