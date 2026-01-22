import 'package:chuchu/core/account/account+relay.dart';
import 'package:chuchu/core/manager/thread_pool_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../config/storage_key_tool.dart';
import '../feed/model/noteDB_isar.dart';
import '../feed/model/notificationDB_isar.dart';
import 'package:nostr_core_dart/src/nips/nip_005.dart';
import '../account/account.dart';
import '../account/secure_account_storage.dart';
import '../account/model/userDB_isar.dart';
import '../account/relays.dart';
import '../account/zaps.dart';
import '../contacts/contacts.dart';
import '../database/db_isar.dart';
import '../feed/feed.dart';
import '../messages/messages.dart';
import '../network/connect.dart';
import '../network/eventCache.dart';
import '../relayGroups/relayGroup.dart';
import '../wallet/wallet.dart';
import 'cache/chuchu_cache_manager.dart';
import 'chuchu_feed_manager.dart';

abstract mixin class ChuChuUserInfoObserver {
  void didLoginSuccess(UserDBISAR? userInfo);

  void didSwitchUser(UserDBISAR? userInfo);

  void didLogout();

  void didUpdateUserInfo() {}
}

enum _ContactType {
  contacts,
  channels,
  // groups
  relayGroups,
}

class ChuChuUserInfoManager {
  static final ChuChuUserInfoManager sharedInstance =
      ChuChuUserInfoManager._internal();

  ChuChuUserInfoManager._internal();

  factory ChuChuUserInfoManager() {
    return sharedInstance;
  }

  final List<ChuChuUserInfoObserver> _observers = <ChuChuUserInfoObserver>[];

  final List<VoidCallback> initDataActions = [];

  bool get isLogin => (currentUserInfo != null);

  UserDBISAR? currentUserInfo;

  Map<String, dynamic> settingsMap = {};

  var _contactFinishFlags = {
    _ContactType.contacts: false,
    _ContactType.channels: false,
    _ContactType.relayGroups: false,
  };

  bool get isFetchContactFinish => _contactFinishFlags.values.every((v) => v);

  bool canVibrate = true;
  bool canSound = true;
  bool signatureVerifyFailed = false;
  //0: top; 1: tabbar; 2: delete.
  int momentPosition = 0;

  Future initDB(String pubkey) async {
    if (pubkey.isEmpty) return;
    await logout(needObserver: false);

    await DBISAR.sharedInstance.open(pubkey);
    Account.sharedInstance.init();
  }

  void addObserver(ChuChuUserInfoObserver observer) => _observers.add(observer);

  bool removeObserver(ChuChuUserInfoObserver observer) =>
      _observers.remove(observer);

  Future initLocalData() async {
    /// Try secure storage (supports web refresh)
    final storedPrivkey = await SecureAccountStorage.readPrivateKey();
    if (storedPrivkey != null && storedPrivkey.isNotEmpty) {
      try {
        final storedPubkey = Account.getPublicKey(storedPrivkey);
        await initDB(storedPubkey);
        final UserDBISAR? tempUserDB =
            await Account.sharedInstance.loginWithPriKey(storedPrivkey);
        if (tempUserDB != null) {
          currentUserInfo = tempUserDB;
          await SecureAccountStorage.savePrivateKey(
            storedPrivkey,
            pubkey: storedPubkey,
          );
          _initDatas();
          return;
        }
      } catch (_) {
        // Fall back to legacy path
      }
    }

    /// Legacy auto-login based on cached pubkey
    final String? localPubKey = await ChuChuCacheManager
        .defaultOXCacheManager
        .getForeverData(StorageKeyTool.CHUCHU_USER_PUBKEY);
    if (localPubKey != null && localPubKey.isNotEmpty) {
        await initDB(localPubKey);
        final UserDBISAR? tempUserDB = await Account.sharedInstance.loginWithPubKeyAndPassword(localPubKey);
        if (tempUserDB != null) {
          currentUserInfo = tempUserDB;
          _initDatas();
          return;
        }
    }
  }

  Future<void> loginSuccess(UserDBISAR userDB, {bool isAmber = false}) async {
    currentUserInfo = Account.sharedInstance.me;
    ChuChuCacheManager.defaultOXCacheManager.saveForeverData(
      StorageKeyTool.CHUCHU_USER_PUBKEY,
      userDB.pubKey,
    );

    await _initDatas();
    for (ChuChuUserInfoObserver observer in _observers) {
      observer.didLoginSuccess(currentUserInfo);
    }
  }

  void addChatCallBack() {
    Feed.sharedInstance.newNotesCallBack = (List<NoteDBISAR> notes) {
      ChuChuFeedManager.sharedInstance.newNotesCallBackCallBack(notes);
    };

    Feed.sharedInstance.newNotificationCallBack = (
      List<NotificationDBISAR> notifications,
    ) {
      ChuChuFeedManager.sharedInstance.newNotificationCallBack(notifications);
    };

    Feed.sharedInstance.myZapNotificationCallBack = (
      List<NotificationDBISAR> notifications,
    ) {
      ChuChuFeedManager.sharedInstance.myZapNotificationCallBack(notifications);
    };
  }

  void updateUserInfo(UserDBISAR userDB) {}

  void updateSuccess() {
    for (ChuChuUserInfoObserver observer in _observers) {
      observer.didUpdateUserInfo();
    }
  }

  Future<UserDBISAR?> handleSwitchFailures(
    UserDBISAR? userDB,
    String currentUserPubKey,
  ) async {
    if (userDB == null && currentUserPubKey.isNotEmpty) {
      //In the case of failing to add a new account while already logged in, implement the logic to re-login to the current account.
      await ChuChuUserInfoManager.sharedInstance.initDB(currentUserPubKey);
      userDB = await Account.sharedInstance.loginWithPubKeyAndPassword(
        currentUserPubKey,
      );
    }
    return userDB;
  }

  Future logout({bool needObserver = true}) async {
    if (ChuChuUserInfoManager.sharedInstance.currentUserInfo == null) {
      return;
    }
    await Account.sharedInstance.logout();
    await SecureAccountStorage.clearPrivateKey();
    await SecureAccountStorage.clearPrivateKeyForPubkey(
      currentUserInfo?.pubKey ?? '',
    );
    // Clear Feed cache before closing database
    Feed.sharedInstance.clearCache();
    // Close database when logging out to ensure clean state
    await DBISAR.sharedInstance.closeDatabase();
    resetData(needObserver: needObserver);
  }

  void resetData({bool needObserver = true}) {
    signatureVerifyFailed = false;
    currentUserInfo = null;
    _contactFinishFlags = {
      _ContactType.contacts: false,
      _ContactType.channels: false,
      // _ContactType.groups: false,
      _ContactType.relayGroups: false,
    };
    if (needObserver) {
      for (ChuChuUserInfoObserver observer in _observers) {
        observer.didLogout();
      }
    }
  }

  bool isCurrentUser(String userID) {
    return userID == currentUserInfo?.pubKey;
  }

  Future<bool> checkDNS({required UserDBISAR userDB}) async {
    String pubKey = userDB.pubKey;
    String dnsStr = userDB.dns ?? '';
    if (dnsStr.isEmpty || dnsStr == 'null') {
      return false;
    }
    List<String> relayAddressList = await Account.sharedInstance
        .getUserGeneralRelayList(pubKey);
    List<String> temp = dnsStr.split('@');
    String name = temp[0];
    String domain = temp[1];
    DNS dns = DNS(name, domain, pubKey, relayAddressList);
    try {
      return await Account.checkDNS(dns);
    } catch (error, stack) {
      return false;
    }
  }

  Future<void> _initDatas() async {
    addChatCallBack();
    initDataActions.forEach((fn) {
      fn();
    });
    await EventCache.sharedInstance.loadAllEventsFromDB();
    
    _initWallet();
    
    Relays.sharedInstance.init().then((value) {
      Contacts.sharedInstance.initContacts(
        Contacts.sharedInstance.contactUpdatedCallBack,
      );
      // Groups.sharedInstance.init(
      //   callBack: Groups.sharedInstance.myGroupsUpdatedCallBack,
      // );
      Feed.sharedInstance.init();
      Zaps.sharedInstance.init();
      RelayGroup.sharedInstance.init(callBack: RelayGroup.sharedInstance.myGroupsUpdatedCallBack);

      _initMessage();
    });
  }

  Future<void> _initWallet() async {
    try {
      await Wallet.sharedInstance.init();
    } catch (e) {
      print('Failed to initialize wallet after login: $e');
    }
  }

  void _initMessage() {
    Messages.sharedInstance.init();
  }

  Future<void> resetHeartBeat() async {
    //eg: backForeground
    if (isLogin) {
      await ThreadPoolManager.sharedInstance.initialize();
      Connect.sharedInstance.startHeartBeat();
      Account.sharedInstance.startHeartBeat();
    }
  }
}
