// Stub for non-web platforms. NIP-07 is only available in browser extensions.

class Nip07Bridge {
  Nip07Bridge._();

  static bool get isAvailable => false;

  static Future<String> getPublicKey() async {
    throw UnsupportedError('NIP-07 is not available on this platform');
  }

  static Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    throw UnsupportedError('NIP-07 is not available on this platform');
  }

  static bool hasNip04Support() => false;
  static bool hasNip44Support() => false;
  static bool hasGetRelaysSupport() => false;

  static Future<String?> nip04Encrypt(String pubkey, String plaintext) async =>
      null;
  static Future<String?> nip04Decrypt(String pubkey, String ciphertext) async =>
      null;
  static Future<String?> nip44Encrypt(String pubkey, String plaintext) async =>
      null;
  static Future<String?> nip44Decrypt(String pubkey, String ciphertext) async =>
      null;
  static Future<Map<String, dynamic>?> getRelays() async => null;
}
