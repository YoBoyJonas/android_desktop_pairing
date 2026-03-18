import 'package:flutter/material.dart';
import 'package:communication_core/communication_core.dart';
import 'package:shared_ui/shared_ui.dart';

void main() => runApp(const DesktopApp());

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ServerScreen());
  }
}

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late final WebSocketServer _server;
  late final MdnsService _mdns;
  String? _ipAddress;  // nullable instead of late

  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _server = WebSocketServer(port: 8080);
    _mdns = MdnsService();

    await _server.start();

    final ip = await getLocalIpAddress();
    await _mdns.register(name: 'Desktop-Server', port: 8080);

    _server.statusStream.listen((s) => setState(() => _status = s));
    _server.messagesStream.listen((m) => setState(() => _messages.add(m)));

    setState(() => _ipAddress = ip);  // triggers rebuild once ready
  }

  @override
  Widget build(BuildContext context) {
    // Guard: show loader until async init completes
    if (_ipAddress == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final qrUrl = PairingService().buildPairingUrl(
      _ipAddress!, 8080, _server.credentials,
    );

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: PairingQrCard(url: qrUrl, statusLabel: _status.label),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(child: ChatMessageList(messages: _messages)),
                ChatInputBar(
                  enabled: _status == ConnectionStatus.connected,
                  onSend: _server.send,
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
    _server.dispose();
    _mdns.unregister();
    super.dispose();
  }
}