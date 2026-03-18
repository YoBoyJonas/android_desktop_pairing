import 'package:flutter/material.dart';
import 'package:communication_core/communication_core.dart';
import 'package:shared_ui/shared_ui.dart';

class ChatScreen extends StatefulWidget {
  final WebSocketClient client;
  final VoidCallback onDisconnect;

  const ChatScreen({
    super.key,
    required this.client,
    required this.onDisconnect,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    widget.client.messagesStream.listen(
      (m) => setState(() => _messages.add(m)),
    );
    widget.client.statusStream.listen((status) {
      if ((status == ConnectionStatus.disconnected ||
          status == ConnectionStatus.error) && mounted) {
        Navigator.pop(context);
        widget.onDisconnect();
      }
    });
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
              widget.client.disconnect();
              widget.onDisconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: ChatMessageList(messages: _messages)),
          ChatInputBar(
            enabled: true,
            onSend: widget.client.send,
          ),
        ],
      ),
    );
  }
}
