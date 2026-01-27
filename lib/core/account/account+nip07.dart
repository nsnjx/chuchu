import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:nostr_core_dart/nostr.dart';

import 'account.dart';
import 'model/userDB_isar.dart';
import 'nip07.dart';

extension AccountNIP07 on Account {
  /// Registers SignerHelper callbacks to delegate signing/encrypt/decrypt to NIP-07 extension.
  void initNIP07Callback() {
    SignerHelper.sharedInstance.signEventHandle = (String eventString) async {
      final eventMap = jsonDecode(eventString) as Map<String, dynamic>;
      final signed = await Nip07Bridge.signEvent(eventMap);
      return Event.fromJson(Map<String, dynamic>.from(signed), verify: false);
    };
    SignerHelper.sharedInstance.nip04encryptEventHandle =
        (String plainText, String peerPubkey) async {
      return Nip07Bridge.nip04Encrypt(peerPubkey, plainText);
    };
    SignerHelper.sharedInstance.nip04decryptEventHandle =
        (String encryptedText, String peerPubkey) async {
      return Nip07Bridge.nip04Decrypt(peerPubkey, encryptedText);
    };
    SignerHelper.sharedInstance.nip44encryptEventHandle =
        (String plainText, String peerPubkey) async {
      return Nip07Bridge.nip44Encrypt(peerPubkey, plainText);
    };
    SignerHelper.sharedInstance.nip44decryptEventHandle =
        (String encryptedText, String peerPubkey) async {
      return Nip07Bridge.nip44Decrypt(peerPubkey, encryptedText);
    };
  }

  /// Logs in using the NIP-07 browser extension (web only).
  /// Returns the user when successful; null or throws on failure.
  Future<UserDBISAR?> loginWithNip07() async {
    if (!kIsWeb) {
      throw UnsupportedError('NIP-07 is only available on web');
    }
    if (!Nip07Bridge.isAvailable) {
      throw UnsupportedError('NIP-07 extension not available');
    }
    try {
      final pubkey = await Nip07Bridge.getPublicKey();
      if (pubkey.isEmpty) return null;
      initNIP07Callback();
      return await loginWithPubKey(pubkey, SignerApplication.nip07Signer);
    } catch (e) {
      rethrow;
    }
  }

  /// Logs in with an already-fetched NIP-07 pubkey (avoids calling getPublicKey again).
  /// Use when the caller has already called Nip07Bridge.getPublicKey().
  Future<UserDBISAR?> loginWithNip07Pubkey(String pubkey) async {
    if (!kIsWeb || !Nip07Bridge.isAvailable) {
      throw UnsupportedError('NIP-07 extension not available');
    }
    if (pubkey.isEmpty) return null;
    initNIP07Callback();
    return await loginWithPubKey(pubkey, SignerApplication.nip07Signer);
  }

  /// Restores an existing NIP-07 session (web only). Call when privkey == 'nip07Signer'.
  Future<UserDBISAR?> restoreNip07Session(String pubkey) async {
    if (!kIsWeb || !Nip07Bridge.isAvailable) return null;
    initNIP07Callback();
    return await loginWithPubKey(pubkey, SignerApplication.nip07Signer);
  }
}
