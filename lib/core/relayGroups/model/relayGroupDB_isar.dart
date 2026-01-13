import 'dart:convert';

import 'package:isar/isar.dart';

import '../../account/model/userDB_isar.dart';
import 'package:nostr_core_dart/src/nips/nip_029.dart';
import '../../utils/log_utils.dart';

part 'relayGroupDB_isar.g.dart';

extension RelayGroupDBISARExtensions on RelayGroupDBISAR {
  RelayGroupDBISAR withGrowableLevels() => this
    ..pinned = pinned?.toList()
    ..members = members?.toList();

  /// Create a copy of this RelayGroupDBISAR with all properties copied
  /// Note: id is not copied as it's managed by Isar and should be auto-assigned
  RelayGroupDBISAR copy() {
    return RelayGroupDBISAR(
      groupId: groupId,
      author: author,
      relay: relay,
      relayPubkey: relayPubkey,
      private: private,
      closed: closed,
      lastUpdatedTime: lastUpdatedTime,
      lastMembersUpdatedTime: lastMembersUpdatedTime,
      lastAdminsUpdatedTime: lastAdminsUpdatedTime,
      mute: mute,
      adminsString: adminsString,
      name: name,
      about: about,
      picture: picture,
      pinned: pinned?.toList(),
      members: members?.toList(),
      memberSubscriptionExpiryJson: memberSubscriptionExpiryJson,
      memberSubscriptionExpiry: memberSubscriptionExpiry,
      level: level,
      point: point,
      subscriptionAmount: subscriptionAmount,
      groupWalletId: groupWalletId,
    );
  }
}

@collection
class RelayGroupDBISAR {
  @Id()
  int id = 0;

  @Index(unique: true)
  String groupId;

  String author; // group creator
  String relay;
  String relayPubkey;
  bool private;
  bool closed;
  int lastUpdatedTime;
  int lastMembersUpdatedTime;
  int lastAdminsUpdatedTime;
  bool mute;
  String? adminsString;
  String name;
  String about;
  String picture;
  List<String>? pinned;
  List<String>? members;
  String? memberSubscriptionExpiryJson; // JSON string for subscription expiry data
  @ignore
  Map<String, int>? memberSubscriptionExpiry; // Map of pubkey -> subscription expiry timestamp
  int level; // group level
  int point; // group point
  int subscriptionAmount; // subscription amount in satoshis
  String groupWalletId; // LNbits wallet ID for group payments

  RelayGroupDBISAR(
      {this.groupId = '',
      this.author = '',
      this.relay = '',
      this.relayPubkey = '',
      this.private = false,
      this.closed = false,
      this.lastUpdatedTime = 0,
      this.lastMembersUpdatedTime = 0,
      this.lastAdminsUpdatedTime = 0,
      this.mute = false,
      this.adminsString,
      this.name = '',
      this.about = '',
      this.picture = '',
      this.pinned,
      this.members,
      this.memberSubscriptionExpiryJson,
      this.memberSubscriptionExpiry,
      this.level = 0,
      this.point = 0,
      this.subscriptionAmount = 0,
      this.groupWalletId = ''});

  static RelayGroupDBISAR fromMap(Map<String, Object?> map) {
    return _groupInfoFromMap(map);
  }

  String get identifier {
    RegExp regExp = RegExp(r'(?<=wss?://)([^/]+)');
    String host = regExp.firstMatch(relay)?.group(0) ?? '';
    return '$host\'$groupId';
  }

  @ignore
  String get shortGroupId {
    String k = groupId;
    if (k.length < 12) return k;
    final String start = k.substring(0, 6);
    final String end = k.substring(k.length - 6);
    return '$start:$end';
  }

  @ignore
  String get showName {
    return name.isEmpty ? shortGroupId : name;
  }

  set admins(List<GroupAdmin> attributes) {
    adminsString = groupAdminsToString(attributes);
  }

  @ignore
  List<GroupAdmin> get admins {
    return adminsString != null ? stringToGroupAdmins(adminsString!) : [];
  }
  
  static List<GroupAdmin> stringToGroupAdmins(String json) {
    if (json.isEmpty || json == 'null') return [];
    try {
      List<dynamic> groupAdminsJson = [];
      groupAdminsJson = jsonDecode(json);
      List<GroupAdmin> admins =
          groupAdminsJson.map((json) => GroupAdmin.fromJson(json)).toList();
      return admins;
    } catch (e) {
      LogUtils.v(() => 'stringToGroupAdmins error: $e');
      return [];
    }
  }

  static String groupAdminsToString(List<GroupAdmin> admins) {
    List<List<dynamic>> adminsString =
    admins.map((admin) => admin.toJson()).toList();
    return jsonEncode(adminsString);
  }
}

RelayGroupDBISAR _groupInfoFromMap(Map<String, dynamic> map) {
  return RelayGroupDBISAR(
    groupId: map['groupId']?.toString() ?? '',
    author: map['author']?.toString() ?? '',
    relay: map['relay']?.toString() ?? '',
    relayPubkey: map['relayPubkey']?.toString() ?? '',
    private: map['private'] as bool? ?? false,
    closed: map['closed'] as bool? ?? false,
    lastUpdatedTime: (map['lastUpdatedTime'] as num?)?.toInt() ?? 0,
    lastMembersUpdatedTime: (map['lastMembersUpdatedTime'] as num?)?.toInt() ?? 0,
    lastAdminsUpdatedTime: (map['lastAdminsUpdatedTime'] as num?)?.toInt() ?? 0,
    mute: map['mute'] as bool? ?? false,
    adminsString: map['adminsString']?.toString(),
    name: map['name']?.toString() ?? '',
    about: map['about']?.toString() ?? '',
    picture: map['picture']?.toString() ?? '',
    pinned: UserDBISAR.decodeStringList(map['pinned']?.toString() ?? ''),
    members: UserDBISAR.decodeStringList(map['members']?.toString() ?? ''),
    memberSubscriptionExpiryJson: map['memberSubscriptionExpiryJson']?.toString(),
    level: (map['level'] as num?)?.toInt() ?? 0,
    point: (map['point'] as num?)?.toInt() ?? 0,
    subscriptionAmount: (map['subscriptionAmount'] as num?)?.toInt() ?? 0,
    groupWalletId: map['groupWalletId']?.toString() ?? '',
  )..id = (map['id'] as num?)?.toInt() ?? 0;
}

extension RelayGroupDBISARSubscription on RelayGroupDBISAR {
  /// Load subscription expiry data from JSON string
  void _loadSubscriptionExpiryFromJson() {
    if (memberSubscriptionExpiryJson != null && memberSubscriptionExpiryJson!.isNotEmpty) {
      try {
        Map<String, dynamic> jsonMap = jsonDecode(memberSubscriptionExpiryJson!);
        memberSubscriptionExpiry = jsonMap.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        memberSubscriptionExpiry = null;
      }
    } else {
      memberSubscriptionExpiry = null;
    }
  }
  
  /// Save subscription expiry data to JSON string
  void _saveSubscriptionExpiryToJson() {
    if (memberSubscriptionExpiry != null && memberSubscriptionExpiry!.isNotEmpty) {
      memberSubscriptionExpiryJson = jsonEncode(memberSubscriptionExpiry);
    } else {
      memberSubscriptionExpiryJson = null;
    }
  }
  
  /// Batch update subscription expiry for multiple members
  void setMemberSubscriptionExpiryBatch(Map<String, int?> memberExpiryMap) {
    _loadSubscriptionExpiryFromJson();
    memberSubscriptionExpiry ??= {};
    
    for (String pubkey in memberExpiryMap.keys) {
      int? timestamp = memberExpiryMap[pubkey];
      if (timestamp != null) {
        memberSubscriptionExpiry![pubkey] = timestamp;
      } else {
        memberSubscriptionExpiry!.remove(pubkey);
      }
    }
    
    _saveSubscriptionExpiryToJson();
  }
  
  /// Get subscription expiry timestamp for a specific member
  int? getMemberSubscriptionExpiry(String pubkey) {
    _loadSubscriptionExpiryFromJson();
    return memberSubscriptionExpiry?[pubkey];
  }
  
  /// Check if a member's subscription is expired
  bool isMemberSubscriptionExpired(String pubkey) {
    int? expiry = getMemberSubscriptionExpiry(pubkey);
    if (expiry == null) return false; // No expiry means permanent
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > expiry;
  }
  
  /// Get all members with expired subscriptions
  List<String> getExpiredMembers() {
    if (members == null || memberSubscriptionExpiry == null) return [];
    
    List<String> expiredMembers = [];
    for (String pubkey in members!) {
      if (isMemberSubscriptionExpired(pubkey)) {
        expiredMembers.add(pubkey);
      }
    }
    return expiredMembers;
  }
  
  /// Get all members with active subscriptions
  List<String> getActiveMembers() {
    if (members == null) return [];
    
    List<String> activeMembers = [];
    for (String pubkey in members!) {
      if (!isMemberSubscriptionExpired(pubkey)) {
        activeMembers.add(pubkey);
      }
    }
    return activeMembers;
  }
}
