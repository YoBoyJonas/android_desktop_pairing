import 'dart:convert';
import 'dart:math';
import 'crypto_helper.dart';

class PairingCredentials {
  final String sessionToken;
  final String sharedSecret;

  const PairingCredentials({
    required this.sessionToken,
    required this.sharedSecret,
  });
}

class PairingService {
  static const String pairingSecret = 'mDNS_DEFAULT';

  PairingCredentials generateCredentials() {
    final random = Random.secure();

    final tokenBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final sessionToken =
        tokenBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final sharedSecret = base64.encode(keyBytes);

    return PairingCredentials(
      sessionToken: sessionToken,
      sharedSecret: sharedSecret,
    );
  }

  /// Encodes the pairing handshake payload sent over the socket.
  /// Uses a fixed well-known secret so the phone can decrypt before
  /// it has the real session secret.
  String buildPairingPayload(PairingCredentials credentials) {
    final tempCrypto = CryptoHelper(pairingSecret);
    return tempCrypto.encrypt(
      jsonEncode({
        'message': 'Pairing Successful!',
        'token': credentials.sessionToken,
        'secret': credentials.sharedSecret,
      }),
    );
  }

  /// Returns the pairing URL embedded in the QR code.
  String buildPairingUrl(String ipAddress, int port, PairingCredentials creds) {
    return 'http://$ipAddress:$port/connect'
        '?token=${creds.sessionToken}'
        '&secret=${creds.sharedSecret}';
  }
}