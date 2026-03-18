import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PairingQrCard extends StatelessWidget {
  final String url;           // full ws:// or http:// pairing URL
  final String statusLabel;   // comes from ConnectionStatusBadge or parent

  const PairingQrCard({
    super.key,
    required this.url,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Scan to connect', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 250,
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          url,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Text(statusLabel, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}