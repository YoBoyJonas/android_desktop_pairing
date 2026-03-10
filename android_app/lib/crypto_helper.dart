import 'dart:convert';
import 'dart:typed_data'; 
import 'package:encrypt/encrypt.dart';

class CryptoHelper {
  late Key _key;
  late IV _iv;

  // Call this once, pass the same secret to both sides via QR code
  CryptoHelper(String sharedSecret) {
    // Derive a 32-byte key from the secret
    final keyBytes = utf8.encode(sharedSecret.padRight(32).substring(0, 32));
    _key = Key(Uint8List.fromList(keyBytes));
    _iv = IV.fromLength(16); // static IV for simplicity, see note below
  }

  String encrypt(String plainText) {
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    // Use a random IV per message for better security
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    // Prepend IV to the ciphertext so receiver can decrypt
    return base64.encode(iv.bytes + encrypted.bytes);
  }

  String decrypt(String cipherText) {
    final bytes = base64.decode(cipherText);
    // Extract IV from first 16 bytes
    final iv = IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final cipherBytes = Encrypted(Uint8List.fromList(bytes.sublist(16)));
    final encrypter = Encrypter(AES(_key, mode: AESMode.cbc));
    return encrypter.decrypt(cipherBytes, iv: iv);
  }
}