import 'package:chuchu/core/network/eventDB_isar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:isar/isar.dart';

import '../database/db_isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import '../utils/log_utils.dart';

class EventCache {
  /// singleton
  EventCache._internal();
  factory EventCache() => sharedInstance;
  static final EventCache sharedInstance = EventCache._internal();

  Set<String> cacheIds = {};
  //cache kinds
  List<int> kinds = [4, 1059, 42, 1, 6, 7, 9, 10, 11, 12, 9735];

  final cacheTimeStamp = 24 * 60 * 60 * 7;

  Future<void> loadAllEventsFromDB() async {
    List<EventDBISAR> eventDBs;
    if (kIsWeb) {
      // Web platform uses dedicated methods
      eventDBs = await DBISAR.sharedInstance.findAllEvents();
    } else {
      // Mobile platform uses Isar
      eventDBs = await DBISAR.sharedInstance.isar.eventDBISARs.where().findAll();
    }
    List<int> expiredEvents = [];
    for (var eventDB in eventDBs) {
      if (eventDB.expiration != null &&
          eventDB.expiration! > 0 &&
          eventDB.expiration! < currentUnixTimestampSeconds()) {
        if (eventDB.id != 0) {
          expiredEvents.add(eventDB.id);
        }
        continue;
      }
      cacheIds.add(eventDB.eventId);
    }

    if (expiredEvents.isEmpty) return;
    
    if (kIsWeb) {
      // Web platform uses dedicated methods
      await DBISAR.sharedInstance.deleteEvents(expiredEvents);
      LogUtils.v(() => 'Deleted event caches: ${expiredEvents.length}');
    } else {
      // Mobile platform uses Isar
      DBISAR.sharedInstance.isar.write((isar) {
        int result = DBISAR.sharedInstance.isar.eventDBISARs.deleteAll(expiredEvents);
        LogUtils.v(() => 'Deleted event caches: $result');
      });
    }
  }

  Future<EventDBISAR?> loadEventFromDB(String eventId) async {
    if (kIsWeb) {
      // Web platform uses dedicated methods
      return await DBISAR.sharedInstance.findEventByEventId(eventId);
    } else {
      // Mobile platform uses Isar
      return await DBISAR.sharedInstance.isar.eventDBISARs
          .where()
          .eventIdEqualTo(eventId)
          .findFirst();
    }
  }

  Future<void> saveEventToDB(EventDBISAR eventDB) async {
    await DBISAR.sharedInstance.saveToDB(eventDB);
  }

  Future<bool> eventExit(Event event) async {
    EventDBISAR? eventDB = await loadEventFromDB(event.id);
    return eventDB != null;
  }

  Future<void> receiveEvent(Event event, String relay) async {
    if (cacheIds.contains(event.id)) return;
    cacheIds.add(event.id);
    if (!kinds.contains(event.kind)) return;
    EventDBISAR? eventDB =
        EventDBISAR(eventId: event.id, expiration: currentUnixTimestampSeconds() + cacheTimeStamp);
    eventDB.eventReceiveStatus.add(EventStatusISAR(relay: relay, status: true, message: ''));
    await saveEventToDB(eventDB);
  }

  Future<void> sendEvent(Event event, String relay, bool status, String message) async {
    cacheIds.add(event.id);
    EventDBISAR? eventDB = await loadEventFromDB(event.id);
    eventDB ??=
        EventDBISAR(eventId: event.id, expiration: currentUnixTimestampSeconds() + cacheTimeStamp);
    eventDB.eventSendStatus.add(EventStatusISAR(relay: relay, status: status, message: message));
    await saveEventToDB(eventDB);
  }
}
