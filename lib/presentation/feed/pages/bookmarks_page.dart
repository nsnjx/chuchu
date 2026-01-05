import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/feed/model/noteDB_isar.dart';
import '../../../core/feed/feed.dart';
import '../../../core/feed/feed+load.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/widgets/chuchu_smart_refresher.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/noted_ui_model.dart';
import '../widgets/feed_widget.dart';
import 'feed_info_page.dart';

class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> with ChuChuUIRefreshMixin {
  final RefreshController _refreshController = RefreshController();
  List<NotedUIModel?> _bookmarkedNotes = [];
  bool _isLoading = true;
  static const String _bookmarksKey = 'bookmarked_note_ids';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }


  Future<void> _loadBookmarks() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final noteIds = prefs.getStringList(_bookmarksKey) ?? [];
      
      await _loadNotesFromDB(noteIds);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadNotesFromDB(List<String> noteIds) async {
    if (noteIds.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _bookmarkedNotes = [];
        });
      }
      return;
    }

    try {
      final notes = <NoteDBISAR>[];
      
      for (var i = 0; i < noteIds.length; i++) {
        final noteId = noteIds[i];
        
        NoteDBISAR? note = await Feed.sharedInstance.loadNoteFromDBWithNoteId(noteId);
        
        if (note == null) {
          note = await Feed.sharedInstance.loadNoteWithNoteId(
            noteId,
            private: false,
            reload: true,
            relays: null,
          );
        }
        
        if (note != null) {
          notes.add(note);
        }
      }

      notes.sort((a, b) => b.createAt.compareTo(a.createAt));

      final notedUIModels = notes.map((note) {
        return NotedUIModel(noteDB: note);
      }).toList();

      if (mounted) {
        setState(() {
          _bookmarkedNotes = notedUIModels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: CommonImage(
              iconName: 'back_arrow_icon.png',
              size: 24,
              color: kTitleColor,
            ),
          ),
        ),
        title: Text(
          'Bookmarks',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: theme.colorScheme.primary),
              )
            : ChuChuSmartRefresher(
                controller: _refreshController,
                enablePullDown: true,
                enablePullUp: false,
                onRefresh: () async {
                  await _loadBookmarks();
                  _refreshController.refreshCompleted();
                },
                child: _buildContent(),
              ),
      ),
    );
  }

  Widget _buildContent() {
    if (_bookmarkedNotes.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _bookmarkedNotes.length,
      itemBuilder: (context, index) {
        final note = _bookmarkedNotes[index];
        if (note == null) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: FeedWidget(
            key: ValueKey(note.noteDB.noteId),
            isShowReplyWidget: true,
            feedWidgetLayout: EFeedWidgetLayout.fullScreen,
            notedUIModel: note,
            clickMomentCallback: (m) => ChuChuNavigator.pushPage(
              context,
              (_) => FeedInfoPage(notedUIModel: m),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          const SizedBox(
            height: 100,
          ),
          CommonImage(iconName: 'no_list_ill.png', width: 187),
          const SizedBox(height: 20),
          Text(
            'No Bookmarks',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark posts you want to save\nand view them later',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

