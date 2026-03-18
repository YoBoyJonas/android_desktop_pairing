import 'dart:io';

Future<String> getLocalIpAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  // Prefer common LAN ranges: 192.168.x.x, 10.x.x.x, 172.16-31.x.x
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      final ip = addr.address;
      if (ip.startsWith('192.168.') ||
          ip.startsWith('10.')       ||
          _is172Range(ip)) {
        return ip;
      }
    }
  }

  // Fallback: return first non-loopback address we find
  for (final interface in interfaces) {
    if (interface.addresses.isNotEmpty) {
      return interface.addresses.first.address;
    }
  }

  return 'localhost';
}

bool _is172Range(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final second = int.tryParse(parts[1]) ?? 0;
  return parts[0] == '172' && second >= 16 && second <= 31;
}