import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkManager {
  static final BookmarkManager _instance = BookmarkManager._internal();
  factory BookmarkManager() => _instance;
  BookmarkManager._internal();

  static BookmarkManager get sharedInstance => _instance;

  static const String _bookmarksKey = 'bookmarked_note_ids';
  
  final ValueNotifier<List<String>> _bookmarkedNoteIds = ValueNotifier<List<String>>([]);
  
  ValueNotifier<List<String>> get bookmarkedNoteIds => _bookmarkedNoteIds;
  
  List<String> get currentBookmarkedIds => _bookmarkedNoteIds.value;

  bool isBookmarked(String noteId) {
    return _bookmarkedNoteIds.value.contains(noteId);
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final noteIds = prefs.getStringList(_bookmarksKey) ?? [];
      _bookmarkedNoteIds.value = noteIds;
    } catch (e) {
      _bookmarkedNoteIds.value = [];
    }
  }

  Future<void> addBookmark(String noteId) async {
    if (noteId.isEmpty || isBookmarked(noteId)) return;

    final updatedList = List<String>.from(_bookmarkedNoteIds.value);
    updatedList.add(noteId);
    _bookmarkedNoteIds.value = updatedList;

    await _saveToStorage(updatedList);
  }

  Future<void> removeBookmark(String noteId) async {
    if (noteId.isEmpty || !isBookmarked(noteId)) return;

    final updatedList = List<String>.from(_bookmarkedNoteIds.value);
    updatedList.remove(noteId);
    _bookmarkedNoteIds.value = updatedList;

    await _saveToStorage(updatedList);
  }

  Future<void> toggleBookmark(String noteId) async {
    if (isBookmarked(noteId)) {
      await removeBookmark(noteId);
    } else {
      await addBookmark(noteId);
    }
  }

  Future<void> _saveToStorage(List<String> noteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarksKey, noteIds);
    } catch (e) {
      // Silent fail
    }
  }
}

