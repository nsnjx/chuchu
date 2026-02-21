import 'dart:async';

import 'package:chuchu/core/feed/feed+load.dart';
import 'package:chuchu/core/relayGroups/relayGroup.dart';
import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../feed/feed.dart';
import '../feed/model/noteDB_isar.dart';
import '../network/connect.dart';
import 'package:nostr_core_dart/src/event.dart';
import 'package:nostr_core_dart/src/filter.dart';
import 'package:nostr_core_dart/src/nips/nip_018.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import 'package:nostr_core_dart/src/nips/nip_021.dart';
import 'package:nostr_core_dart/src/nips/nip_025.dart';
import 'package:nostr_core_dart/src/nips/nip_029.dart';
import 'package:nostr_core_dart/src/ok.dart';
import 'package:nostr_core_dart/src/utils.dart';
import 'model/relayGroupDB_isar.dart';

extension ENote on RelayGroup {
  Future<void> handleGroupNotes(Event event, String relay) async {
    GroupNote groupNote = Nip29.decodeGroupNote(event);
    NoteDBISAR noteDB = NoteDBISAR.noteDBFromNote(groupNote.note);
    noteDB.groupId = groupNote.groupId;
    // reply
    if (noteDB.getNoteKind() == 1) {
      await Feed.sharedInstance.addReplyToNote(event, noteDB.reply ?? noteDB.root!);
    }
    // quote repost
    else if (noteDB.getNoteKind() == 2) {
      await Feed.sharedInstance.addQuoteRepostToNote(event, noteDB.quoteRepostId!);
    }
    noteCallBack?.call(noteDB);
    Feed.sharedInstance.handleNewNotes(noteDB);
  }

  Future<OKEvent> sendGroupNotes(String groupId, String content, List<String> previous,
      {String? rootEvent,
      String? replyEvent,
      List<String>? mentions,
      List<String>? hashTags}) async {
    RelayGroupDBISAR? groupDB = myGroups[groupId]?.value;
    if (groupDB == null) return OKEvent(groupId, false, 'group not exit');
    Completer<OKEvent> completer = Completer<OKEvent>();
    Event event;
    List<String> previous = await getPrevious(groupId);
    if (rootEvent == null) {
      event = await Nip29.encodeGroupNote(groupId, content, pubkey, privkey, previous);
    } else {
      event = await Nip29.encodeGroupNoteReply(groupId, content, pubkey, privkey, previous,
          rootEvent: rootEvent, replyEvent: replyEvent, replyUsers: mentions, hashTags: hashTags);
    }
    handleGroupNotes(event, groupDB.relay);
    Connect.sharedInstance.sendEvent(event, toRelays: [groupDB.relay],
        sendCallBack: (ok, relay) async {
      if (!completer.isCompleted) completer.complete(ok);
    });
    return completer.future;
  }

  Future<OKEvent> sendGroupNoteReply(String replyNoteId, String content, List<String> previous,
      {List<String>? hashTags, List<String>? mentions}) async {
    NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(replyNoteId);
    if (note == null) {
      return OKEvent(replyNoteId, false, 'reacted note DB == null');
    }
    String groupId = note.groupId;
    if (groupId.isEmpty) {
      return OKEvent(replyNoteId, false, 'group not exit');
    }
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    if (groupDB == null) {
      return OKEvent(replyNoteId, false, 'group not exit');
    }

    String? rootEventId = note.root;
    note.pTags ??= [];
    late OKEvent okEvent;
    if (rootEventId == null || rootEventId.isEmpty) {
      if (!note.pTags!.contains(note.author)) {
        note.pTags!.add(note.author);
      }
      for (var mention in mentions ?? []) {
        if (!note.pTags!.contains(mention)) {
          note.pTags!.add(mention);
        }
      }
      okEvent = await sendGroupNotes(note.groupId, content, previous,
          rootEvent: replyNoteId, mentions: note.pTags, hashTags: hashTags);
    } else {
      NoteDBISAR? rootNote = await Feed.sharedInstance.loadNoteWithNoteId(rootEventId);
      if (rootNote?.author.isNotEmpty == true && !note.pTags!.contains(rootNote?.author)) {
        note.pTags!.add(rootNote!.author);
      }
      if (!note.pTags!.contains(note.author)) {
        note.pTags!.add(note.author);
      }
      okEvent = await sendGroupNotes(note.groupId, content, previous,
          rootEvent: rootEventId,
          mentions: note.pTags,
          replyEvent: replyNoteId,
          hashTags: hashTags);
    }
    return okEvent;
  }

  Future<OKEvent> sendGroupNoteReaction(String reactedNoteId,
      {bool like = true, String? content, String? emojiShotCode, String? emojiURL}) async {
    NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(reactedNoteId);
    if (note == null) {
      return OKEvent(reactedNoteId, false, 'reacted note DB == null');
    }
    String groupId = note.groupId;
    if (groupId.isEmpty) {
      return OKEvent(reactedNoteId, false, 'group not exit');
    }
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    if (groupDB == null) {
      return OKEvent(reactedNoteId, false, 'group not exit');
    }

    Completer<OKEvent> completer = Completer<OKEvent>();
    if (!note.pTags!.contains(note.author)) {
      note.pTags!.add(note.author);
    }
    Event event = await Nip25.encode(reactedNoteId, note.pTags ?? [], '1', like, pubkey, privkey,
        content: content, emojiShotCode: emojiShotCode, emojiURL: emojiURL, relayGroupId: groupId);

    Connect.sharedInstance.sendEvent(event, toRelays: [groupDB.relay],
        sendCallBack: (ok, relay) async {
      if (ok.status) {
        NoteDBISAR noteDB = NoteDBISAR.noteDBFromReactions(Nip25.decode(event));
        noteDB.groupId = groupId;
        Feed.sharedInstance.saveNoteToDB(noteDB, null);

        note.reactionEventIds ??= [];
        if (!note.reactionEventIds!.contains(event.id)) {
          note.reactionEventIds!.add(event.id);
          note.reactionCount++;
          note.reactionCountByMe++;
          Feed.sharedInstance.saveNoteToDB(note, null);
        }
      }
      if (!completer.isCompleted) completer.complete(ok);
    });
    return completer.future;
  }

  Future<OKEvent> sendRepost(String repostNoteId, String? repostNoteRelay) async {
    NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(repostNoteId);
    if (note == null) {
      return OKEvent(repostNoteId, false, 'reacted note DB == null');
    }
    String groupId = note.groupId;
    if (groupId.isEmpty) {
      return OKEvent(repostNoteId, false, 'group not exit');
    }
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    if (groupDB == null) {
      return OKEvent(repostNoteId, false, 'group not exit');
    }

    Completer<OKEvent> completer = Completer<OKEvent>();
    if (!note.pTags!.contains(note.author)) {
      note.pTags!.add(note.author);
    }
    Event event = await Nip18.encodeReposts(
        repostNoteId, repostNoteRelay, note.pTags ?? [], note.rawEvent, pubkey, privkey,
        relayGroupId: groupId);

    Reposts r = await Nip18.decodeReposts(event);
    NoteDBISAR noteDB = NoteDBISAR.noteDBFromReposts(r);
    noteDB.groupId = groupId;
    await Feed.sharedInstance.saveNoteToDB(noteDB, null);

    note.repostEventIds ??= [];
    note.repostEventIds!.add(event.id);
    note.repostCount++;
    note.repostCountByMe++;
    Feed.sharedInstance.saveNoteToDB(note, null);

    Connect.sharedInstance.sendEvent(event, toRelays: [groupDB.relay],
        sendCallBack: (ok, relay) async {
      if (!completer.isCompleted) completer.complete(ok);
    });

    return completer.future;
  }

  Future<OKEvent> sendQuoteRepost(String quoteRepostNoteId, String content,
      {List<String>? hashTags, List<String>? mentions}) async {
    NoteDBISAR? note = await Feed.sharedInstance.loadNoteWithNoteId(quoteRepostNoteId);
    if (note == null) {
      return OKEvent(quoteRepostNoteId, false, 'reacted note DB == null');
    }
    String groupId = note.groupId;
    if (groupId.isEmpty) {
      return OKEvent(quoteRepostNoteId, false, 'group not exit');
    }
    RelayGroupDBISAR? groupDB = groups[groupId]?.value;
    if (groupDB == null) {
      return OKEvent(quoteRepostNoteId, false, 'group not exit');
    }

    Completer<OKEvent> completer = Completer<OKEvent>();
    if (!note.pTags!.contains(note.author)) {
      note.pTags!.add(note.author);
    }
    String nostrNote = Nip21.encode(Nip19.encodeNote(quoteRepostNoteId));
    content = '$content\n$nostrNote';
    Event event = await Nip18.encodeQuoteReposts(
        quoteRepostNoteId, note.pTags ?? [], content, hashTags, pubkey, privkey,
        relayGroupId: groupId);
    for (var mention in mentions ?? []) {
      if (!note.pTags!.contains(mention)) {
        note.pTags!.add(mention);
      }
    }
    NoteDBISAR noteDB = NoteDBISAR.noteDBFromQuoteReposts(Nip18.decodeQuoteReposts(event));
    noteDB.groupId = groupId;
    await Feed.sharedInstance.saveNoteToDB(noteDB, null);

    note.quoteRepostEventIds ??= [];
    note.quoteRepostEventIds!.add(event.id);
    note.quoteRepostCount++;
    note.quoteRepostCountByMe++;
    Feed.sharedInstance.saveNoteToDB(note, null);

    Connect.sharedInstance.sendEvent(event, toRelays: [groupDB.relay],
        sendCallBack: (ok, relay) async {
      if (!completer.isCompleted) completer.complete(ok);
    });

    return completer.future;
  }

  Future<List<NoteDBISAR>?> loadGroupNotesFromDB(String id, {int limit = 50, int? until}) async {
    until ??= currentUnixTimestampSeconds() + 1;
    List<NoteDBISAR>? notes =
        await Feed.sharedInstance.searchNotesFromDB(groupId: id, until: until, limit: limit);
    for (var note in notes) {
      Feed.sharedInstance.notesCache[note.noteId] = note;
    }
    return notes;
  }

  Future<void> fetchGroupNotesFromRelays(RelayGroupDBISAR group,
      {int limit = 50, int? until}) async {
    // Fetch notes only from recommendGroupRelays (e.g. wss://relay.chuchu.app)
    final relayUrl = Config.sharedInstance.recommendGroupRelays.isNotEmpty
        ? Config.sharedInstance.recommendGroupRelayOrDefault
        : group.relay.isNotEmpty
            ? group.relay
            : Config.sharedInstance.wssHost;
    final filter = Filter(
      h: [group.groupId],
      kinds: const [
        11,
        12,
      ],
      limit: limit,
      until: until,
    );

    final completer = Completer<void>();
    try {
      Connect.sharedInstance.addSubscription([filter], relays: [relayUrl],
          eventCallBack: (event, relay) async {
        await handleGroupNotes(event, relay);
      }, eoseCallBack: (requestId, ok, relay, unCompletedRelays) async {
        if (unCompletedRelays.isEmpty && !completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 8), onTimeout: () {
        if (!completer.isCompleted) {
          if (kDebugMode) {
            print('fetchGroupNotesFromRelays timeout for group ${group.groupId}');
          }
          completer.complete();
        }
        return;
      });
    } catch (e) {
      if (kDebugMode) {
        print('fetchGroupNotesFromRelays error: $e');
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<List<NoteDBISAR>?> loadAllMyGroupsNotesFromDB({int limit = 50, int? until}) async {
    try {
      List<NoteDBISAR>? notes =
          await Feed.sharedInstance.loadAllMyGroupsNotesFromDB(until: until, limit: limit);
      for (var note in notes) {
        Feed.sharedInstance.notesCache[note.noteId] = note;
      }
      return notes;
    } catch (e) {
      debugPrint('[RelayGroup] Error loading notes: $e');
      rethrow;
    }
  }
}
