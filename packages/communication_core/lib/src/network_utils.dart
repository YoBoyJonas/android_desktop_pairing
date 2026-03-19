import 'dart:io';

Future<String> getLocalIpAddress() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );

  for (final interface in interfaces) {
  print('Interface: ${interface.name}');
  for (final addr in interface.addresses) {
    print('  ${addr.address}');
  }
}
  // Prefer common LAN ranges: 192.168.x.x, 10.x.x.x
  for (final interface in interfaces) {
    for (final addr in interface.addresses) {
      final ip = addr.address;
      if (ip.startsWith('192.168.') ||
          ip.startsWith('10.')) {
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