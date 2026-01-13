import 'dart:async';

import 'package:chuchu/core/relayGroups/relayGroup.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart' hide Filter;

import '../account/account.dart';
import '../account/model/userDB_isar.dart';
import '../config/config.dart';
import '../database/db_isar.dart';
import '../network/connect.dart';
import 'package:nostr_core_dart/src/event.dart';
import 'package:nostr_core_dart/src/filter.dart';
import 'package:nostr_core_dart/src/nips/nip_029.dart';
import 'package:nostr_core_dart/src/nips/nip_051.dart';
import 'model/relayGroupDB_isar.dart';

extension EInfo on RelayGroup {
  Future<RelayGroupDBISAR?> getGroupMetadataFromRelay(String groupId,
      {String? relay, String? author}) async {
    if (groupId.isEmpty) return null;
    SimpleGroups simpleGroups = getHostAndGroupId(groupId);
    groupId = simpleGroups.groupId;
    relay ??= simpleGroups.relay;
    List<String> tempRelays = [];
    if (relay.isNotEmpty && !Connect.sharedInstance.webSockets.keys.contains(relay)) {
      await Connect.sharedInstance.connectRelays([relay], relayKind: RelayKind.temp);
      tempRelays.add(relay);
    }
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    groupDB ??= RelayGroupDBISAR(groupId: groupId, relay: relay, author: author ?? '');
    Completer<RelayGroupDBISAR?> completer = Completer<RelayGroupDBISAR?>();
    Filter f = Filter(kinds: [39000, 39001, 39002, 39003], d: [groupId]);
    Map<String, List<Filter>> subscriptions = {};
    subscriptions[groupDB.relay] = [f];
    Connect.sharedInstance.addSubscriptions(subscriptions, eventCallBack: (event, relay) async {
      switch (event.kind) {
        case 39000:
          Group group = Nip29.decodeMetadata(event, relay);
          groupDB!.name = group.name;
          groupDB.relay = relay;
          groupDB.picture = group.picture;
          groupDB.about = group.about;
          groupDB.private = group.private;
          groupDB.closed = group.closed;
          groupDB.subscriptionAmount = group.subscriptionAmount;
          groupDB.groupWalletId = group.groupWalletId ?? '';
          groupDB.lastUpdatedTime = event.createdAt;
          break;
        case 39001:
          List<GroupAdmin> admins = Nip29.decodeGroupAdmins(event);
          groupDB!.admins = admins;
          groupDB.lastAdminsUpdatedTime = event.createdAt;
          break;
        case 39002:
          List<GroupMember> members = Nip29.decodeGroupMembers(event);
          List<String> memberPubkeys = members.map((m) => m.pubkey).toList();
          
          // Create batch update map for subscription expiry
          Map<String, int?> memberExpiryMap = {};
          for (GroupMember member in members) {
            memberExpiryMap[member.pubkey] = member.subscriptionExpiryTimestamp;
          }
          
          if ((!checkInGroup(groupId) && memberPubkeys.contains(pubkey)) ||
              (checkInGroup(groupId) && !memberPubkeys.contains(pubkey))) {
            groupDB!.members = memberPubkeys;
            groupDB.setMemberSubscriptionExpiryBatch(memberExpiryMap);
            groupDB.lastMembersUpdatedTime = event.createdAt;
            await syncGroupToDB(groupDB);
            updateGroupSubscription();
          } else {
            groupDB!.members = memberPubkeys;
            groupDB.setMemberSubscriptionExpiryBatch(memberExpiryMap);
            groupDB.lastMembersUpdatedTime = event.createdAt;
          }
          break;
        case 39003:

          break;
      }
    }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
      if (unCompletedRelays.isEmpty && !completer.isCompleted) {
        if (groupDB != null) await syncGroupToDB(groupDB);
        // Connect.sharedInstance.closeConnects(tempRelays, RelayKind.temp);
        completer.complete(groupDB);
      }
    });
    return completer.future;
  }

  RelayGroupDBISAR handleGroupMetadata(Event event, String relay) {
    Group group = Nip29.decodeMetadata(event, relay);
    RelayGroupDBISAR? groupDB = groups[group.groupId]?.value;
    groupDB ??= RelayGroupDBISAR(groupId: group.groupId, relay: relay);
    if (event.createdAt < groupDB.lastUpdatedTime) return groupDB;
    groupDB.name = group.name;
    groupDB.relay = relay;
    groupDB.picture = group.picture;
    groupDB.about = group.about;
    groupDB.private = group.private;
    groupDB.closed = group.closed;
    groupDB.subscriptionAmount = group.subscriptionAmount;
    groupDB.lastUpdatedTime = event.createdAt;
    groupMetadataUpdatedCallBack?.call(groupDB);
    syncGroupToDB(groupDB);
    return groupDB;
  }

  Future<void> handleGroupMetadataFromModeration(GroupModeration moderation, String relay) async {
    RelayGroupDBISAR? groupDB = groups[moderation.groupId]?.value;
    groupDB ??= RelayGroupDBISAR(groupId: moderation.groupId, relay: relay);
    if (moderation.createdAt < groupDB.lastUpdatedTime) return;
    groupDB.name = moderation.name;
    groupDB.picture = moderation.picture;
    groupDB.about = moderation.about;
    groupDB.lastUpdatedTime = moderation.createdAt;
    groupMetadataUpdatedCallBack?.call(groupDB);
    await syncGroupToDB(groupDB);
  }

  Future<void> handleGroupAdmins(Event event, String relay) async {
    String groupId = Nip29.getGroupIdFromEvent(event) ?? '';
    List<GroupAdmin> admins = Nip29.decodeGroupAdmins(event);
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    groupDB ??= RelayGroupDBISAR(groupId: groupId, relay: relay);
    if (event.createdAt < groupDB.lastAdminsUpdatedTime) return;
    groupDB.admins = admins;
    groupDB.lastAdminsUpdatedTime = event.createdAt;
    groupMetadataUpdatedCallBack?.call(groupDB);
    await syncGroupToDB(groupDB);
  }

  RelayGroupDBISAR handleGroupMembers(Event event, String relay) {
    String groupId = Nip29.getGroupIdFromEvent(event) ?? '';
    List<GroupMember> members = Nip29.decodeGroupMembers(event);
    List<String> memberPubkeys = members.map((m) => m.pubkey).toList();
    
    // Create batch update map for subscription expiry
    Map<String, int?> memberExpiryMap = {};
    for (GroupMember member in members) {
      memberExpiryMap[member.pubkey] = member.subscriptionExpiryTimestamp;
    }
    
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    groupDB ??= RelayGroupDBISAR(groupId: groupId, relay: relay);
    if (event.createdAt < groupDB.lastMembersUpdatedTime) return groupDB;
    groupDB.members = memberPubkeys;
    groupDB.setMemberSubscriptionExpiryBatch(memberExpiryMap);
    groupDB.lastMembersUpdatedTime = event.createdAt;
    groupMetadataUpdatedCallBack?.call(groupDB);
    syncGroupToDB(groupDB);
    return groupDB;
  }

  List<GroupAdmin>? getGroupAdminsFromLocal(String groupId) {
    return groups[groupId]?.value.admins;
  }

  Future<List<UserDBISAR>> getGroupMembersFromLocal(String groupId) async {
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    List<UserDBISAR> result = [];
    if (groupDB != null && groupDB.members != null) {
      await Future.forEach(groupDB.members!, (member) async {
        UserDBISAR? userDB = await Account.sharedInstance.getUserInfo(member);
        if (userDB != null) {
          if (groupDB.author == member) {
            result.insert(0, userDB);
          } else {
            result.add(userDB);
          }
        }
      });
    }
    return result;
  }

  Future<List<RelayGroupDBISAR>> searchGroupsFromDB(List<String> relays) async {
    if (kIsWeb) {
      // Web platform uses dedicated methods
      return await DBISAR.sharedInstance.searchRelayGroupsByRelays(relays);
    } else {
      // Mobile platform uses Isar
      return await DBISAR.sharedInstance.isar.relayGroupDBISARs
          .where()
          .anyOf(relays, (q, relay) => q.relayEqualTo(relay))
          .findAll();
    }
  }

  Future<List<RelayGroupDBISAR>> searchAllGroupsFromRelays(
      GroupSearchCallBack? groupCallback) async {
    Set<String> relays = Set.from(groupRelays);
    relays.addAll(Config.sharedInstance.recommendGroupRelays);
    return await searchGroupsMetadataFromRelays(relays.toList(), groupCallback);
  }

  Future<RelayGroupDBISAR> searchGroupMembersFromRelays(RelayGroupDBISAR group) async {
    Completer<RelayGroupDBISAR> completer = Completer<RelayGroupDBISAR>();
    Filter f = Filter(kinds: [39002], d: [group.groupId]);
    Connect.sharedInstance.addSubscription([f], relays: [group.relay],
        eventCallBack: (event, relay) async {
      RelayGroupDBISAR groupDB = handleGroupMembers(event, relay);
      completer.complete(groupDB);
    }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
      if (unCompletedRelays.isEmpty && !completer.isCompleted) {
        completer.complete(group);
      }
    });
    return completer.future;
  }

  Future<List<RelayGroupDBISAR>> searchGroupsMetadataFromRelays(
      List<String> relays, GroupSearchCallBack? groupCallback) async {
    if (relays.isEmpty) return [];
    Map<String, RelayGroupDBISAR> result = {};
    List<RelayGroupDBISAR> resultFromDB = await searchGroupsFromDB(relays);
    for (var db in resultFromDB) {
      result[db.groupId] = db;
    }
    groupCallback?.call(resultFromDB);
    await Connect.sharedInstance.connectRelays(relays, relayKind: RelayKind.temp);
    Completer<List<RelayGroupDBISAR>> completer = Completer<List<RelayGroupDBISAR>>();
    Filter f = Filter(kinds: [39000, 39002], limit: 100);
    Connect.sharedInstance.addSubscription([f], relays: relays,
        eventCallBack: (event, relay) async {
      RelayGroupDBISAR? groupDB;
      if (event.kind == 39000) {
        groupDB = handleGroupMetadata(event, relay);
      } else if (event.kind == 39002) {
        groupDB = handleGroupMembers(event, relay);
      }
      if (groupDB != null) {
        result[groupDB.groupId] = groupDB;
      }
    }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
      // for (var groupDB in List.from(result.values.toList())) {
      //   groupDB = await searchGroupMembersFromRelays(groupDB);
      //   result[groupDB.groupId] = groupDB;
      // }
      groupCallback?.call(result.values.toList());
      if (unCompletedRelays.isEmpty && !completer.isCompleted) {
        completer.complete(result.values.toList());
      }
    });
    return completer.future;
  }

  Future<RelayGroupDBISAR?> searchGroupsMetadataWithGroupID(String id, String? relay) async {
    SimpleGroups simpleGroups = getHostAndGroupId(id);
    String groupId = simpleGroups.groupId;
    relay ??= simpleGroups.relay;
    if (groups.containsKey(groupId) && groups[groupId]!.value.lastUpdatedTime > 0) {
      return groups[groupId]!.value;
    }
    await Connect.sharedInstance.connectRelays([relay], relayKind: RelayKind.temp);
    Completer<RelayGroupDBISAR?> completer = Completer<RelayGroupDBISAR?>();
    Filter f = Filter(kinds: [39000], d: [groupId]);
    Connect.sharedInstance.addSubscription([f], relays: [relay],
        eventCallBack: (event, relay) async {
      RelayGroupDBISAR groupDB = handleGroupMetadata(event, relay);
      if (!completer.isCompleted) {
        completer.complete(groupDB);
      }
    }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
      Connect.sharedInstance.closeConnects([relay], RelayKind.temp);
      if (!completer.isCompleted) {
        completer.complete(RelayGroupDBISAR(groupId: groupId, relay: relay));
      }
    });
    return completer.future;
  }

  Future<List<RelayGroupDBISAR>> searchMyGroupsMetadataFromRelays(
      List<String> relays, GroupSearchCallBack? groupCallback) async {
    if (relays.isEmpty) return [];
   
    Map<String, RelayGroupDBISAR> result = {};
   
    UserDBISAR? me = Account.sharedInstance.me;
    if (me != null && me.relayGroupsList != null && me.relayGroupsList!.isNotEmpty) {
      for (String id in me.relayGroupsList!) {
        SimpleGroups simpleGroups = getHostAndGroupId(id);
        String groupId = simpleGroups.groupId;
        if (groupId.isEmpty) continue;
        RelayGroupDBISAR? groupDB = groups[groupId]?.value;
        if (groupDB != null) {
          result[groupId] = groupDB;
        }
      }
    }
    groupCallback?.call(result.values.toList());
    await Connect.sharedInstance.connectRelays(relays, relayKind: RelayKind.temp);
    Completer<List<RelayGroupDBISAR>> completer = Completer<List<RelayGroupDBISAR>>();
   
    Filter f = Filter(kinds: [39002], p: [pubkey]);
    Connect.sharedInstance.addSubscription([f], relays: relays,
        eventCallBack: (event, relay) async {
      RelayGroupDBISAR? groupDB;
      if (event.kind == 39000) {
        groupDB = handleGroupMetadata(event, relay);
      } else if (event.kind == 39002) {
        groupDB = handleGroupMembers(event, relay);

        List<String>? members = groupDB?.members;
        if (members != null && members.isNotEmpty && members.contains(pubkey)) {
          result[groupDB!.groupId] = groupDB;
        }
      }
    }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
      if (unCompletedRelays.isEmpty) {
        UserDBISAR? me = Account.sharedInstance.me;
        if (me != null && me.relayGroupsList != null && me.relayGroupsList!.isNotEmpty) {
          Map<String, ValueNotifier<RelayGroupDBISAR>> newMyGroups = {};
          for (String id in me.relayGroupsList!) {
            SimpleGroups simpleGroups = getHostAndGroupId(id);
            String groupId = simpleGroups.groupId;
            if (groupId.isEmpty) continue;
            if (groups.containsKey(groupId)) {
              newMyGroups[groupId] = groups[groupId]!;
            }
          }
          myGroups = newMyGroups;
        } else {
          myGroups = {};
        }
        await syncMyGroupListToRelay();
      }
      
      groupCallback?.call(result.values.toList());
      if (unCompletedRelays.isEmpty && !completer.isCompleted) {
        completer.complete(result.values.toList());
      }
    });
    return completer.future;
  }
}
