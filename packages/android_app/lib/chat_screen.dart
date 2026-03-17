import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_app/crypto_helper.dart';

class ChatScreen extends StatefulWidget {
  final WebSocket socket;
  final CryptoHelper crypto;
  final VoidCallback onDisconnect;
  final String serverUrl;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.crypto,
    required this.onDisconnect,
    required this.serverUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> _messages = [];
  final _textController = TextEditingController();
  late CryptoHelper _crypto;

  @override
  void initState() {
    super.initState();
    _crypto = widget.crypto;
    widget.socket.listen(
      (data) async {
      try {
      final decrypted = _crypto.decrypt(data);
      final decoded = jsonDecode(decrypted);

if (decoded['secret'] != null && decoded['token'] != null) {
  final newSecret = decoded['secret'];
  final token = decoded['token'];

  await widget.socket.close();

  final uri = Uri.parse(widget.serverUrl);

  final newWsUrl =
      'ws://${uri.host}:${uri.port}/ws?token=$token';

  try {
    final newSocket = await WebSocket.connect(newWsUrl);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          socket: newSocket,
          crypto: CryptoHelper(newSecret),
          serverUrl: newWsUrl, // 👈 IMPORTANT
          onDisconnect: widget.onDisconnect,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reconnect failed: $e')),
    );
  }

  return;
}

      // Normal message
      setState(() => _messages.add('🖥️ ${decoded['message']}'));
    } catch (e) {
      setState(() => _messages.add('🖥️ $data'));
    }
  });
  }

  void _sendMessage(String message) {
    final encrypted = _crypto.encrypt(jsonEncode({'message': message}));
    widget.socket.add(encrypted);
    setState(() => _messages.add('📱 $message'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              widget.socket.close();
              widget.onDisconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(_messages[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Send message to desktop...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _sendMessage(v);
                      _textController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _sendMessage(_textController.text);
                    _textController.clear();
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}