import 'package:flutter/material.dart';
import 'package:communication_core/communication_core.dart';
import 'chat_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _discovery = MdnsDiscovery();
  final _client = WebSocketClient();
  bool _isSearching = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    setState(() { _isSearching = true; _isConnecting = false; });
    await _discovery.start(onFound: _onServiceFound);
  }

  Future<void> _onServiceFound(String ip, int port) async {
    await _discovery.stop();
    setState(() { _isSearching = false; _isConnecting = true; });

    try {
      await _client.connectFromMdns(ip, port);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(client: _client, onDisconnect: () {}),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
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
            ] else if (_isSearching) ...[
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
    _discovery.stop();
    super.dispose();
  }
}