import 'package:flutter/material.dart';
import 'package:communication_core/communication_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:notification_service/notification_service.dart';
import 'package:window_manager/window_manager.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> with WindowListener{
  bool _isWindowFocused = true;
  late final WebSocketServer _server;
  late final MdnsService _mdns;
  String? _ipAddress;  

  ConnectionStatus _status = ConnectionStatus.disconnected;
  final List<ChatMessage> _messages = [];

  Future<void> _init() async {
    _server = WebSocketServer();
    _mdns = MdnsService();

    await _server.start();
    final ip = await getLocalIpAddress();
    await _mdns.register(name: 'Desktop-Server', port: _server.actualPort);

    _server.statusStream.listen((s) => setState(() => _status = s));
    _server.messagesStream.listen((m) {
      setState(() => _messages.add(m));
      if(!_isWindowFocused){
        NotificationService.instance.showMessageNotification(
        senderName: "android_app", 
        messagePreview: m.text);
      }
    });

    setState(() => _ipAddress = ip); 
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
      _ipAddress!, _server.actualPort, _server.credentials,
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
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true); // Prevent app from exiting on 'X' click
    _init();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _server.dispose();
    _mdns.unregister();
    super.dispose();
  }

  @override
  void onWindowFocus() => setState(() => _isWindowFocused = true);

  @override
  void onWindowBlur() => setState(() => _isWindowFocused = false);

  @override
  void onWindowMinimize() => setState(() => _isWindowFocused = false);

  @override
  void onWindowRestore() => setState(() => _isWindowFocused = true);

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }
}