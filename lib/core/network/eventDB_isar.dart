import 'package:isar/isar.dart';
import 'dart:convert';

part 'eventDB_isar.g.dart';

@collection
class EventDBISAR {
  @Id()
  int id = 0;

  @Index(unique: true)
  String eventId;

  String rawData;
  int? expiration;
  String? eventSendStatusJson;
  String? eventReceiveStatusJson;

  EventDBISAR(
      {this.eventId = '',
      this.rawData = '',
      this.expiration,
      List<EventStatusISAR>? eventSendStatus,
      List<EventStatusISAR>? eventReceiveStatus})
      : eventSendStatusJson = jsonEncode(eventSendStatus),
        eventReceiveStatusJson = jsonEncode(eventReceiveStatus);

  @ignore
  List<EventStatusISAR> get eventSendStatus {
    if (eventSendStatusJson == null || eventSendStatusJson!.isEmpty) {
      return [];
    }

    try {
      List<dynamic> decodedJson = jsonDecode(eventSendStatusJson!);
      return decodedJson.map((e) => EventStatusISAR.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  set eventSendStatus(List<EventStatusISAR> statuses) {
    eventSendStatusJson = jsonEncode(statuses);
  }

  @ignore
  List<EventStatusISAR> get eventReceiveStatus {
    if (eventReceiveStatusJson == null || eventReceiveStatusJson!.isEmpty) {
      return [];
    }

    try {
      List<dynamic> decodedJson = jsonDecode(eventReceiveStatusJson!);
      return decodedJson.map((e) => EventStatusISAR.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  set eventReceiveStatus(List<EventStatusISAR> statuses) {
    eventReceiveStatusJson = jsonEncode(statuses);
  }

  static EventDBISAR fromMap(Map<String, dynamic> map) {
    return EventDBISAR(
      eventId: map['eventId']?.toString() ?? '',
      rawData: map['rawData']?.toString() ?? '',
      expiration: (map['expiration'] as num?)?.toInt(),
      eventSendStatus: map['eventSendStatusJson'] != null
          ? _parseEventStatusList(map['eventSendStatusJson'])
          : null,
      eventReceiveStatus: map['eventReceiveStatusJson'] != null
          ? _parseEventStatusList(map['eventReceiveStatusJson'])
          : null,
    )..id = (map['id'] as num?)?.toInt() ?? 0;
  }

  static List<EventStatusISAR>? _parseEventStatusList(dynamic jsonString) {
    if (jsonString == null) return null;
    try {
      final String jsonStr = jsonString is String ? jsonString : jsonString.toString();
      if (jsonStr.isEmpty) return null;
      List<dynamic> decodedJson = jsonDecode(jsonStr);
      return decodedJson.map((e) => EventStatusISAR.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return null;
    }
  }
}

class EventStatusISAR {
  String relay;
  bool status;
  String message;

  EventStatusISAR({this.relay = '', this.status = false, this.message = ''});

  factory EventStatusISAR.fromJson(Map<String, dynamic> json) =>
      EventStatusISAR(
        relay: json['relay'],
        status: json['status'],
        message: json['message'],
      );

  Map<String, dynamic> toJson() => {
        'relay': relay,
        'status': status,
        'message': message,
      };
}
