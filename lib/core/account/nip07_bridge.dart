// Web-only NIP-07 bridge. Uses dart:js_util to call window.nostr (browser extension API).

import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart' show kIsWeb;

class Nip07Bridge {
  Nip07Bridge._();

  static dynamic get _nostr {
    if (!kIsWeb) return null;
    try {
      final g = js_util.globalThis;
      if (js_util.hasProperty(g, 'nostr')) {
        return js_util.getProperty(g, 'nostr');
      }
    } catch (_) {}
    return null;
  }

  static bool get isAvailable => _nostr != null;

  static Future<String> getPublicKey() async {
    final n = _nostr;
    if (n == null) {
      throw UnsupportedError('NIP-07 extension not available');
    }
    try {
      final p = js_util.callMethod(n, 'getPublicKey', []);
      final r = await js_util.promiseToFuture<Object>(p);
      // Extension may resolve with { error: { message: "..." } } instead of rejecting
      final m = js_util.dartify(r);
      if (m is Map && m['error'] != null) {
        final err = m['error'];
        final msg = err is Map ? (err['message'] ?? err.toString()) : err.toString();
        throw Exception(msg.toString());
      }
      return r.toString();
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('NIP-07 getPublicKey failed: $e');
    }
  }

  static Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    final n = _nostr;
    if (n == null) {
      throw UnsupportedError('NIP-07 extension not available');
    }
    try {
      final jsEvent = js_util.jsify(event);
      final p = js_util.callMethod(n, 'signEvent', [jsEvent]);
      final r = await js_util.promiseToFuture<Object>(p);
      final dartMap = js_util.dartify(r) as Map<dynamic, dynamic>;
      return dartMap.map((k, v) => MapEntry(k.toString(), v));
    } catch (e) {
      throw Exception('NIP-07 signEvent failed: $e');
    }
  }

  static bool hasNip04Support() {
    final n = _nostr;
    if (n == null) return false;
    try {
      if (!js_util.hasProperty(n, 'nip04')) return false;
      final nip04 = js_util.getProperty(n, 'nip04');
      return nip04 != null &&
          js_util.hasProperty(nip04, 'encrypt') &&
          js_util.hasProperty(nip04, 'decrypt');
    } catch (_) {
      return false;
    }
  }

  static bool hasNip44Support() {
    final n = _nostr;
    if (n == null) return false;
    try {
      if (!js_util.hasProperty(n, 'nip44')) return false;
      final nip44 = js_util.getProperty(n, 'nip44');
      return nip44 != null &&
          js_util.hasProperty(nip44, 'encrypt') &&
          js_util.hasProperty(nip44, 'decrypt');
    } catch (_) {
      return false;
    }
  }

  static bool hasGetRelaysSupport() {
    final n = _nostr;
    if (n == null) return false;
    try {
      return js_util.hasProperty(n, 'getRelays');
    } catch (_) {
      return false;
    }
  }

  static Future<String?> nip04Encrypt(String pubkey, String plaintext) async {
    if (!hasNip04Support()) return null;
    try {
      final n = _nostr;
      final nip04 = js_util.getProperty(n, 'nip04');
      final p = js_util.callMethod(nip04, 'encrypt', [pubkey, plaintext]);
      return await js_util.promiseToFuture<String>(p);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> nip04Decrypt(String pubkey, String ciphertext) async {
    if (!hasNip04Support()) return null;
    try {
      final n = _nostr;
      final nip04 = js_util.getProperty(n, 'nip04');
      final p = js_util.callMethod(nip04, 'decrypt', [pubkey, ciphertext]);
      return await js_util.promiseToFuture<String>(p);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> nip44Encrypt(String pubkey, String plaintext) async {
    if (!hasNip44Support()) return null;
    try {
      final n = _nostr;
      final nip44 = js_util.getProperty(n, 'nip44');
      final p = js_util.callMethod(nip44, 'encrypt', [pubkey, plaintext]);
      return await js_util.promiseToFuture<String>(p);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> nip44Decrypt(String pubkey, String ciphertext) async {
    if (!hasNip44Support()) return null;
    try {
      final n = _nostr;
      final nip44 = js_util.getProperty(n, 'nip44');
      final p = js_util.callMethod(nip44, 'decrypt', [pubkey, ciphertext]);
      return await js_util.promiseToFuture<String>(p);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getRelays() async {
    if (!hasGetRelaysSupport()) return null;
    try {
      final n = _nostr;
      final p = js_util.callMethod(n, 'getRelays', []);
      final r = await js_util.promiseToFuture<Object>(p);
      final dartMap = js_util.dartify(r) as Map<dynamic, dynamic>?;
      if (dartMap == null) return null;
      return dartMap.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }
}
