import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_app/crypto_helper.dart';

class ChatScreen extends StatefulWidget {
  final WebSocket socket;
  final CryptoHelper crypto;
  final VoidCallback onDisconnect;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.crypto,
    required this.onDisconnect,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<String> _messages = [];
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.socket.listen(
      (data) {
        try {
          final decrypted = widget.crypto.decrypt(data);
          final decoded = jsonDecode(decrypted);
          setState(() => _messages.add('🖥️ ${decoded['message']}'));
        } catch (e) {
          setState(() => _messages.add('🖥️ $data'));
        }
      },
      onDone: () {
        widget.onDisconnect();
        Navigator.pop(context);
      },
      onError: (_) {
        widget.onDisconnect();
        Navigator.pop(context);
      },
      cancelOnError: true,
    );
  }

  void _sendMessage(String message) {
    final encrypted = widget.crypto.encrypt(jsonEncode({'message': message}));
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