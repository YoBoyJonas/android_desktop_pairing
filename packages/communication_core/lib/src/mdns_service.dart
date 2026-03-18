import 'package:nsd/nsd.dart' as nsd;

class MdnsService {
  nsd.Registration? _registration;

  Future<void> register({
    required String name,
    required int port,
    String type = '_dartchat._tcp',
  }) async {
    try {
      _registration = await nsd.register(
        nsd.Service(name: name, type: type, port: port),
      );
    } catch (e) {
      // non-fatal — app works without mDNS
      // caller can log or surface this via a stream if needed
    }
  }

  Future<void> unregister() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
  }
}