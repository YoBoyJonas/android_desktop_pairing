import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_app/crypto_helper.dart';
import 'package:android_app/chat_screen.dart';
import 'package:nsd/nsd.dart' as nsd;

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  nsd.Discovery? _activeDiscovery;
  bool _isConnecting = false;
  CryptoHelper? _crypto;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    await _stopDiscovery();
    final discovery = await nsd.startDiscovery('_dartchat._tcp');
    setState(() => _activeDiscovery = discovery);

    discovery.addServiceListener((service, status) {
      if (status == nsd.ServiceStatus.found &&
          service.addresses != null &&
          service.addresses!.isNotEmpty) {
        final ip = service.addresses!.first.address;
        final port = service.port;
        _stopDiscovery();
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

  Future<void> _connectToServer(String wsUrl) async {
    setState(() => _isConnecting = true);
    _crypto = CryptoHelper('mDNS_DEFAULT');

    try {
      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            socket: socket,
            crypto: _crypto!,
            onDisconnect: () {},
          ),
        ),
      );
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Desktop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Retry',
            onPressed: _startDiscovery,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isConnecting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Connecting...'),
            ] else if (_activeDiscovery != null) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Searching for desktop on network...'),
            ] else ...[
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 16),
              const Text('No desktop found'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _startDiscovery,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }
}