import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_app/crypto_helper.dart';
import 'package:nsd/nsd.dart' as nsd;

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
  String _sharedSecret = 'mDNS_DEFAULT';        
  CryptoHelper? _crypto;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  String? _lastUrl; // remember last URL to reconnect to 
  Timer? _reconnectTimer;
  nsd.Discovery? _activeDiscovery;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _startDiscovery();
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

void _startDiscovery() async {
  // Stop existing discovery if running
  await _stopDiscovery();

  final discovery = await nsd.startDiscovery('_dartchat._tcp');
  setState(() => _activeDiscovery = discovery);
  
  discovery.addServiceListener((service, status) {
    if (status == nsd.ServiceStatus.found && 
        service.addresses != null && 
        service.addresses!.isNotEmpty) {
      
      final ip = service.addresses!.first.address;
      final port = service.port;

      print('Resolved service at $ip:$port');
      _stopDiscovery();

      // We connect using a pairing request since we don't have a token yet
      _connectToServer('ws://$ip:$port/ws?requestPairing=true&secret=mDNS_DEFAULT');
    }
  });
}

Future<void> _stopDiscovery() async {
  if (_activeDiscovery != null) {
    await nsd.stopDiscovery(_activeDiscovery!);
    setState(() => _activeDiscovery = null);
  }
}

void _onServiceFound(nsd.Service service) {
  final ip = service.addresses?.first.address;
  final port = service.port;
  
  if (ip != null) {
    _stopDiscovery();

    _connectToServer('ws://$ip:$port/ws?requestPairing=true');
  }
}

Future<void> _connectToServer(String rawUrl) async {
  _lastUrl = rawUrl;
  final uri = Uri.parse(rawUrl);
  
  // Safely extract secret or use default
  final secret = uri.queryParameters['secret'] ?? 'mDNS_DEFAULT';
  _sharedSecret = secret;
  _crypto = CryptoHelper(secret);

  // Determine the WebSocket URL
  String wsUrl;
  if (rawUrl.startsWith('http')) {
    wsUrl = _toWsUrl(rawUrl);
  } else {
    wsUrl = rawUrl; // Already ws://
  }
  
  try {
    final socket = await WebSocket.connect(wsUrl).timeout(
      const Duration(seconds: 10),
    );

    setState(() {
      _socket = socket;
      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;
    });

    socket.listen(
      (data) {
        try {
          final decrypted = _crypto!.decrypt(data);
          final decoded = jsonDecode(decrypted);
          if (decoded['message'] == 'Pairing Successful!') {
            debugPrint("UPGRADING ENCRYPTION KEYS...");
            setState(() {
              _sharedSecret = decoded['secret'];
              _crypto = CryptoHelper(_sharedSecret); 
              _messages.add('🛡️ Secure connection established!');
            });
            return; 
          }
          setState(() => _messages.add('🖥️ ${decoded['message']}'));
        } catch (e) {
          debugPrint("Decryption error: $e");
          setState(() => _messages.add('🖥️ $data')); 
        }
      },
      onDone: () => _handleDisconnection('Server closed'),
      onError: (e) => _handleDisconnection('Error: $e'),
      cancelOnError: true, 
    );
  } catch (e) {
    debugPrint("Connection failed: $e");
    _scheduleReconnect();
  }
}

// Helper to consolidate state cleanup
void _handleDisconnection(String reason) {
  debugPrint(reason);
  if (_isConnected) {
    setState(() {
      _isConnected = false;
      _socket = null;
    });
    _scheduleReconnect();
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
      title: const Text('Connect to Desktop'),
      actions: [
        // Button to trigger mDNS discovery
        IconButton(
          icon: Icon(_activeDiscovery != null ? Icons.sync : Icons.search), 
          onPressed: _startDiscovery,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard), 
          onPressed: _showManualEntryDialog,
        ),
      ],
    ),
    body: Stack(
      children: [
        MobileScanner(
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
        if (_activeDiscovery != null)
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Searching for Desktop via mDNS..."),
                ),
              ),
            ),
          ),
      ],
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