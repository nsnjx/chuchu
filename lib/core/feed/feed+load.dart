import 'dart:async';
import 'package:chuchu/core/contacts/contacts+blocklist.dart';
import 'package:chuchu/core/feed/feed+notification.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:isar/isar.dart' hide Filter;

import '../account/account.dart';
import '../utils/log_utils.dart';
import '../account/model/zapRecordsDB_isar.dart';
import '../account/zaps.dart';
import '../contacts/contacts.dart';
import '../database/db_isar.dart';
import '../messages/messages.dart';
import '../config/config.dart';
import '../network/connect.dart';
import '../network/eventCache.dart';
import '../relayGroups/relayGroup.dart';
import 'feed.dart';
import 'model/noteDB_isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'model/notificationDB_isar.dart';

typedef NoteCallBack = void Function(NoteDBISAR);
typedef ActionsCallBack = void Function(Map<String, List<dynamic>>);

enum ConflictAlgorithm {
  rollback,
  abort,
  fail,
  ignore,
  replace,
}

void _logIsarResults(String label, List<NoteDBISAR> notes) {
  if (!kDebugMode) return;
  // ignore: avoid_print
  print('[Feed][$label] fetched ${notes.length} notes: '
      '${notes.take(5).map((n) => n.noteId).toList()}');
}

extension Load on Feed {
  // Future<List<NoteDB>?> loadAllNotesFromDB({int limit = 50, int? until}) async {
  //   until ??= currentUnixTimestampSeconds() + 1;
  //   List<NoteDB>? notes = await loadNotesFromDB(
  //       where: 'createAt < ?',
  //       whereArgs: [until],
  //       orderBy: 'createAt desc',
  //       limit: limit);
  //   for (var note in notes) {
  //     notesCache[note.noteId] = note;
  //     Messages.addToLoaded(note.noteId);
  //   }
  //   return notes;
  // }

  Future<List<NoteDBISAR>?> loadAllNotesFromDB({int limit = 50, int? until, bool? private}) async {
    List<String> authors = Contacts.sharedInstance.allContacts.keys.toList();
    authors.addAll(Account.sharedInstance.me?.followingList ?? []);
    authors.add(pubkey);
    return await loadUserNotesFromDB(authors, limit: limit, until: until, private: private);
  }

  Future<List<NoteDBISAR>?> loadContactsNotesFromDB(
      {int limit = 50, int? until, bool? private = false}) async {
    Set<String> authors = Set.from(Contacts.sharedInstance.allContacts.keys.toList());
    authors.add(pubkey);

    return await loadUserNotesFromDB(authors.toList(),
        limit: limit, until: until, private: private);
  }

  Future<List<NoteDBISAR>?> loadFollowsNotesFromDB(
      {int limit = 50, int? until, bool? private = false}) async {
    List<String> authors = Account.sharedInstance.me?.followingList ?? [];
    return await loadUserNotesFromDB(authors, limit: limit, until: until, private: private);
  }

  Future<List<NoteDBISAR>?> loadMyReactedNotesFromDB(
      {int limit = 50, int? until, bool? private = false}) async {
    List<String> authors = [pubkey];
    List<NoteDBISAR>? reactedNotes = await loadUserNotesFromDB(authors,
        limit: limit, until: until, private: private, isReacted: true);
    List<ZapRecordsDBISAR?> zapRecords = await Zaps.searchZapRecordsFromDB(sender: pubkey);
    List<String> reactedIds = [];
    for (NoteDBISAR note in reactedNotes ?? []) {
      if (note.reactedId != null) reactedIds.add(note.reactedId!);
    }
    for (ZapRecordsDBISAR? zapRecordsDB in zapRecords) {
      if (zapRecordsDB != null && zapRecordsDB.eventId.isNotEmpty) {
        reactedIds.add(zapRecordsDB.eventId);
      }
    }
    List<NoteDBISAR> result = [];
    await Future.forEach(reactedIds, (noteId) async {
      NoteDBISAR? n = await loadNoteWithNoteId(noteId, reload: false);
      if (n != null) result.add(n);
    });
    result.sort((a, b) => b.createAt.compareTo(a.createAt));
    return result;
  }

  Future<List<NoteDBISAR>?> loadMyNotesFromDB({int limit = 50, int? until}) async {
    return await loadUserNotesFromDB([pubkey], limit: limit, until: until);
  }

  Future<List<NoteDBISAR>?> loadUserNotesFromDB(List<String> userPubkeys,
      {int limit = 50, int? until, bool? private, bool? isReacted, String? root}) async {
    // remove blocklist pubkeys
    userPubkeys =
        userPubkeys.where((pubkey) => !Contacts.sharedInstance.inBlockList(pubkey)).toList();
    if (userPubkeys.isEmpty) return null;
    until ??= currentUnixTimestampSeconds() + 1;

    List<NoteDBISAR>? notes = await searchNotesFromDB(
        authors: userPubkeys,
        until: until,
        limit: limit,
        isReacted: isReacted,
        private: private,
        root: root);

    for (var note in notes) {
      notesCache[note.noteId] = note;
      latestNoteTime = note.createAt > latestNoteTime ? note.createAt : latestNoteTime;
    }
    return notes;
  }

  Future<NoteDBISAR?> loadNoteFromDBWithNoteId(String noteId) async {
    List<NoteDBISAR>? result = await searchNotesFromDB(noteId: noteId);
    return result.isEmpty ? null : result[0];
  }

  Future<NoteDBISAR?> loadNoteWithNoteId(String noteId,
      {bool private = false, bool reload = true, List<String>? relays}) async {
    if (notesCache.containsKey(noteId)) return notesCache[noteId];
    NoteDBISAR? note = await loadNoteFromDBWithNoteId(noteId);
    if (note == null && !private && reload) {
      note = await loadPublicNoteFromRelay(noteId, relays: relays);
    }
    if (note != null) notesCache[noteId] = note;
    return note;
  }

  Future<NoteDBISAR?> loadNoteWithNevent(String nevent,
      {bool private = false, bool reload = true}) async {
    String? noteId;
    List<String>? relays;
    if (nevent.startsWith('nostr:')) {
      nevent = Nip21.decode(nevent)!;
    }
    Map result = Nip19.decodeShareableEntity(nevent);
    if (result['prefix'] == 'nevent') {
      noteId = result['special'];
      relays = result['relays'];
      if (noteId != null) {
        return await loadNoteWithNoteId(noteId, private: private, reload: reload, relays: relays);
      }
    }
    return null;
  }

  Future<void> saveNoteToDB(NoteDBISAR noteDB, ConflictAlgorithm? conflictAlgorithm) async {
    if (!notesCache.containsKey(noteDB.noteId) || conflictAlgorithm != ConflictAlgorithm.ignore) {
      notesCache[noteDB.noteId] = noteDB;
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Feed] saveNoteToDB noteId=${noteDB.noteId} groupId=${noteDB.groupId} conflict=$conflictAlgorithm');
    }
    await DBISAR.sharedInstance.saveToDB(noteDB);
    notesCache[noteDB.noteId] = noteDB;
  }

  Future<NoteDBISAR?> loadPublicNoteFromRelay(String noteId, {List<String>? relays}) async {
    if (noteId.isEmpty) return null;

    Completer<NoteDBISAR?> completer = Completer<NoteDBISAR?>();

    List<String> tempRelays = [];
    for (var relay in relays ?? []) {
      if (relay.isNotEmpty && !Connect.sharedInstance.webSockets.keys.contains(relay)) {
        await Connect.sharedInstance.connectRelays([relay], relayKind: RelayKind.temp);
        tempRelays.add(relay);
      }
    }
    EventCache.sharedInstance.cacheIds.remove(noteId);
    Filter f = Filter(ids: [noteId]);
    Connect.sharedInstance.addSubscription([f], relays: relays,
        eventCallBack: (event, relay) async {
          NoteDBISAR? noteDB;
          switch (event.kind) {
            case 1:
              if (Nip18.hasQTag(event)) {
                QuoteReposts quoteReposts = Nip18.decodeQuoteReposts(event);
                noteDB = NoteDBISAR.noteDBFromQuoteReposts(quoteReposts);
              } else {
                Note note = Nip1.decodeNote(event);
                noteDB = NoteDBISAR.noteDBFromNote(note);
              }
              break;
            case 6:
              Reposts reposts = await Nip18.decodeReposts(event);
              noteDB = NoteDBISAR.noteDBFromReposts(reposts);
              break;
            case 7:
              Reactions reactions = Nip25.decode(event);
              noteDB = NoteDBISAR.noteDBFromReactions(reactions);
              break;
          }
          if (!completer.isCompleted) completer.complete(noteDB);
          if (noteDB != null) saveNoteToDB(noteDB, ConflictAlgorithm.ignore);
        }, eoseCallBack: (requestId, ok, relay, unRelays) async {
          if (unRelays.isEmpty) {
            if (!completer.isCompleted) {
              NoteDBISAR? note = await loadNoteWithNoteId(noteId, reload: false);
              Connect.sharedInstance.closeConnects(tempRelays, RelayKind.temp);
              if (!completer.isCompleted) completer.complete(note);
            }
          }
        });
    return completer.future;
  }

  Future<NoteDBISAR> loadPublicNoteActionsFromDB(NoteDBISAR noteDB,
      {NoteCallBack? noteCallBack}) async {
    List<NoteDBISAR> notes1 = await searchNotesFromDB(root: noteDB.noteId);
    List<NoteDBISAR> notes2 = await searchNotesFromDB(reply: noteDB.noteId);
    List<NoteDBISAR> notes3 = await searchNotesFromDB(repostId: noteDB.noteId);
    List<NoteDBISAR> notes4 = await searchNotesFromDB(quoteRepostId: noteDB.noteId);
    List<NoteDBISAR> notes5 = await searchNotesFromDB(reactedId: noteDB.noteId);

    List<NoteDBISAR> notes = [];
    notes.addAll(notes1);
    notes.addAll(notes2);
    notes.addAll(notes3);
    notes.addAll(notes4);
    notes.addAll(notes5);

    noteDB.replyEventIds ??= [];
    noteDB.repostEventIds ??= [];
    noteDB.quoteRepostEventIds ??= [];
    noteDB.reactionEventIds ??= [];

    for (var note in notes) {
      // check reply
      if (note.reply == noteDB.noteId && !noteDB.replyEventIds!.contains(note.noteId)) {
        noteDB.replyEventIds!.add(note.noteId);
        noteDB.replyCount++;
        if (note.author == pubkey) noteDB.replyCountByMe++;
      } else if ((note.root == noteDB.noteId && (note.reply == null || note.reply!.isEmpty)) &&
          !noteDB.replyEventIds!.contains(note.noteId)) {
        noteDB.replyEventIds!.add(note.noteId);
        noteDB.replyCount++;
        if (note.author == pubkey) noteDB.replyCountByMe++;
      }
      // check repost
      if (note.repostId == noteDB.noteId && !noteDB.repostEventIds!.contains(note.noteId)) {
        noteDB.repostEventIds!.add(note.noteId);
        noteDB.repostCount++;
        if (note.author == pubkey) noteDB.repostCountByMe++;
      }
      // check quote repost
      if (note.quoteRepostId == noteDB.noteId &&
          !noteDB.quoteRepostEventIds!.contains(note.noteId)) {
        noteDB.quoteRepostEventIds!.add(note.noteId);
        noteDB.quoteRepostCount++;
        if (note.author == pubkey) noteDB.quoteRepostCountByMe++;
      }
      // check reaction
      if (note.reactedId == noteDB.noteId && !noteDB.reactionEventIds!.contains(note.noteId)) {
        noteDB.reactionEventIds!.add(note.noteId);
        noteDB.reactionCount++;
        if (note.author == pubkey) noteDB.reactionCountByMe++;
      }
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
    return noteDB;
  }

  Future<NoteDBISAR> loadPublicNoteActionsFromRelay(NoteDBISAR noteDB,
      {NoteCallBack? noteCallBack}) async {
    String noteId = noteDB.noteId;
    Completer<NoteDBISAR> completer = Completer<NoteDBISAR>();

    // Only use relayGroup (chuchu.app) so notes/replies saved to DB are from chuchu.app
    final noteRelays = Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup]).isNotEmpty
        ? Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup])
        : Config.sharedInstance.recommendGroupRelays;
    Map<String, Event> result = {};
    Map<String, List<Filter>> subscriptions = {};
    for (String relayURL in noteRelays) {
      int lastUpdatedTime = noteDB.getLastUpdatedTime(relayURL);
      Filter f = lastUpdatedTime == 0
          ? Filter(kinds: [1, 6, 7, 9735], e: [noteId])
          : Filter(kinds: [1, 6, 7, 9735], e: [noteId], since: lastUpdatedTime + 1);
      subscriptions[relayURL] = [f];
    }
    Connect.sharedInstance.addSubscriptions(subscriptions, eventCallBack: (event, relay) async {
      if (Contacts.sharedInstance.inBlockList(event.pubkey)) return;
      if (!result.containsKey(event.id)) {
        result[event.id] = event;
        switch (event.kind) {
          case 1:
            Nip18.hasQTag(event)
                ? addQuoteRepostToNote(event, noteId)
                : addReplyToNote(event, noteId);
            break;
          case 6:
            addRepostToNote(event, noteId);
            break;
          case 7:
            addReactionToNote(event, noteId);
            break;
          case 9735:
            addZapRecordToNote(event, noteId);
            break;
        }
        NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
        noteCallBack?.call(noteDB!);
      }
    }, eoseCallBack: (requestId, ok, relay, unRelays) async {
      if (ok.status) {
        NoteDBISAR? noteDB = notesCache[noteId];
        noteDB?.lastUpdatedTime[relay] = currentUnixTimestampSeconds();
      }
      if (unRelays.isEmpty) {
        NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
        if (!completer.isCompleted) completer.complete(noteDB);
      }
    });
    return completer.future;
  }

  Future<void> addZapRecordToNote(Event zapEvent, String noteId) async {
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId, reload: false);
    if (noteDB == null) return;
    noteDB.zapEventIds ??= [];
    ZapReceipt zapReceipt = await Nip57.getZapReceipt(
        zapEvent, Account.sharedInstance.currentPubkey, Account.sharedInstance.currentPrivkey);
    ZapRecordsDBISAR zapRecordsDB = ZapRecordsDBISAR.zapReceiptToZapRecordsDB(zapReceipt);
    if (noteDB.zapEventIds?.contains(zapRecordsDB.bolt11) == true) return;
    Zaps.saveZapRecordToDB(zapRecordsDB);
    noteDB.zapEventIds?.add(zapRecordsDB.bolt11);
    noteDB.zapCount++;
    // noteDB.zapAmount += ZapRecordsDBISAR.getZapAmount(zapRecordsDB.bolt11);
    if (zapRecordsDB.sender == pubkey) {
      noteDB.zapCountByMe++;
      // noteDB.zapAmountByMe += ZapRecordsDBISAR.getZapAmount(zapRecordsDB.bolt11);
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
  }

  Future<void> addReplyToNote(Event replyEvent, String replyId) async {
    Note replyNote = Nip1.decodeNote(replyEvent);
    NoteDBISAR replyNoteDB = NoteDBISAR.noteDBFromNote(replyNote);
    String noteId = replyNoteDB.reply ?? '';
    if (noteId.isEmpty) noteId = replyNoteDB.root ?? '';
    if (noteId.isEmpty) noteId = replyId;
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
    if (noteDB == null) return;
    noteDB.replyEventIds ??= [];
    if (noteDB.replyEventIds?.contains(replyEvent.id) == true) return;
    saveNoteToDB(replyNoteDB, ConflictAlgorithm.ignore);
    noteDB.replyEventIds?.add(replyNoteDB.noteId);
    
    // Update reply count - check if this is a direct reply or root reply
    // This logic should match loadPublicNoteActionsFromDB for consistency
    bool shouldIncrementCount = false;
    if (replyNoteDB.reply == noteDB.noteId) {
      // Direct reply to this note
      shouldIncrementCount = true;
    } else if (replyNoteDB.root == noteDB.noteId && 
               (replyNoteDB.reply == null || replyNoteDB.reply!.isEmpty)) {
      // Root reply (reply to root note, not a nested reply)
      shouldIncrementCount = true;
    }
    
    if (shouldIncrementCount) {
      noteDB.replyCount++;
    }
    if (replyEvent.pubkey == pubkey) {
      noteDB.replyCountByMe++;
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
  }

  Future<void> addRepostToNote(Event repostEvent, String noteId) async {
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
    if (noteDB == null) return;
    noteDB.repostEventIds ??= [];
    if (noteDB.repostEventIds?.contains(repostEvent.id) == true) return;

    Reposts reposts = await Nip18.decodeReposts(repostEvent);
    NoteDBISAR repostDB = NoteDBISAR.noteDBFromReposts(reposts);
    saveNoteToDB(repostDB, ConflictAlgorithm.ignore);
    noteDB.repostEventIds?.add(repostDB.noteId);
    noteDB.repostCount++;
    if (reposts.pubkey == pubkey) {
      noteDB.repostCountByMe++;
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
  }

  Future<void> addQuoteRepostToNote(Event quoteRepostEvent, String noteId) async {
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
    if (noteDB == null) return;
    noteDB.quoteRepostEventIds ??= [];
    if (noteDB.quoteRepostEventIds?.contains(quoteRepostEvent.id) == true) {
      return;
    }

    QuoteReposts quoteReposts = Nip18.decodeQuoteReposts(quoteRepostEvent);
    NoteDBISAR quoteRepostDB = NoteDBISAR.noteDBFromQuoteReposts(quoteReposts);
    saveNoteToDB(quoteRepostDB, ConflictAlgorithm.ignore);
    noteDB.quoteRepostEventIds?.add(quoteRepostDB.noteId);
    noteDB.quoteRepostCount++;
    if (quoteReposts.pubkey == pubkey) {
      noteDB.quoteRepostCountByMe++;
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
  }

  Future<void> addReactionToNote(Event reactionEvent, String noteId) async {
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
    if (noteDB == null) return;
    noteDB.reactionEventIds ??= [];
    if (noteDB.reactionEventIds?.contains(reactionEvent.id) == true) return;

    Reactions reactions = Nip25.decode(reactionEvent);
    NoteDBISAR reactionDB = NoteDBISAR.noteDBFromReactions(reactions);
    saveNoteToDB(reactionDB, ConflictAlgorithm.ignore);
    noteDB.reactionEventIds?.add(reactionDB.noteId);
    noteDB.reactionCount++;
    if (reactions.pubkey == pubkey) {
      noteDB.reactionCountByMe++;
    }
    saveNoteToDB(noteDB, ConflictAlgorithm.replace);
  }

  Future<List<NoteDBISAR>?> loadAllNewNotesFromRelay({int? until, int? since, int? limit}) async {
    List<String> authors = Contacts.sharedInstance.allContacts.keys.toList();
    authors.addAll(Account.sharedInstance.me?.followingList ?? []);
    authors.add(pubkey);
    return await loadNewNotesFromRelay(limit: limit, authors: authors, until: until, since: since);
  }

  Future<List<NoteDBISAR>?> loadContactsNewNotesFromRelay(
      {int? until, int? since, int? limit}) async {
    List<String> authors = Contacts.sharedInstance.allContacts.keys.toList();
    authors.add(pubkey);
    return await loadNewNotesFromRelay(limit: limit, authors: authors, until: until, since: since);
  }

  Future<List<NoteDBISAR>?> loadFollowsNewNotesFromRelay(
      {int? until, int? since, int? limit}) async {
    List<String> authors = Account.sharedInstance.me?.followingList ?? [];
    authors.add(pubkey);
    return await loadNewNotesFromRelay(limit: limit, authors: authors, until: until, since: since);
  }

  Future<List<NoteDBISAR>?> loadNewNotesFromRelay(
      {int? limit = 50, List<String>? authors, int? until, int? since}) async {
    Completer<List<NoteDBISAR>?> completer = Completer<List<NoteDBISAR>?>();
    if (authors != null) {
      // remove blocklist pubkeys
      authors = authors.where((pubkey) => !Contacts.sharedInstance.inBlockList(pubkey)).toList();
      if (authors.isEmpty) return null;
    }
    authors ??= [pubkey];
    Filter f = Filter(kinds: [1], authors: authors, limit: limit, until: until, since: since);
    Map<String, Event> result = {};
    // Only use relayGroup (chuchu.app) so notes saved to DB are from chuchu.app
    final noteRelays = Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup]).isNotEmpty
        ? Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup])
        : Config.sharedInstance.recommendGroupRelays;
    Connect.sharedInstance.addSubscription([f], relays: noteRelays, relayKind: RelayKind.relayGroup,
        eventCallBack: (event, relay) async {
      result[event.id] = event;
    }, eoseCallBack: (requestId, ok, relay, unRelays) async {
      if (unRelays.isEmpty) {
        List<NoteDBISAR> r = [];
        List<Event> values = List.from(result.values);
        for (Event event in values) {
          NoteDBISAR? noteDB;
          Note note = Nip1.decodeNote(event);
          noteDB = NoteDBISAR.noteDBFromNote(note);
          await saveNoteToDB(noteDB, ConflictAlgorithm.ignore);
          r.add(noteDB);
        }
        if (!completer.isCompleted) completer.complete(r);
      }
    });
    return completer.future;
  }

  Future<List<NoteDBISAR>?> loadHashTagsFromRelay(List<String> hashTags,
      {int limit = 30, int? until}) async {
    List<NoteDBISAR> returnResult = [];
    List<NoteDBISAR> searchResult;
    if (kIsWeb) {
      // Web platform uses dedicated methods
      searchResult = await DBISAR.sharedInstance.searchNotesByHashTags(hashTags, limit: limit);
    } else {
      // Mobile platform uses Isar
      searchResult = await DBISAR.sharedInstance.isar.noteDBISARs
          .where()
          .anyOf(hashTags, (q, hashTag) => q.hashTagsElementEqualTo(hashTag))
          .findAll();
    }
    for (var note in searchResult) {
      note = note.withGrowableLevels();
      returnResult.add(note);
    }
    Completer<List<NoteDBISAR>?> completer = Completer<List<NoteDBISAR>?>();
    Filter f = Filter(kinds: [1], t: hashTags, until: until, limit: limit);
    Map<String, Event> result = {};
    // Only use relayGroup (chuchu.app) so notes saved to DB are from chuchu.app
    final noteRelays = Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup]).isNotEmpty
        ? Connect.sharedInstance.relays(relayKinds: [RelayKind.relayGroup])
        : Config.sharedInstance.recommendGroupRelays;
    Connect.sharedInstance.addSubscription([f], relays: noteRelays, relayKind: RelayKind.relayGroup,
        eventCallBack: (event, relay) async {
      result[event.id] = event;
    }, eoseCallBack: (requestId, ok, relay, unRelays) async {
      if (unRelays.isEmpty) {
        for (Event event in result.values) {
          NoteDBISAR? noteDB;
          Note note = Nip1.decodeNote(event);
          noteDB = NoteDBISAR.noteDBFromNote(note);
          saveNoteToDB(noteDB, ConflictAlgorithm.ignore);
          returnResult.add(noteDB);
        }
        returnResult.sort((a, b) => b.createAt.compareTo(a.createAt));
        if (!completer.isCompleted) completer.complete(returnResult);
      }
    });
    return completer.future;
  }

  Future<void> loadOldNotes() async {}

  Future<List<NoteDBISAR>> loadNoteIdsToNoteDBs(
      List<String> noteIds, bool private, bool reload) async {
    List<NoteDBISAR> result = [];
    List<String> copiedNoteIds = List.from(noteIds);
    for (var noteId in copiedNoteIds) {
      NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId);
      if (!private && reload) {
        noteDB ??= await loadPublicNoteFromRelay(noteId);
      }
      if (noteDB != null) result.add(noteDB);
    }
    return result;
  }

  static Future<List<ZapRecordsDBISAR>> loadInvoicesToZapRecords(
      List<String> invoices, bool private) async {
    List<ZapRecordsDBISAR> result = [];
    for (var invoice in invoices) {
      List<ZapRecordsDBISAR> zapRecords = await Zaps.getZapReceipt('', invoice: invoice);
      if (zapRecords.isNotEmpty) result.add(zapRecords.first);
    }
    return result;
  }

  Future<Map<String, List<dynamic>>> loadNoteActions(String noteId,
      {bool reload = true, ActionsCallBack? actionsCallBack}) async {
    Map<String, List<dynamic>> result = {
      'reply': [],
      'repost': [],
      'quoteRepost': [],
      'reaction': [],
      'zap': []
    };
    NoteDBISAR? noteDB = await loadNoteWithNoteId(noteId, reload: reload);
    if (noteDB != null) {
      noteDB = await loadPublicNoteActionsFromDB(noteDB);
      result['reply'] =
      await loadNoteIdsToNoteDBs(noteDB.replyEventIds ?? [], noteDB.private, reload);
      actionsCallBack?.call(result);
      if (!noteDB.private && reload) {
        await loadPublicNoteActionsFromRelay(noteDB, noteCallBack: (noteDB) async {
          result['reply'] =
          await loadNoteIdsToNoteDBs(noteDB.replyEventIds ?? [], noteDB.private, reload);
          // result['repost'] = await _loadNoteIdsToNoteDBs(
          //     noteDB.repostEventIds ?? [], noteDB.private, reload);
          // result['quoteRepost'] = await _loadNoteIdsToNoteDBs(
          //     noteDB.quoteRepostEventIds ?? [], noteDB.private, reload);
          // result['reaction'] = await _loadNoteIdsToNoteDBs(
          //     noteDB.reactionEventIds ?? [], noteDB.private, reload);
          // result['zap'] = await loadInvoicesToZapRecords(
          //     noteDB.zapEventIds ?? [], noteDB.private);
          actionsCallBack?.call(result);
        });
      }
    }
    return result;
  }

  List<NoteDBISAR> searchNotesFromCache(
      String? noteId,
      String? groupId,
      List<String>? authors,
      String? root,
      String? reply,
      String? repostId,
      String? quoteRepostId,
      String? reactedId,
      bool? isReacted,
      bool? private,
      int? until,
      int? limit,
      ) {
    final Map<Type, List<dynamic>> buffers = DBISAR.sharedInstance.getBuffers();
    List<NoteDBISAR> result = [];
    for (NoteDBISAR noteDB in buffers[NoteDBISAR]?.toList() ?? []) {
      bool query = true;
      if (query && noteId != null) {
        query = noteDB.noteId == noteId;
      }
      if (query && groupId != null && groupId.isNotEmpty) {
        query = noteDB.groupId == groupId;
      }
      if (query && authors != null) {
        query = authors.any((author) => noteDB.author == author);
      }
      if (query && root != null) {
        query = noteDB.root == root;
      }
      if (query && reply != null) {
        query = noteDB.reply == reply;
      }
      if (query && repostId != null) {
        query = noteDB.repostId == repostId;
      }
      if (query && quoteRepostId != null) {
        query = noteDB.quoteRepostId == quoteRepostId;
      }
      if (query && reactedId != null) {
        query = noteDB.reactedId == reactedId;
      }
      if (query && isReacted != null) {
        query =
        isReacted ? noteDB.reactedId?.isNotEmpty == true : noteDB.reactedId?.isEmpty == true;
      }
      if (query && private != null) {
        query = noteDB.private == private;
      }
      if (query && until != null) {
        query = noteDB.createAt < until;
      }
      if (query) result.add(noteDB);
    }
    return result;
  }

  List<NoteDBISAR> _filterNotesFromMemoryCache({
    String? noteId,
    String? groupId,
    List<String>? groupIds,
    List<String>? authors,
    String? root,
    String? reply,
    String? repostId,
    String? quoteRepostId,
    String? reactedId,
    bool? isReacted,
    bool? private,
    int? until,
    String? keyword,
  }) {
    final List<NoteDBISAR> matches = [];
    if (notesCache.isEmpty) return matches;
    for (final note in notesCache.values) {
      bool include = true;
      if (noteId != null && note.noteId != noteId) include = false;
      if (include && groupId != null) {
        if (groupId.isNotEmpty) {
          include = note.groupId == groupId;
        } else {
          include = note.groupId.isEmpty;
        }
      }
      if (include && groupIds != null && groupIds.isNotEmpty) {
        include = groupIds.contains(note.groupId);
      }
      if (include && authors != null) {
        include = authors.contains(note.author);
      }
      if (include && root != null) {
        include = note.root == root;
      }
      if (include && reply != null) {
        include = note.reply == reply;
      }
      if (include && repostId != null) {
        include = note.repostId == repostId;
      }
      if (include && quoteRepostId != null) {
        include = note.quoteRepostId == quoteRepostId;
      }
      if (include && reactedId != null) {
        include = note.reactedId == reactedId;
      }
      if (include && until != null) {
        include = note.createAt < until;
      }
      if (include && isReacted != null) {
        include = isReacted
            ? note.reactedId?.isNotEmpty == true
            : (note.reactedId == null || note.reactedId!.isEmpty);
      }
      if (include && private != null) {
        include = note.private == private;
      }
      if (include) {
        final String keywordValue = keyword ?? '';
        if (keywordValue.isNotEmpty) {
          final content = note.content;
          include = content.contains(keywordValue);
        }
      }
      if (include) {
        matches.add(note);
      }
    }
    return matches;
  }

  void _addUniqueNotes(List<NoteDBISAR> source, List<NoteDBISAR> target, Set<String> seenNoteIds) {
    if (source.isEmpty) return;
    for (final note in source) {
      final id = note.noteId;
      if (id.isEmpty) continue;
      if (seenNoteIds.add(id)) {
        target.add(note);
      }
    }
  }

  List<NoteDBISAR> _finalizeNoteResults(List<NoteDBISAR> notes, int? limit) {
    if (notes.isEmpty) return [];
    notes.sort((a, b) => b.createAt.compareTo(a.createAt));
    final List<NoteDBISAR> sorted =
        limit != null && notes.length > limit ? notes.take(limit).toList() : List.of(notes);
    return sorted.map((note) => note.withGrowableLevels()).toList();
  }

  Future<List<NoteDBISAR>> searchNotesFromDB(
      {String? noteId,
        String? groupId,
        List<String>? authors,
        String? root,
        String? reply,
        String? repostId,
        String? quoteRepostId,
        String? reactedId,
        bool? isReacted,
        bool? private,
        int? until,
        int? limit,
        String? keyword}) async {
    final bool isWeb = kIsWeb;
    final List<NoteDBISAR> aggregated = [];
    final Set<String> seenNoteIds = {};

    void addNotes(List<NoteDBISAR> notes) => _addUniqueNotes(notes, aggregated, seenNoteIds);

    addNotes(_filterNotesFromMemoryCache(
      noteId: noteId,
      groupId: groupId,
      authors: authors,
      root: root,
      reply: reply,
      repostId: repostId,
      quoteRepostId: quoteRepostId,
      reactedId: reactedId,
      isReacted: isReacted,
      private: private,
      until: until,
      keyword: keyword,
    ));

    addNotes(searchNotesFromCache(noteId, groupId, authors, root, reply, repostId,
        quoteRepostId, reactedId, isReacted, private, until, limit));

    final isar = DBISAR.sharedInstance.isar;
    if (!isar.isOpen) {
      return _finalizeNoteResults(aggregated, limit);
    }
    
    try {
      dynamic queryBuilder = isar.noteDBISARs.where();
      if (queryBuilder == null) {
        return _finalizeNoteResults(aggregated, limit);
      }
      
      if (noteId != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .noteIdEqualTo(noteId);
      }
      
      if (groupId != null && groupId.isNotEmpty) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .groupIdEqualTo(groupId);
      } else if (groupId == null || groupId.isEmpty) {
        if (noteId == null) {
          queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
              .groupIdIsEmpty();
        }
      }
      
      if (authors != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .anyOf(authors, (q, author) => q.authorEqualTo(author));
      }
      
      if (root != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .rootEqualTo(root);
      }
      
      if (reply != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .replyEqualTo(reply);
      }
      
      if (repostId != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .repostIdEqualTo(repostId);
      }
      
      if (quoteRepostId != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .quoteRepostIdEqualTo(quoteRepostId);
      }
      
      if (reactedId != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .reactedIdEqualTo(reactedId);
      }
      
      if (until != null) {
        queryBuilder = (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>)
            .createAtLessThan(until);
      }
      
      if (isReacted != null) {
        queryBuilder = isReacted ? queryBuilder.reactedIdIsNotEmpty() : queryBuilder.reactedIdIsEmpty();
        if (isWeb && queryBuilder == null) {
          return _finalizeNoteResults(aggregated, limit);
        }
      }
      
      if (private != null) {
        queryBuilder = queryBuilder.privateEqualTo(private);
        if (isWeb && queryBuilder == null) {
          return _finalizeNoteResults(aggregated, limit);
        }
      }
      
      if (keyword != null) {
        queryBuilder = queryBuilder.contentContains(keyword);
      }
      
      var allNotes = await (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QOperations>).findAll();
      final isarNotes = List<NoteDBISAR>.from(allNotes);
      if (isWeb) {
        _logIsarResults('searchNotesFromDB', isarNotes);
      }
      addNotes(isarNotes);
      return _finalizeNoteResults(aggregated, limit);
    } catch (e) {
      if (!isWeb) {
        print('Error in searchNotesFromDB: $e');
      }
      return _finalizeNoteResults(aggregated, limit);
    }
  }

  /// Load notes from all groups that the current user has joined
  /// Similar to searchNotesFromDB but queries multiple groupIds using anyOf
  Future<List<NoteDBISAR>> loadAllMyGroupsNotesFromDB({
    List<String>? authors,
    String? root,
    String? reply,
    String? repostId,
    String? quoteRepostId,
    String? reactedId,
    bool? isReacted,
    bool? private,
    int? until,
    int? limit,
    String? keyword,
  }) async {
    // Get all group IDs that the current user has joined
    List<String> myGroupIds = RelayGroup.sharedInstance.myGroups.keys.toList();

    final bool isWeb = kIsWeb;
    final List<NoteDBISAR> aggregated = [];
    final Set<String> seenNoteIds = {};

    void addNotes(List<NoteDBISAR> notes) => _addUniqueNotes(notes, aggregated, seenNoteIds);

    addNotes(_filterNotesFromMemoryCache(
      groupIds: myGroupIds,
      authors: authors,
      root: root,
      reply: reply,
      repostId: repostId,
      quoteRepostId: quoteRepostId,
      reactedId: reactedId,
      isReacted: isReacted,
      private: private,
      until: until,
      keyword: keyword,
    ));

    // Web platform uses IndexedDB, mobile platform uses Isar
    if (isWeb) {
      try {
        // Web platform: use IndexedDB query
        final indexedDB = DBISAR.sharedInstance.indexedDB;
        if (indexedDB == null || !indexedDB.isOpen) {
          return _finalizeNoteResults(aggregated, limit);
        }
        
        final collection = indexedDB.getCollection<NoteDBISAR>('noteDBISARs');
        final query = collection.where();
        
        // Apply groupId filter (anyOf needs manual implementation in IndexedDB)
        // First get all notes, then filter in memory
        List<NoteDBISAR> allNotes = await query.findAll();
        
        // Filter in memory: only keep notes whose groupId is in myGroupIds
        if (myGroupIds.isNotEmpty) {
          allNotes = allNotes.where((note) => myGroupIds.contains(note.groupId)).toList();
        }
        
        // Apply other filter conditions
        if (authors != null && authors.isNotEmpty) {
          allNotes = allNotes.where((note) => authors.contains(note.author)).toList();
        }
        if (root != null && root.isNotEmpty) {
          allNotes = allNotes.where((note) => note.root == root).toList();
        }
        if (reply != null) {
          allNotes = allNotes.where((note) => note.reply == reply).toList();
        }
        if (repostId != null) {
          allNotes = allNotes.where((note) => note.repostId == repostId).toList();
        }
        if (quoteRepostId != null) {
          allNotes = allNotes.where((note) => note.quoteRepostId == quoteRepostId).toList();
        }
        if (reactedId != null) {
          allNotes = allNotes.where((note) => note.reactedId == reactedId).toList();
        }
        if (until != null) {
          allNotes = allNotes.where((note) => note.createAt < until).toList();
        }
        if (isReacted != null) {
          if (isReacted) {
            allNotes = allNotes.where((note) => note.reactedId != null && note.reactedId!.isNotEmpty).toList();
          } else {
            allNotes = allNotes.where((note) => note.reactedId == null || note.reactedId!.isEmpty).toList();
          }
        }
        if (private != null) {
          allNotes = allNotes.where((note) => note.private == private).toList();
        }
        if (keyword != null && keyword.isNotEmpty) {
          allNotes = allNotes.where((note) => 
            note.content.toLowerCase().contains(keyword.toLowerCase())
          ).toList();
        }
        
        // Sort by createAt in descending order
        allNotes.sort((a, b) => b.createAt.compareTo(a.createAt));
        
        // Apply limit
        if (limit != null && limit > 0) {
          allNotes = allNotes.take(limit).toList();
        }
        
        addNotes(allNotes);
        return _finalizeNoteResults(aggregated, limit);
      } catch (e) {
        debugPrint('[DB-Web] Error loading notes: $e');
        return _finalizeNoteResults(aggregated, limit);
      }
    }
    
    // Mobile platform: use Isar
    final isar = DBISAR.sharedInstance.isar;
    if (!isar.isOpen) {
      return _finalizeNoteResults(aggregated, limit);
    }
    
    try {
      var queryBuilder = isar.noteDBISARs.where() as QueryBuilder<NoteDBISAR, NoteDBISAR, QFilterCondition>;
      
      queryBuilder = queryBuilder
          .anyOf(myGroupIds, (q, groupId) => q.groupIdEqualTo(groupId));
      
      if (authors != null) {
        queryBuilder = queryBuilder
            .anyOf(authors, (q, author) => q.authorEqualTo(author));
      }
      if (root != null) {
        queryBuilder = queryBuilder.rootEqualTo(root);
      }
      if (reply != null) {
        queryBuilder = queryBuilder.replyEqualTo(reply);
      }
      if (repostId != null) {
        queryBuilder = queryBuilder.repostIdEqualTo(repostId);
      }
      if (quoteRepostId != null) {
        queryBuilder = queryBuilder.quoteRepostIdEqualTo(quoteRepostId);
      }
      if (reactedId != null) {
        queryBuilder = queryBuilder.reactedIdEqualTo(reactedId);
      }
      if (until != null) {
        queryBuilder = queryBuilder.createAtLessThan(until);
      }
      if (isReacted != null) {
        queryBuilder = isReacted ? queryBuilder.reactedIdIsNotEmpty() : queryBuilder.reactedIdIsEmpty();
      }
      if (private != null) {
        queryBuilder = queryBuilder.privateEqualTo(private);
      }
      if (keyword != null) {
        queryBuilder = queryBuilder.contentContains(keyword);
      }
      
      var allNotes = await (queryBuilder as QueryBuilder<NoteDBISAR, NoteDBISAR, QOperations>).findAll();
      final isarNotes = List<NoteDBISAR>.from(allNotes);
      if (isWeb) {
        _logIsarResults('loadAllMyGroupsNotesFromDB', isarNotes);
      }
      addNotes(isarNotes);
      return _finalizeNoteResults(aggregated, limit);
    } catch (e) {
      if (!isWeb) {
        print('Error in loadAllMyGroupsNotesFromDB: $e');
      }
      return _finalizeNoteResults(aggregated, limit);
    }
  }

  Future<void> handleNewNotes(NoteDBISAR noteDB) async {
    await saveNoteToDB(noteDB, ConflictAlgorithm.ignore);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[Feed] handleNewNotes cached noteId=${noteDB.noteId} groupId=${noteDB.groupId}');
    }
    LogUtils.d(() => '[DB-Web] handleNewNotes: noteId=${noteDB.noteId}, createAt=${noteDB.createAt}, latestNoteTime=$latestNoteTime');
    if (noteDB.createAt > latestNoteTime) {
      newNotes.add(noteDB);
      LogUtils.d(() => '[DB-Web] handleNewNotes: Added to newNotes, count=${newNotes.length}, callback=${newNotesCallBack != null}');
      newNotesCallBack?.call(newNotes);
    } else {
      LogUtils.d(() => '[DB-Web] handleNewNotes: Note createAt (${noteDB.createAt}) <= latestNoteTime ($latestNoteTime), not adding');
    }
    // Check if this note mentions the current user (notification condition)
    bool hasPTag = noteDB.pTags?.contains(pubkey) == true;
    if (hasPTag) {
      NotificationDBISAR notificationDB = NotificationDBISAR.notificationDBFromNoteDB(noteDB);
      await saveNotificationToDB(notificationDB);
      if (notificationDB.author != pubkey && notificationDB.createAt > latestNotificationTime) {
        newNotifications.add(notificationDB);
        newNotificationCallBack?.call(newNotifications);
      }
    }
  }

  Future<void> handleNoteEvent(Event event, String relay, bool private) async {
    Note note = Nip1.decodeNote(event);
    NoteDBISAR noteDB = NoteDBISAR.noteDBFromNote(note);
    noteDB.private = private;
    // reply
    if (noteDB.getNoteKind() == 1) {
      await addReplyToNote(event, noteDB.reply ?? noteDB.root!);
    }
    // quote repost
    else if (noteDB.getNoteKind() == 2) {
      await addQuoteRepostToNote(event, noteDB.quoteRepostId!);
    }
    handleNewNotes(noteDB);
  }

  Future<void> handleRepostsEvent(Event event, String relay, bool private) async {
    Reposts repost = await Nip18.decodeReposts(event);
    // save repost event to DB
    if (repost.repostNote != null) {
      NoteDBISAR repostNoteDB = NoteDBISAR.noteDBFromNote(repost.repostNote!);
      saveNoteToDB(repostNoteDB, ConflictAlgorithm.ignore);
    }

    NoteDBISAR noteDB = NoteDBISAR.noteDBFromReposts(repost);
    noteDB.private = private;
    await addRepostToNote(event, noteDB.repostId!);
    handleNewNotes(noteDB);
  }

  Future<void> handleReactionEvent(Event event, String relay, bool private) async {
    Reactions reactions = Nip25.decode(event);
    NoteDBISAR reactionsNoteDB = NoteDBISAR.noteDBFromReactions(reactions);
    reactionsNoteDB.private = private;
    final reactedMessageDB =
    await Messages.sharedInstance.loadMessageDBFromDB(reactions.reactedEventId);
    if (reactedMessageDB != null) {
      await Messages.sharedInstance.handleReactionEvent(event);
    } else {
      NoteDBISAR? noteDB = await loadNoteWithNoteId(reactionsNoteDB.reactedId!);
      if (noteDB != null) {
        await addReactionToNote(event, reactionsNoteDB.reactedId!);
        handleNewNotes(reactionsNoteDB);
      }
    }
  }

  Future<List<NoteDBISAR>> searchNotesWithKeyword(String keyword) async {
    var notesFromDB = await searchNotesFromDB(keyword: keyword);
    var notesFromRelay = await _searchNotesFromRelay(keyword);
    var result = [...notesFromDB, ...notesFromRelay];
    result.sort((a, b) => a.createAt.compareTo(b.createAt));
    return result;
  }

  Future<List<NoteDBISAR>> _searchNotesFromRelay(String keyword) async {

    return [];
  }
}
