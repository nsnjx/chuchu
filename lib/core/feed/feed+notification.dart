import 'package:isar/isar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../account/model/zapRecordsDB_isar.dart';
import '../database/db_isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'feed+load.dart';
import 'feed.dart';
import 'model/notificationDB_isar.dart';

extension Notification on Feed {
  Future<List<NotificationDBISAR>?> loadNotificationsFromDB(int until, {int limit = 50}) async {
    if (kIsWeb) {
      // Web platform: use IndexedDB
      final indexedDB = DBISAR.sharedInstance.indexedDB;
      if (indexedDB == null || !indexedDB.isOpen) {
        return [];
      }
      
      final collection = indexedDB.getCollection<NotificationDBISAR>('notificationDBISARs');
      final query = collection.where();
      // Filter by createAt < until, then sort and limit
      List<NotificationDBISAR> allNotifications = await query.findAll();
      
      // Filter and sort in memory (IndexedDB query builder doesn't support complex conditions)
      allNotifications = allNotifications
          .where((n) => n.createAt < until)
          .toList();
      allNotifications.sort((a, b) => b.createAt.compareTo(a.createAt)); // Sort descending
      
      // Apply limit
      if (limit > 0 && allNotifications.length > limit) {
        allNotifications = allNotifications.take(limit).toList();
      }
      
      // Only update latestNotificationTime if we have notifications
      if (allNotifications.isNotEmpty) {
        latestNotificationTime = allNotifications.first.createAt;
      }
      
      return allNotifications;
    } else {
      // Mobile platform: use Isar
      final isar = DBISAR.sharedInstance.isar;
      List<NotificationDBISAR> notifications = await isar.notificationDBISARs
          .where()
          .createAtLessThan(until)
          .sortByCreateAtDesc()
          .findAll(limit: limit);
      
      // Only update latestNotificationTime if we have notifications
      if (notifications.isNotEmpty) {
        latestNotificationTime = notifications.first.createAt;
      }
      
      return notifications;
    }
  }

  Future<void> handleZapNotification(ZapRecordsDBISAR zapRecordsDB, Event zapEvent) async {
    // final reactedMessageDB =
    // await Messages.sharedInstance.loadMessageDBFromDB(zapRecordsDB.eventId);
    // if (reactedMessageDB != null) {
    //   await Messages.sharedInstance.handleZapRecordEvent(zapEvent);
    // } else {
    //   await addZapRecordToNote(zapEvent, zapRecordsDB.eventId);
    //   NotificationDBISAR notificationDB =
    //   NotificationDBISAR.notificationDBFromZapRecordsDB(zapRecordsDB, zapEvent.id);
    //   await saveNotificationToDB(notificationDB);
    //   if (notificationDB.author != pubkey && notificationDB.createAt > latestNotificationTime) {
    //     newNotifications.add(notificationDB);
    //     newNotificationCallBack?.call(newNotifications);
    //   } else if (notificationDB.author != pubkey) {
    //     myZapNotificationCallBack?.call([notificationDB]);
    //   }
    // }
  }

  Future<void> saveNotificationToDB(NotificationDBISAR notificationDB,
      {ConflictAlgorithm? conflictAlgorithm}) async {
    await DBISAR.sharedInstance.saveToDB(notificationDB);
  }

  Future<void> deleteAllNotifications() async {
    newNotifications.clear();
    final isar = DBISAR.sharedInstance.isar;
    await isar.write((isar) async {
      isar.notificationDBISARs.clear();
    });
  }
}
