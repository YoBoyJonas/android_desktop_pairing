import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_app/crypto_helper.dart';
import 'package:android_app/chat_screen.dart';
import 'package:nsd/nsd.dart' as nsd;

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController controller = MobileScannerController(autoStart: false);
  CryptoHelper? _crypto;
  nsd.Discovery? _activeDiscovery;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      controller.start();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required')),
      );
    }
  }

  String _toWsUrl(String scannedUrl) {
    return scannedUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('/connect', '/ws');
  }

  Future<void> _connectToServer(String rawUrl) async {
    final uri = Uri.parse(rawUrl);
    final secret = uri.queryParameters['secret'] ?? 'mDNS_DEFAULT';
    _crypto = CryptoHelper(secret);

    final String wsUrl = rawUrl.startsWith('http') ? _toWsUrl(rawUrl) : rawUrl;

    try {
      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            socket: socket,
            crypto: _crypto!,
            onDisconnect: () {
              controller.start();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Connection failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  void _showManualEntryDialog() {
    final TextEditingController textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Entry'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: 'Paste URL from desktop'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (textController.text.isNotEmpty) {
                controller.stop();
                _connectToServer(textController.text);
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
                    child: Text('Searching for Desktop via mDNS...'),
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
    super.dispose();
  }
}