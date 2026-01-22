
import 'package:chuchu/core/contacts/contacts+blocklist.dart';
import 'package:chuchu/core/feed/feed+load.dart';
import 'package:flutter/foundation.dart';

import '../account/account.dart';
import '../account/model/relayDB_isar.dart';
import '../account/relays.dart';
import '../contacts/contacts.dart';
import '../manager/chuchu_user_info_manager.dart';
import '../network/connect.dart';
import 'package:nostr_core_dart/src/filter.dart';
import 'package:nostr_core_dart/src/utils.dart';
import '../utils/log_utils.dart';
import 'model/noteDB_isar.dart';
import 'model/notificationDB_isar.dart';

typedef NewNotesCallBack = void Function(List<NoteDBISAR>);
typedef NewNotificationCallBack = void Function(List<NotificationDBISAR>);
typedef OfflineMomentFinishCallBack = void Function();

class Feed {
  /// singleton
  Feed._internal();
  factory Feed() => sharedInstance;
  static final Feed sharedInstance = Feed._internal();

  /// memory storage
  String pubkey = '';
  String privkey = '';
  Map<String, NoteDBISAR> notesCache = {};
  List<NoteDBISAR> newNotes = [];
  List<NotificationDBISAR> newNotifications = [];
  NewNotesCallBack? newNotesCallBack;
  NewNotificationCallBack? newNotificationCallBack;
  NewNotificationCallBack? myZapNotificationCallBack;
  OfflineMomentFinishCallBack? offlineMomentFinishCallBack;

  String notesSubscription = '';
  Map<String, bool> offlineMomentFinish = {};

  int latestNoteTime = 0;
  int latestNotificationTime = 0;
  int limit = 50;

  Future<void> init() async {
    privkey = Account.sharedInstance.currentPrivkey;
    pubkey = Account.sharedInstance.currentPubkey;
    
    Connect.sharedInstance.addConnectStatusListener((relay, status, relayKinds) async {
      if (status == 1 && 
          Account.sharedInstance.me != null && 
          relayKinds.contains(RelayKind.general) &&
          ChuChuUserInfoManager.sharedInstance.isLogin) {
        updateSubscriptions(relay: relay);
      }
    });
    
    if (ChuChuUserInfoManager.sharedInstance.isLogin) {
      updateSubscriptions();
    } else {
      debugPrint('If the user is not logged in, skip the Moments and subscribe to the updates');
    }
  }

  void closeSubscriptions({String? relay}) {
    if (notesSubscription.isNotEmpty) {
      Connect.sharedInstance.closeRequests(notesSubscription, relay: relay);
    }
  }

  Future<void> updateSubscriptions({String? relay}) async {
    closeSubscriptions(relay: relay);

    List<String> authors = Contacts.sharedInstance.allContacts.keys.toList();
    authors.add(pubkey); // add self
    if (authors.isNotEmpty) {
      Map<String, List<Filter>> subscriptions = {};
      if (relay == null) {
        for (String relayURL in Connect.sharedInstance.relays()) {
          int momentUntil = Relays.sharedInstance.getMomentUntil(relayURL);
          Filter f1 = Filter(
              authors: authors,
              kinds: [1, 6],
              since: momentUntil,
              limit: limit);
          // Subscribe to reactions where p tags contain our pubkey (reactions to our notes)
          Filter f2 = Filter(
              p: [pubkey], kinds: [7], since: momentUntil, limit: limit);
          // Also subscribe to reactions we sent (for local updates)
          Filter f3 = Filter(
              authors: [pubkey], kinds: [7], since: momentUntil, limit: limit);
          subscriptions[relayURL] = [f1, f2, f3];
        }
      } else {
        int momentUntil = Relays.sharedInstance.getMomentUntil(relay);
        Filter f1 = Filter(
            authors: authors, kinds: [1, 6], since: momentUntil, limit: limit);
        // Subscribe to reactions where p tags contain our pubkey (reactions to our notes)
        Filter f2 = Filter(
            p: [pubkey], kinds: [7], since: momentUntil, limit: limit);
        // Also subscribe to reactions we sent (for local updates)
        Filter f3 = Filter(
            authors: [pubkey], kinds: [7], since: momentUntil, limit: limit);
        subscriptions[relay] = [f1, f2, f3];
      }

      notesSubscription = Connect.sharedInstance.addSubscriptions(subscriptions,
          eventCallBack: (event, relay) async {
            updateMomentTime(event.createdAt, relay);
            if (Contacts.sharedInstance.inBlockList(event.pubkey)) return;
            switch (event.kind) {
              case 1:
                handleNoteEvent(event, relay, false);
                break;
              case 6:
                handleRepostsEvent(event, relay, false);
                break;
              case 7:
                handleReactionEvent(event, relay, false);
                break;
              default:
                LogUtils.v(() => 'moment unhandled message ${event.toJson()}');
                break;
            }
          }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) {
            offlineMomentFinish[relay] = true;
            if (ok.status) {
              updateMomentTime(currentUnixTimestampSeconds() - 1, relay);
            }
            if (unCompletedRelays.isEmpty) {
              offlineMomentFinishCallBack?.call();
            }
          });
    }
  }

  void updateMomentTime(int eventTime, String relay) {
    /// set setMomentSince setMomentUntil
    if (Relays.sharedInstance.relays.containsKey(relay)) {
      Relays.sharedInstance.setMomentSince(eventTime, relay);
      Relays.sharedInstance.setMomentUntil(eventTime, relay);
    } else {
      Relays.sharedInstance.relays[relay] = RelayDBISAR(
          url: relay, momentSince: eventTime, momentUntil: eventTime);
    }
    if (offlineMomentFinish[relay] == true) {
      Relays.sharedInstance.syncRelaysToDB(r: relay);
    }
  }

  void clearNewNotes() {
    newNotes.clear();
  }

  void clearNewNotifications() {
    newNotifications.clear();
  }

  /// Clear all caches when user logs out or switches account
  void clearCache() {
    notesCache.clear();
    newNotes.clear();
    newNotifications.clear();
    latestNoteTime = 0;
    latestNotificationTime = 0;
  }
}
