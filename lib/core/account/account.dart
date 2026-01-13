import 'dart:async';
import 'dart:convert';
import 'package:chuchu/core/account/account+nip46.dart';
import 'package:chuchu/core/account/account+profile.dart';
import 'package:chuchu/core/account/relays.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart' hide Filter;
import 'package:pointycastle/export.dart';
import 'package:convert/convert.dart';
import '../contacts/contacts.dart';
import '../database/db_isar.dart';
import '../network/connect.dart';
import '../network/eventCache.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:nostr_core_dart/src/signer/external_signer_tool.dart';
import '../utils/log_utils.dart';
import '../wallet/wallet.dart';
import '../relayGroups/model/relayGroupDB_isar.dart';
import '../bookmark/bookmark_manager.dart';
import 'model/userDB_isar.dart';
import 'secure_account_storage.dart';


enum NIP46ConnectionStatus {
  connected,
  disconnected,
  connecting,
  waitingForSigning,
  approvedSigning
}

typedef AccountUpdateCallback = void Function();
typedef NIP46CommandResultCallback = void Function(NIP46CommandResult result);
typedef NIP46ConnectionStatusCallback = void Function(NIP46ConnectionStatus status);

class Account {
  /// singleton
  Account._internal();
  factory Account() => sharedInstance;
  static final Account sharedInstance = Account._internal();

  UserDBISAR? me;
  String currentPubkey = '';
  String currentPrivkey = '';
  Timer? timer;

  String NIP46Subscription = '';
  RemoteSignerConnection? currentRemoteConnection;
  RemoteSignerConnection? tempRemoteConnection;

  Map<String, Completer<NIP46CommandResult>> resultCompleters = {};
  NIP46CommandResultCallback? nip46commandResultCallback;
  NIP46ConnectionStatusCallback? nip46connectionStatusCallback;

  // Map<String, UserDB> userCache = {};
  Map<String, ValueNotifier<UserDBISAR>> userCache = {};

  List<String> pQueue = [];
  List<Event> unsentNIP46EventQueue = [];

  AccountUpdateCallback? relayListUpdateCallback;
  AccountUpdateCallback? dmRelayListUpdateCallback;
  AccountUpdateCallback? contactListUpdateCallback;
  AccountUpdateCallback? channelListUpdateCallback;
  AccountUpdateCallback? groupListUpdateCallback;
  AccountUpdateCallback? relayGroupListUpdateCallback;

  void init(){
    startHeartBeat();
    _loadAllUsers();
    initNIP46Callback();
    BookmarkManager.sharedInstance.loadFromStorage();
  }

  void startHeartBeat() {
    if (timer == null || timer!.isActive == false) {
      timer = Timer.periodic(Duration(seconds: 15), (Timer t) async {
        await syncProfilesFromRelay();
      });
    }
  }

  Future<void> _loadAllUsers() async {
    List<UserDBISAR?> maps;
    if (kIsWeb) {
      // Web platform uses dedicated methods
      maps = await DBISAR.sharedInstance.findAllUsers();
    } else {
      // Mobile platform uses Isar
      var queryBuilder = DBISAR.sharedInstance.isar.userDBISARs.where();
      maps = await queryBuilder.findAll();
    }
    for (UserDBISAR? user in maps) {
      if (user != null) {
        user = user.withGrowableLevels();
        userCache[user.pubKey] = ValueNotifier<UserDBISAR>(user);
      }
    }
  }

  Future<void> syncMe() async {
    await saveUserToDB(me!);
  }

  static Future<void> saveUserToDB(UserDBISAR user) async {
    await DBISAR.sharedInstance.saveToDB(user);
  }

  bool isValidPubKey(String pubKey) {
    final pattern = RegExp(r'^[a-fA-F0-9]{64}$');
    return pattern.hasMatch(pubKey);
  }

  FutureOr<UserDBISAR?> getUserInfo(String pubkey) {
    if (pubkey.length == 66 && pubkey.startsWith('02')) {
      pubkey = pubkey.replaceFirst('02', '');
    }
    if (!isValidPubKey(pubkey)) return null;

    UserDBISAR? user = userCache[pubkey]?.value;
    if (user != null) {
      _addToPQueue(user);
      return user;
    }

    Completer<UserDBISAR?> completer = Completer();
    getUserFromDB(pubkey: pubkey).then((user) {
      if (user != null) {
        userCache[pubkey] = ValueNotifier<UserDBISAR>(user);
        _addToPQueue(user);
      }
      completer.complete(user);
    });
    return completer.future;
  }

  Future<Map<String, UserDBISAR>> getUserInfos(List<String> pubkeys) async {
    Map<String, UserDBISAR> result = {};
    for (var p in pubkeys) {
      UserDBISAR? user = await getUserInfo(p);
      if (user != null) result[p] = user;
    }
    return result;
  }

  ValueNotifier<UserDBISAR> getUserNotifier(String pubkey) {
    if (userCache.containsKey(pubkey)) return userCache[pubkey]!;
    userCache[pubkey] = ValueNotifier(UserDBISAR(pubKey: pubkey));
    return userCache[pubkey]!;
  }

  void syncUserFromGroupMetadata(RelayGroupDBISAR group) {
    final pubkey = group.groupId;
    if (pubkey.isEmpty || !isValidPubKey(pubkey)) return;

    final notifier = getUserNotifier(pubkey);
    final user = notifier.value;
    bool changed = false;

    if (user.pubKey.isEmpty) {
      user.pubKey = pubkey;
      changed = true;
    }

    if (group.name.isNotEmpty && user.name != group.name) {
      user.name = group.name;
      changed = true;
    }

    if (group.about.isNotEmpty && user.about != group.about) {
      user.about = group.about;
      changed = true;
    }

    // Note: Do not sync group.picture to user.picture
    // group.picture is for cover photo, user.picture is for avatar
    // They should remain separate

    if (group.relay.isNotEmpty && user.mainRelay != group.relay) {
      user.mainRelay = group.relay;
      changed = true;
    }

    if (!changed) return;

    user.lastUpdatedTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    notifier.value = user;
    unawaited(saveUserToDB(user));
  }

  void _addToPQueue(UserDBISAR user) {
    if (user.lastUpdatedTime != 0) return;
    final pubkey = user.pubKey;
    if (pubkey.isNotEmpty && !pQueue.contains(pubkey)) {
      pQueue.add(pubkey);
    }
  }

  Future<UserDBISAR?> _searchUserFromDB(String pubkey) async {
    UserDBISAR? user;
    if (kIsWeb) {
      // Web platform uses dedicated methods
      user = await DBISAR.sharedInstance.findUserByPubKey(pubkey);
    } else {
      // Mobile platform uses Isar
      user = await DBISAR.sharedInstance.isar.userDBISARs.where().pubKeyEqualTo(pubkey).findFirst();
    }
    if (user != null) {
      user = user.withGrowableLevels();
      userCache[user.pubKey] = ValueNotifier<UserDBISAR>(user);
    }
    return user;
  }

  Future<UserDBISAR?> getUserFromDB({String pubkey = '', String privkey = ''}) async {
    if (privkey.isNotEmpty) {
      pubkey = Keychain.getPublicKey(privkey);
    }
    if (pubkey.isNotEmpty) {
      UserDBISAR? db = await _searchUserFromDB(pubkey);
      if (db != null) {
        return db;
      } else {
        db = UserDBISAR(pubKey: pubkey);
        db.name = db.shortEncodedPubkey;
        await saveUserToDB(db);
        return db;
      }
    }
    return null;
  }

  Future<UserDBISAR?> loginWithPubKey(String pubkey, SignerApplication signerApplication, {String? androidSignerKey}) async {
    UserDBISAR? userDB = await getUserFromDB(pubkey: pubkey);
    if (userDB != null) {
      me = userDB;
      currentPubkey = userDB.pubKey;
      currentPrivkey = SignerHelper.getSignerApplicationKey(signerApplication, '');
      userDB.privkey = currentPrivkey;
      // Save android signer key if provided
      if (signerApplication == SignerApplication.androidSigner && androidSignerKey != null) {
        userDB.androidSignerKey = androidSignerKey;
      }
      userCache[currentPubkey] = ValueNotifier<UserDBISAR>(userDB);
      await saveUserToDB(userDB);
      loginSuccess();
    }
    return userDB;
  }

  Future<UserDBISAR?> loginWithPubKeyAndPassword(String pubkey) async {
    UserDBISAR? db = await _searchUserFromDB(pubkey);
    if (db == null) return null;
    
    // Check login type: bunker/remoteSigner
    if (db.remoteSignerURI != null) {
      return await loginWithNip46Pubkey(pubkey);
    }
    
    // Check login type: androidSigner
    if (db.privkey == 'androidSigner') {
      // Restore the saved signer if available
      if (db.androidSignerKey != null && db.androidSignerKey!.isNotEmpty) {
        await ExternalSignerTool.initialize();
        await ExternalSignerTool.setSigner(db.androidSignerKey!);
      }
      return await loginWithPubKey(pubkey, SignerApplication.androidSigner, androidSignerKey: db.androidSignerKey);
    }
    
    final storedPrivkey = await SecureAccountStorage.readPrivateKeyForPubkey(pubkey);
    if (storedPrivkey != null && storedPrivkey.isNotEmpty) {
      await SecureAccountStorage.savePrivateKey(
        storedPrivkey,
        pubkey: pubkey,
      );
      return await loginWithPriKey(storedPrivkey);
    }
    return null;
  }

  Future<UserDBISAR?> loginWithPriKey(String privkey) async {
    String pubkey = Keychain.getPublicKey(privkey);
    UserDBISAR? db = await getUserFromDB(pubkey: pubkey);
    if (db == null) return null;

    me = db;
    currentPrivkey = privkey;
    currentPubkey = db.pubKey;
    userCache[currentPubkey] = ValueNotifier<UserDBISAR>(db);
    loginSuccess();
    return db;
  }

  static Future<bool> checkDNS(DNS dns) async {
    String? pubkey = await getDNSPubkey(dns.name, dns.domain);
    return (pubkey != null && pubkey == dns.pubkey);
  }

  static Future<String?> getDNSPubkey(String name, String domain) async {
    try {
      final response =
          await http.get(Uri.parse('https://$domain/.well-known/nostr.json?name=$name'));

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse["names"][name];
      } else {
        return null;
      }
    } catch (e) {
      LogUtils.v(() => e.toString());
      return null;
    }
  }

  // static String signData(List data, String privateKey) {
  //   return Nip101.getSig(data, privateKey);
  // }

  static Keychain generateNewKeychain() {
    return Keychain.generate();
  }

  static String getPublicKey(String privkey) {
    return Keychain.getPublicKey(privkey);
  }

  static Future<String> getPublicKeyWithNIP46URI(String uri) async {
    if (uri.startsWith('bunker://')) {
      RemoteSignerConnection remoteSignerConnection = Nip46.parseBunkerUri(uri);
      return remoteSignerConnection.remotePubkey;
    } else if (uri.startsWith('nostrconnect://')) {
      return await Account.sharedInstance.getPublicKeyWithNostrConnectURI(uri);
    }
    return '';
  }

  static Future<UserDBISAR> newAccount({Keychain? user}) async {
    user ??= Keychain.generate();
    UserDBISAR db = UserDBISAR();
    db.pubKey = user.public;
    await Account.saveUserToDB(db);
    return db;
  }

  List<Profile> toProfiles(List<String> pubkeys) {
    List<Profile> result = [];
    for (var p in pubkeys) {
      result.add(Profile(p, '', ''));
    }
    return result;
  }

  Future<void> logout() async {
    await Connect.sharedInstance.closeAllConnects();
    Contacts.sharedInstance.allContacts.clear();
    Relays.sharedInstance.relays.clear();
    EventCache.sharedInstance.cacheIds.clear();
    Wallet.sharedInstance.logout();
    me = null;
    currentPubkey = '';
    currentPrivkey = '';
    userCache.remove(currentPubkey);
  }

  static Future<Event?> loadAddress(String d, String pubkey) async {
    Completer<Event?> completer = Completer<Event?>();
    Filter f = Filter(d: [d], authors: [pubkey]);
    Connect.sharedInstance.addSubscription([f], eventCallBack: (event, relay) async {
      if (!completer.isCompleted) completer.complete(event);

    }, eoseCallBack: (requestId, status, relay, unRelays) {
      if (unRelays.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    return completer.future;
  }

  static Future<Event?> loadEvent(String eventId, {List<String>? relays}) async {
    EventCache.sharedInstance.cacheIds.remove(eventId);
    Completer<Event?> completer = Completer<Event?>();
    Timer(Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    if (relays == null && Connect.sharedInstance.relays().isEmpty) return null;
    if (relays != null && relays.isNotEmpty) {
      await Connect.sharedInstance.connectRelays(relays, relayKind: RelayKind.temp);
    }
    Filter f = Filter(ids: [eventId]);
    Connect.sharedInstance.addSubscription([f], relays: relays,
        eventCallBack: (event, relay) async {
      if (!completer.isCompleted) completer.complete(event);
    }, eoseCallBack: (requestId, status, relay, unRelays) {
      if (unRelays.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    return completer.future;
  }

  static String encodeProfile(String pubkey, List<String> relays) {
    String profile = Nip19.encodeShareableEntity('nprofile', pubkey, relays, null, null);
    return Nip21.encode(profile);
  }

  static Map<String, dynamic>? decodeProfile(String profile) {
    if (profile.startsWith('nostr:')) {
      profile = Nip21.decode(profile)!;
    }
    if (profile.startsWith('npub')) {
      return {'pubkey': Nip19.decodePubkey(profile), 'relays': []};
    } else if (profile.startsWith('nprofile')) {
      Map result = Nip19.decodeShareableEntity(profile);
      if (result['prefix'] == 'nprofile') {
        return {'pubkey': result['special'], 'relays': result['relays']};
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> json) async {
    if (json['pubkey'] == null) json['pubkey'] = currentPubkey;
    if (json['id'] == null) {
      var tags = (json['tags'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((e) => e.toString()).toList())
          .toList();
      json['id'] = Event.processEventId(
          json['pubkey'], json['created_at'], json['kind'], tags, json['content']);
    }
    Event event = await Event.fromJson(json, verify: false);
    if (SignerHelper.needSigner(currentPrivkey)) {
      final pubkey = Account.sharedInstance.currentPubkey;
      final privkey = Account.sharedInstance.currentPrivkey;
      event.sig = await SignerHelper.signMessage(event.id, pubkey, privkey) ?? '';
    } else {
      event.sig = event.getSignature(currentPrivkey);
    }
    assert(await event.isValid() == true);
    return event.toJson();
  }

  Future<String> encryptNip04(String content, String peer) async {
    return await Nip4.encryptContent(content, peer, currentPubkey, currentPrivkey);
  }

  Future<String> decryptNip04(String content, String peer) async {
    return await Nip4.decryptContent(content, peer, currentPubkey, currentPrivkey);
  }

  static Future<String> getSignatureWithSecret(String secret, [String? privkey]) async {
    privkey ??= Account.sharedInstance.currentPrivkey;
    if (SignerHelper.needSigner(privkey)) {
      final pubkey = Account.sharedInstance.currentPubkey;
      final privkey = Account.sharedInstance.currentPrivkey;
      return await SignerHelper.signMessage(secret, pubkey, privkey) ?? '';
    }
    final hexMessage = hex.encode(SHA256Digest().process(Uint8List.fromList(utf8.encode(secret))));
    return Keychain(privkey).sign(hexMessage);
  }
}

