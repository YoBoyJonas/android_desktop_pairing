import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:communication_core/communication_core.dart';
import 'chat_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(autoStart: false);
  final _client = WebSocketClient();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _controller.start();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required')),
      );
    }
  }

  Future<void> _connectFromUrl(String rawUrl) async {
    _controller.stop();
    try {
      await _client.connectFromUrl(rawUrl);
      if (!mounted) return;
      _goToChat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
      _controller.start();
    }
  }

  void _goToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          client: _client,
          onDisconnect: () => _controller.start(),
        ),
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Entry'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'Paste URL from desktop'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textController.text.isNotEmpty) {
                _connectFromUrl(textController.text);
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Desktop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Manual entry',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            if (barcode.rawValue != null) {
              _connectFromUrl(barcode.rawValue!);
              break;
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }
}