import 'dart:async';
import 'dart:math';

import 'package:chuchu/core/account/model/userDB_isar.dart';
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:chuchu/data/models/feed_extension_model.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import '../../../core/account/account.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import '../../../core/feed/model/notificationDB_isar.dart';
import '../../../core/manager/chuchu_feed_manager.dart';
import '../../../core/manager/chuchu_user_info_manager.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/chuchu_smart_refresher.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../../core/utils/ui_refresh_mixin.dart';

import '../../search/pages/search_page.dart';
import '../../home/pages/home_page.dart';
import '../../home/widgets/drawer_menu.dart';
import '../widgets/feed_widget.dart';
import '../widgets/feed_skeleton_widget.dart';
import 'feed_info_page.dart';
import 'feed_personal_page.dart';

class FeedPage extends StatefulWidget {
  final ScrollController? scrollController;

  const FeedPage({super.key, this.scrollController});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage>
    with
        SingleTickerProviderStateMixin,
        ChuChuUserInfoObserver,
        ChuChuFeedObserver,
        ChuChuUIRefreshMixin {
  List<NotedUIModel?> notesList = [];
  int _listVersion = 0; // Track list changes to force ListView refresh
  final int _limit = 1000;
  int? _allNotesFromDBLastTimestamp;

  final ScrollController feedScrollController = ScrollController();
  final RefreshController refreshController = RefreshController();
  final ScrollController storiesScrollController = ScrollController();

  final Map<String,List<NoteDBISAR>> _notificationGroupNotes = {};

  bool _isInitialLoading = true;
  Map<String, ValueNotifier<RelayGroupDBISAR>> myGroupsList = {};

  ThemeData? _cachedTheme;

  // Track processed note ids to prevent duplicate handling across callbacks
  final Set<String> _seenNoteIds = <String>{};

  double avatarSize = 56;
  double storyItemWidth = 70;
  static const double _textLineHeight = 16.0;
  static const double _itemGap = 6.0;
  static const double _topPadding = 0.0;
  static const double _bottomPadding = 14.0;
  static const double _borderWidth = 0.5;

  // Dynamic height calculation: avatar + gap + text + topPadding + bottomPadding + border
  double get kStoriesSectionHeight => avatarSize + _itemGap + _textLineHeight + _topPadding + _bottomPadding + _borderWidth;
  bool _isStoriesVisible = true;
  double get _storiesHeight => kStoriesSectionHeight;

  // Track if notes have been initialized to prevent duplicate loading
  bool _hasInitializedNotes = false;
  // Listen to RelayGroup ready signal
  VoidCallback? _relayReadyListener;
  Timer? _scrollProcessingTimer;

  @override
  void initState() {
    super.initState();
    ChuChuUserInfoManager.sharedInstance.addObserver(this);
    ChuChuFeedManager.sharedInstance.addObserver(this);
    
    // Listen for group updates
    // Save original callback and chain it
    final originalCallback = RelayGroup.sharedInstance.myGroupsUpdatedCallBack;
    RelayGroup.sharedInstance.myGroupsUpdatedCallBack = () {
      originalCallback?.call();
      _loadSubscriptionList();
      // Load notes when myGroups is updated for the first time
      _tryInitializeNotes();
    };

    // Listen to RelayGroup ready state
    _relayReadyListener = () {
      if (RelayGroup.sharedInstance.isReady.value) {
        _tryInitializeNotes();
      }
    };
    RelayGroup.sharedInstance.isReady.addListener(_relayReadyListener!);
    
    _initData();
    _setupScrollListener();
  }

  void _initData() {
    _resetStoriesSection();
    _loadSubscriptionList();
    // Attempt initialization immediately; guarded inside to avoid duplicate work
    _tryInitializeNotes();
  }

  /// Try to initialize notes when myGroups is ready
  /// This ensures we wait for myGroups to be populated before loading notes
  /// The callback is called after _loadAllGroupsFromDB completes, indicating initialization is done
  void _tryInitializeNotes() {
    if (_hasInitializedNotes || !mounted) {
      return;
    }
    
    // Check if RelayGroup has been initialized
    // myGroupsUpdatedCallBack is called after _loadAllGroupsFromDB completes,
    // which means initialization is done (even if myGroups is empty)
    final hasUserInfo = Account.sharedInstance.me != null;
    
    if (!hasUserInfo) return;

    _hasInitializedNotes = true;
    // Use postFrameCallback to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        updateNotesList(true);
      }
    });
  }

  void _loadSubscriptionList() {
    myGroupsList = RelayGroup.sharedInstance.myGroups;
    _sortMyGroupsList();
    if(mounted){
      setState(() {});
    }
  }

  void _sortMyGroupsList() {
    final currentPubkey = Account.sharedInstance.currentPubkey;
    
    // Convert to list for sorting
    final groupsList = myGroupsList.entries.toList();
    
    // Sort the list
    groupsList.sort((a, b) {
      final groupA = a.value.value;
      final groupB = b.value.value;
      
      // Current user's group always comes first
      if (groupA.groupId == currentPubkey) return -1;
      if (groupB.groupId == currentPubkey) return 1;
      
      // Get notification counts
      final countA = _notificationGroupNotes[groupA.groupId]?.length ?? 0;
      final countB = _notificationGroupNotes[groupB.groupId]?.length ?? 0;
      
      // Sort by notification count (descending)
      return countB.compareTo(countA);
    });
    
    // Rebuild the map with sorted order
    final sortedMap = <String, ValueNotifier<RelayGroupDBISAR>>{};
    for (final entry in groupsList) {
      sortedMap[entry.key] = entry.value;
    }
    
    myGroupsList = sortedMap;
    
    // Scroll to the beginning (leftmost position) after sorting
    _scrollToBeginning();
  }

  void _scrollToBeginning() {
    if (storiesScrollController.hasClients) {
      storiesScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _setupScrollListener() {
    final scrollController = widget.scrollController ?? feedScrollController;
    scrollController.addListener(_onScroll);
  }

  bool _isScrollProcessing = false;

  void _onScroll() {
    if (!mounted || _isScrollProcessing) return;
    
    // On Web platform, keep stories section always visible
    if (kIsWeb) return;

    _isScrollProcessing = true;

    final scrollController = widget.scrollController ?? feedScrollController;
    final scrollOffset = scrollController.offset;
    final threshold = 50.0;

    if (scrollOffset > threshold && _isStoriesVisible) {
      setState(() {
        _isStoriesVisible = false;
      });
    } else if (scrollOffset <= threshold && !_isStoriesVisible) {
      setState(() {
        _isStoriesVisible = true;
      });
    }

    _scrollProcessingTimer?.cancel();
    _scrollProcessingTimer = Timer(Duration(milliseconds: 100), () {
      _isScrollProcessing = false;
    });
  }

  void _resetData() {
    notesList = [];
    myGroupsList = {};
    _allNotesFromDBLastTimestamp = null;
    _seenNoteIds.clear();
    _hasInitializedNotes = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _resetStoriesSection() {
    if (mounted) {
      setState(() {
        _isStoriesVisible = true;
      });
    }
  }


  void _clearAvatarBorders() {
    if (mounted) {
      setState(() {
      });
    }
  }

  void _setInitialLoadingFalse() {
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  void _handleNewNotesAfterNavigation(RelayGroupDBISAR relayGroupDB, bool hasNewNotes) {
    if (mounted) {
      // Mark current group's notifications as seen to prevent reappearing
      final cleared = _notificationGroupNotes[relayGroupDB.groupId] ?? [];
      for (final note in cleared) {
        _seenNoteIds.add(note.noteId);
      }
      _notificationGroupNotes[relayGroupDB.groupId] = [];
      // Re-sort the groups list after clearing notifications
      _sortMyGroupsList();
      setState(() {});
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    _cachedTheme ??= Theme.of(context);

    return Container(
      color: kBgLight,
      child: SafeArea(
        child: Column(
          children: [
            _buildTopStoriesSection(),
            Expanded(
              child: ChuChuSmartRefresher(
                scrollController: widget.scrollController ?? feedScrollController,
                controller: refreshController,
                enablePullDown: true,
                enablePullUp: true,
                onRefresh: () => updateNotesList(true),
                onLoading: () => updateNotesList(false),
                child: _getFeedListWidget(),
              ),
            ),
          ],
        ).setPaddingOnly(bottom: 100.0),
      ),
    );
  }

  Widget _getFeedListWidget() {
    if (_isInitialLoading) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (context, index) =>
            RepaintBoundary(child: const FeedSkeletonWidget()),
      );
    }

    if (notesList.isEmpty) {
      final theme = Theme.of(context);
      final content = Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          CommonImage(iconName: 'no_list_ill.png', width: 150),
          const SizedBox(height: 24),
          Text(
            'No Content Yet',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 20 : 40),
            child: Text(
              'Subscribe to your favorite creators to see their exclusive content and updates.',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kIsWeb ? 0 : 20),
            child: SizedBox(
              width: kIsWeb ? null : double.infinity,
              height: 48,
                child: GestureDetector(
                onTap: () {
                  // On web, switch to search page in content area instead of pushing
                  if (kIsWeb) {
                    // Find HomePage state and switch to search page
                    final homeState = context.findAncestorStateOfType<HomePageState>();
                    if (homeState != null) {
                      homeState.switchToWebPage(WebContentPage.search);
                    } else {
                      // Fallback: try to find nested Navigator
                      final navigator = Navigator.of(context, rootNavigator: false);
                      navigator.push(
                        MaterialPageRoute(
                          builder: (context) => SearchPage(),
                        ),
                      );
                    }
                  } else {
                    ChuChuNavigator.pushPage(context, (context) => SearchPage());
                  }
                },
                child: Container(
                  width: kIsWeb ? 280 : double.infinity,
                  decoration: BoxDecoration(
                    gradient: getBrandGradientHorizontal(),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CommonImage(
                        iconName: 'start_ill_icon.png',
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Discover Creators',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );

      if (kIsWeb) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: content,
          ),
        );
      }
      return content;
    }

    return ListView.builder(
      key: ValueKey('feed_list_$_listVersion'), // Force refresh when list changes
      primary: false,
      controller: null,
      shrinkWrap: false,
      itemCount: notesList.length,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final notedUIModel = notesList[index];
        // Use noteId as key to prevent widget reuse issues
        // This ensures widgets are correctly identified when list order changes
        // If notedUIModel is null, create a unique key based on index and list state
        final key = notedUIModel?.noteDB.noteId ?? 
            'null_note_${Object.hash(notedUIModel, index)}';
        return FeedWidget(
          key: ValueKey(key),
          horizontalPadding: 16,
          feedWidgetLayout: EFeedWidgetLayout.halfScreen,
          isShowReplyWidget: true,
          notedUIModel: notedUIModel,
          clickMomentCallback: (NotedUIModel? notedUIModel) async {
            await ChuChuNavigator.pushPage(
              context,
                  (context) => FeedInfoPage(notedUIModel: notedUIModel),
            );
          },
        ).setPadding(EdgeInsets.only(bottom: 16.0,left: 16));
      },
    );
  }

  Widget _buildTopStoriesSection() {
    final storiesContent = RepaintBoundary(
      child: ListView.builder(
        controller: storiesScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 16, right: 16, top: _topPadding, bottom: _bottomPadding),
        itemCount: myGroupsList.length + 1,
        itemBuilder: _buildStoryItemBuilder,
      ),
    );

    final bottomBorder = BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).dividerColor.withAlpha(80),
          width: _borderWidth,
        ),
      ),
    );

    // On Web platform, always show stories section (no animation)
    if (kIsWeb) {
      return Container(
        height: kStoriesSectionHeight,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: bottomBorder,
        child: storiesContent,
      );
    }
    
    // On other platforms, use animated version with scroll hide functionality
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        height: _isStoriesVisible ? _storiesHeight : 0,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: bottomBorder,
        clipBehavior: Clip.hardEdge,
        child: _isStoriesVisible ? storiesContent : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildStoryItemBuilder(BuildContext context, int index) {
    if(index == myGroupsList.length) {
      return _buildAddStoryItem();
    }
    return _buildMyGroupStoryItem(index);
  }

  Widget _buildMyGroupStoryItem(int userIndex) {
    RelayGroupDBISAR relayGroupDB = myGroupsList.values.toList()[userIndex].value;
    bool hasNewNotes =  _notificationGroupNotes[relayGroupDB.groupId]?.isNotEmpty ?? false;
    final noteCount = _notificationGroupNotes[relayGroupDB.groupId]?.length ?? 0;

    return GestureDetector(
      onTap: () async {
        // On web, if it's current user's page, switch to myPosts; otherwise push in nested Navigator
        if (kIsWeb) {
          final currentPubkey = Account.sharedInstance.currentPubkey;
          final isCurrentUser = relayGroupDB.groupId == currentPubkey;
          
          if (isCurrentUser) {
            // Switch to myPosts page
            final homeState = context.findAncestorStateOfType<HomePageState>();
            if (homeState != null) {
              homeState.switchToWebPage(WebContentPage.myPosts);
              updateNotesList(true);
              _handleNewNotesAfterNavigation(relayGroupDB, hasNewNotes);
              return;
            }
          } else {
            // For other users, push in nested Navigator
            // Get nested Navigator context from home page
            final homeState = context.findAncestorStateOfType<HomePageState>();
            final nestedContext = homeState?.getNestedNavigatorContext(WebContentPage.home);
            if (nestedContext != null) {
              await ChuChuNavigator.pushPage(
                context,
                (context) => FeedPersonalPage(relayGroupDB: relayGroupDB),
                nestedNavigatorContext: nestedContext,
                fullscreenDialog: false,
              );
            } else {
              // Fallback: use normal navigation
              await ChuChuNavigator.pushPage(
                context,
                (context) => FeedPersonalPage(relayGroupDB: relayGroupDB),
              );
            }
            updateNotesList(true);
            _handleNewNotesAfterNavigation(relayGroupDB, hasNewNotes);
            return;
          }
        }
        
        // Mobile: use normal navigation
        await ChuChuNavigator.pushPage(
          context,
          (context) => FeedPersonalPage(relayGroupDB: relayGroupDB),
        );
        updateNotesList(true);
        _handleNewNotesAfterNavigation(relayGroupDB, hasNewNotes);
      },
      child: _buildStoryItem(
        relayGroup: relayGroupDB,
        isCurrentUser: false,
        hasUnread: hasNewNotes,
        marginRight: 16,
        storyCount: noteCount,
      ),
    );
  }

  Widget _buildAddStoryItem() {
    return GestureDetector(
      onTap: () {
        // On web, switch to search page in content area instead of pushing
        if (kIsWeb) {
          final homeState = context.findAncestorStateOfType<HomePageState>();
          if (homeState != null) {
            homeState.switchToWebPage(WebContentPage.search);
          } else {
            ChuChuNavigator.pushPage(context, (context) => SearchPage());
          }
        } else {
          ChuChuNavigator.pushPage(context, (context) => SearchPage());
        }
      },
      child: _buildStoryItem(
        isCurrentUser: false,
        hasUnread: false,
        marginRight: 12,
        storyCount: 0,
        isAddButton: true,
      ),
    );
  }

  Widget _buildStoryItem({
    RelayGroupDBISAR? relayGroup,
    required bool isCurrentUser,
    required bool hasUnread,
    double marginRight = 0,
    int storyCount = 0,
    bool isAddButton = false,
  }) {
    final theme = Theme.of(context);

    int noteCount = _notificationGroupNotes[relayGroup?.groupId]?.length ?? 0;
    return Container(
      width: storyItemWidth,
      margin: EdgeInsets.only(right: marginRight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          isAddButton
              ? _buildAddButton()
              :
          ValueListenableBuilder<UserDBISAR>(
            valueListenable: Account.sharedInstance.getUserNotifier(
              relayGroup?.groupId ?? '',
            ),
            builder: (context, user, child) {
              return StoryCircle(
                    imageUrl: user.picture ?? '',
                size: avatarSize,
                    segmentCount: noteCount > 0 ? noteCount : 0,
                    gapRatio: 0.1,
              );
            },
          ),
          SizedBox(height: _itemGap),
          SizedBox(
            height: _textLineHeight,
            child: Text(
              relayGroup?.name ?? 'Add',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Center(
        child: CommonImage(
          iconName: 'add_circle_btn.png',
          size: avatarSize,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel timers to prevent setState after dispose
    _scrollProcessingTimer?.cancel();
    if (_relayReadyListener != null) {
      RelayGroup.sharedInstance.isReady.removeListener(_relayReadyListener!);
    }
    
    ChuChuUserInfoManager.sharedInstance.removeObserver(this);
    ChuChuFeedManager.sharedInstance.removeObserver(this);

    // Restore original callback if we saved it, otherwise clear it
    // Note: We can't easily restore the original callback here since we don't store it
    // But setting to null should be safe as other components can set their own callbacks
    RelayGroup.sharedInstance.myGroupsUpdatedCallBack = null;

    final scrollController = widget.scrollController ?? feedScrollController;
    scrollController.removeListener(_onScroll);

    super.dispose();
  }

  Future<void> updateNotesList(bool isInit) async {
    if (!mounted) {
      return;
    }
    
    // Reset timestamp when refreshing to ensure loading from latest data
    if (isInit) {
      _allNotesFromDBLastTimestamp = null;
      _clearAvatarBorders();
    }
    
    if (isInit && notesList.isEmpty) {
      if (mounted) {
        setState(() => _isInitialLoading = true);
      }
    }

    try {
      // List<NoteDBISAR> list = await _getNoteTypeToDB(isInit);
      debugPrint('[DB-Web] 🔵 FeedPage loading notes, isInit: $isInit, until: ${isInit ? null : _allNotesFromDBLastTimestamp}');
      List<NoteDBISAR> list = await RelayGroup.sharedInstance.loadAllMyGroupsNotesFromDB(
          until: isInit ? null : _allNotesFromDBLastTimestamp,
          limit: _limit) ??
          [];
      
      debugPrint('[DB-Web] 🔵 FeedPage loaded ${list.length} notes from database');
      
      if (!mounted) {
        return;
      }
      
      if (list.isEmpty) {
        debugPrint('[DB-Web] ⚠️ FeedPage no notes found, isInit: $isInit');
        isInit
            ? refreshController.refreshCompleted()
            : refreshController.loadNoData();

        if (isInit) {
          _setInitialLoadingFalse();
        }

        return;
      }

      List<NoteDBISAR> showList = _filterNotes(list);
      debugPrint('🔵 [FeedPage] After filtering: ${showList.length} notes');
      _updateUI(showList, isInit, list.length);
      
      // Ensure loading state is cleared after UI update
      if (isInit && _isInitialLoading) {
        // Use a small delay to ensure _updateUI's microtask has a chance to run
        Future.microtask(() {
          if (mounted && _isInitialLoading) {
            _setInitialLoadingFalse();
          }
        });
      }

      if (list.length < _limit) {
        refreshController.loadNoData();
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading notes: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        refreshController.loadFailed();
        _setInitialLoadingFalse();
      }
    }
  }

  List<NoteDBISAR> _filterNotes(List<NoteDBISAR> list) {

    return list
        .where((NoteDBISAR note) => !note.isReaction && (note.root == null || note.root!.isEmpty))
        .toList();
  }

  void _updateUI(List<NoteDBISAR> showList, bool isInit, int fetchedCount) {
    Future.microtask(() {
      if (!mounted) {
        return;
      }

      debugPrint('🔵 [FeedPage] _updateUI called, isInit: $isInit, showList.length: ${showList.length}');
      final List<NotedUIModel?> list =
          showList.map((item) => NotedUIModel(noteDB: item)).toList();

      if (isInit) {
        notesList = list;
        debugPrint('🔵 [FeedPage] Updated notesList (init), new length: ${notesList.length}');
      } else {
        notesList.addAll(list);
        debugPrint('🔵 [FeedPage] Added to notesList, new length: ${notesList.length}');
      }

      if (showList.isNotEmpty) {
        _allNotesFromDBLastTimestamp = showList.last.createAt;
      }

      if (isInit) {
        refreshController.refreshCompleted();
      } else {
        fetchedCount < _limit
            ? refreshController.loadNoData()
            : refreshController.loadComplete();
      }

      if (_isInitialLoading) {
        _isInitialLoading = false;
      }

      if (mounted) {
        setState(() {
          // Explicitly set loading to false in setState to ensure UI updates
          if (_isInitialLoading) {
            _isInitialLoading = false;
          }
        });
      }
    });
  }

  @override
  didNewNotesCallBackCallBack(List<NoteDBISAR> notes) {
    // Process both new notes and updates to existing notes
    final List<NoteDBISAR> incremental = notes
        .where((n) => !_seenNoteIds.contains(n.noteId))
        .toList(growable: false);
    
    // Update existing notes in notesList if they exist
    bool hasUpdates = false;
    for (NoteDBISAR note in notes) {
      final noteId = note.noteId;
      final index = notesList.indexWhere((n) => n?.noteDB.noteId == noteId);
      if (index != -1 && notesList[index] != null) {
        // Update existing note in notesList
        notesList[index] = NotedUIModel(noteDB: note);
        hasUpdates = true;
      }
    }

    if (incremental.isEmpty && !hasUpdates) return;

    _seenNoteIds.addAll(incremental.map((n) => n.noteId));
    
    // Check and insert my posts
    _insertMyPosts(incremental);
    
    _notificationUpdateNotes(incremental);
    
    // Update UI if there were updates to existing notes
    if (hasUpdates && mounted) {
      setState(() {});
    }
  }

  /// Find and insert posts sent by current user into notesList
  void _insertMyPosts(List<NoteDBISAR> notes) {
    if (notes.isEmpty || !mounted) return;

    try {
      final currentPubkey = Account.sharedInstance.currentPubkey;
      final List<NotedUIModel?> myPosts = [];
      
      // Find all posts sent by current user
      for (NoteDBISAR noteDB in notes) {
        // Check if this is a post sent by current user
        bool isMyPost = noteDB.author == currentPubkey &&
            !noteDB.isReaction &&
            (noteDB.root == null || noteDB.root!.isEmpty);
        
        if (isMyPost) {
          // Create NotedUIModel and add to list for insertion
          myPosts.add(NotedUIModel(noteDB: noteDB));
        }
      }
      
      // Insert my posts to the beginning of notesList
      if (myPosts.isNotEmpty && mounted) {
        // Remove duplicates by noteId before inserting
        final existingNoteIds = notesList.map((n) => n?.noteDB.noteId).toSet();
        final newPosts = myPosts.where((post) => 
          post != null && !existingNoteIds.contains(post.noteDB.noteId)
        ).toList();
        
        if (newPosts.isNotEmpty) {
          // Sort by createAt descending (newest first)
          newPosts.sort((a, b) => 
            (b?.noteDB.createAt ?? 0).compareTo(a?.noteDB.createAt ?? 0)
          );
          
          // Create a new list to ensure ListView detects the change
          notesList = [...newPosts, ...notesList];
          _listVersion++; // Increment version to force ListView refresh
          
          // Update UI immediately
          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugPrint('Error inserting my posts: $e');
    }
  }

  void _notificationUpdateNotes(List<NoteDBISAR> notes) async {
    if (notes.isEmpty || !mounted) return;

    try {
      if (mounted) {
        Future.microtask(() {
          if (mounted) {
            for (NoteDBISAR noteDB in notes) {
              bool isGroupNoted = noteDB.groupId.isNotEmpty;
              bool isRootNote = noteDB.root == null || noteDB.root!.isEmpty;
              if (isGroupNoted && isRootNote) {
                if(_notificationGroupNotes[noteDB.groupId] == null){
                  _notificationGroupNotes[noteDB.groupId] = [noteDB];
                }else{
                  _notificationGroupNotes[noteDB.groupId] = [... _notificationGroupNotes[noteDB.groupId]!,noteDB];
                }
              }
            }
            // Re-sort the groups list after updating notifications
            _sortMyGroupsList();
            setState(() {});
          }
        });
      }
    } catch (e) {
      debugPrint('Error updating notification notes: $e');
    }
  }

  @override
  didNewNotificationCallBack(List<NotificationDBISAR> notifications) {}

  @override
  void didLoginSuccess(UserDBISAR? userInfo) {
    _hasInitializedNotes = false;
    _initData();
  }

  @override
  void didLogout() {
    _resetData();
  }

  @override
  void didSwitchUser(UserDBISAR? userInfo) {}
}

class StoryCircle extends StatelessWidget {
  final String imageUrl;
  final double size;
  final int segmentCount;
  final double gapRatio;

  const StoryCircle({
    super.key,
    required this.imageUrl,
    this.size = 110,
    this.segmentCount = 0,
    this.gapRatio = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // color: Colors.red,
      width: size,
      height:size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ChuChuCachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => FeedWidgetsUtils.badgePlaceholderImage(),
              errorWidget: (_, __, ___) => FeedWidgetsUtils.badgePlaceholderImage(),
              width: segmentCount == 0 ? size  : size - 8,
              height: segmentCount == 0 ? size  : size - 8,
            ),
          ),
          segmentCount > 0 ? CustomPaint(
            size: Size(size , size),
            painter: _SegmentedBorderPainter(
              segmentCount: segmentCount,
              gapRatio: gapRatio,
              isShowBorder: segmentCount > 0,
            ),
          ): const SizedBox(),
        ],
      ),
    );
  }
}

class _SegmentedBorderPainter extends CustomPainter {
  final int segmentCount;
  final double gapRatio;
  final bool isShowBorder;

  _SegmentedBorderPainter({
    required this.segmentCount,
    required this.gapRatio,
    required this.isShowBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 1;

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * pi,
      colors: isShowBorder
          ? [kPrimary, kSecondary]
          : [Colors.transparent, Colors.transparent],
    );

    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    final borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (segmentCount == 1) {
      canvas.drawArc(rect, 0, 2 * pi, false, borderPaint);
    } else {
      // Base sector angle per segment
      final double sector = (2 * pi) / segmentCount;
      // Make the gap grow with segmentCount, so more segments -> larger gaps
      // gapAngle is absolute radians, clamped below the sector size
      final double baseGapAngle = sector * gapRatio; // start from provided ratio
      final double growthPerSegment = 0.03; // gentler growth (~1.7° per extra segment)
      final double gapAngle = (baseGapAngle + growthPerSegment * (segmentCount - 1))
          .clamp(0.0, sector * 0.6);

      final double minSweep = 0.06; // ensure each segment still visible (~3.4°)
      final double sweep = (sector - gapAngle).clamp(minSweep, sector);

      for (int i = 0; i < segmentCount; i++) {
        final double startAngle = sector * i;
        canvas.drawArc(rect, startAngle, sweep, false, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _SegmentedBorderPainter) {
      return oldDelegate.segmentCount != segmentCount ||
          oldDelegate.gapRatio != gapRatio ||
          oldDelegate.isShowBorder != isShowBorder;
    }
    return true;
  }
}




