import 'package:flutter/material.dart';
import 'package:communication_core/communication_core.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.connected    => ('Phone connected', Colors.green),
      ConnectionStatus.disconnected => ('Not connected',  Colors.grey),
      ConnectionStatus.pairing      => ('Pairing...',     Colors.orange),
      ConnectionStatus.error        => ('Error',          Colors.red),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}