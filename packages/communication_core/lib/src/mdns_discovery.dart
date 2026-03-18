import 'dart:async';
import 'package:nsd/nsd.dart' as nsd;

typedef MdnsServiceFound = void Function(String ip, int port);

class MdnsDiscovery {
  nsd.Discovery? _discovery;

  Future<void> start({required MdnsServiceFound onFound}) async {
    await stop();
    _discovery = await nsd.startDiscovery('_dartchat._tcp');

    _discovery!.addServiceListener((service, status) {
      if (status == nsd.ServiceStatus.found &&
          service.addresses != null &&
          service.addresses!.isNotEmpty) {
        final ip = service.addresses!.first.address;
        final port = service.port ?? 8080;
        onFound(ip, port);
      }
    });
  }

  Future<void> stop() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
  }
}