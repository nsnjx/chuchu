import 'package:chuchu/core/relayGroups/relayGroup+info.dart';
import 'package:chuchu/core/relayGroups/relayGroup+note.dart';
import 'package:chuchu/data/models/feed_extension_model.dart';
import 'package:chuchu/presentation/feed/widgets/locked_content_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;

import '../../../core/account/account.dart';
import '../../../core/config/config.dart';
import '../../../core/feed/model/noteDB_isar.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/widgets/chuchu_smart_refresher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_image.dart';
import '../../../data/models/noted_ui_model.dart';
import '../../profile/pages/profile_edit_page.dart';
import '../../profile/pages/share_profile_page.dart';
import '../../home/pages/home_page.dart';
import '../../home/widgets/drawer_menu.dart';
import '../widgets/feed_personal_header_widget.dart';
import '../widgets/feed_widget.dart';
import '../widgets/subscribed_ui_widget.dart';
import 'feed_info_page.dart';

class FeedPersonalPage extends StatefulWidget {
  final RelayGroupDBISAR relayGroupDB;

  const FeedPersonalPage({super.key, required this.relayGroupDB});

  @override
  State<FeedPersonalPage> createState() => _FeedPersonalPageState();
}

class _FeedPersonalPageState extends State<FeedPersonalPage>
    with ChuChuUIRefreshMixin {
  final ScrollController _scrollController = ScrollController();
  final RefreshController _refreshController = RefreshController();

  bool _isInitialLoading = true;
  ESubscriptionStatus subscriptionStatus = ESubscriptionStatus.unsubscribed;
  bool _isFetchingRemoteNotes = false;

  bool _isShowAppBar = false;

  List<NotedUIModel?> notesList = [];
  int? _allNotesFromDBLastTimestamp;

  static const int _limit = 1000;
  static const double _triggerOffset = 100;

  @override
  void initState() {
    super.initState();
    _initializePageData();
  }

  void _initializePageData() {
    _setStatusBarStyle();
    getSubscriptionStatus();
    _scrollController.addListener(_handleScroll);
    updateNotesList(true);
  }

  Future<void> getSubscriptionStatus() async {
    final myPubkey = Account.sharedInstance.currentPubkey;
    if (widget.relayGroupDB.author == myPubkey) {
      subscriptionStatus = ESubscriptionStatus.author;
      setState(() {});
      return;
    }

    RelayGroupDBISAR group = widget.relayGroupDB;
    try {
      final remoteGroup = await RelayGroup.sharedInstance
          .getGroupMetadataFromRelay(
            widget.relayGroupDB.groupId,
            relay: Config.sharedInstance.recommendGroupRelays.first,
            author: widget.relayGroupDB.author,
          );
      if (remoteGroup != null) {
        group = remoteGroup;
        debugPrint(
          'FeedPersonalPage: fetched remote group metadata (subscriptionAmount=${group.subscriptionAmount}, members=${group.members?.length ?? 0})',
        );
      }

      // Ensure we have member info. If missing, pull from relays.
      if (group.members == null || group.members!.isEmpty) {
        final refreshedGroup = await RelayGroup.sharedInstance
            .searchGroupMembersFromRelays(group);
        group = refreshedGroup;
        debugPrint(
          'FeedPersonalPage: refreshed members from relays (members=${group.members?.length ?? 0})',
        );
      }
    } catch (e) {
      debugPrint('FeedPersonalPage getSubscriptionStatus failed: $e');
    }

    final List<String> members =
        (group.members ?? widget.relayGroupDB.members ?? const <String>[])
            .toList();
    debugPrint(
      'FeedPersonalPage: evaluating subscription status. subscriptionAmount=${group.subscriptionAmount}, membersCount=${members.length}, containsMe=${members.contains(myPubkey)}',
    );
    final bool isSubscribed = members.contains(myPubkey);
    final bool isPaidGroup = group.subscriptionAmount > 0;

    if (isPaidGroup) {
      subscriptionStatus =
          isSubscribed
              ? ESubscriptionStatus.subscribed
              : ESubscriptionStatus.unsubscribed;
    } else {
      subscriptionStatus =
          isSubscribed
              ? ESubscriptionStatus.subscribed
              : ESubscriptionStatus.free;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShowAppBar = _scrollController.offset > _triggerOffset;
    if (shouldShowAppBar != _isShowAppBar) {
      setState(() => _isShowAppBar = shouldShowAppBar);
    }
  }

  void _setStatusBarStyle() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  PreferredSizeWidget? _buildAppBar() {
    if (!_isShowAppBar) return null;
    final top = MediaQuery.of(context).padding.top;
    final name =
        Account.sharedInstance
            .getUserNotifier(widget.relayGroupDB.author)
            .value
            .name;
    return PreferredSize(
      preferredSize: const Size.fromHeight(50),
      child: Container(
        height: kToolbarHeight + top,
        padding: EdgeInsets.only(top: top),
        color: Theme.of(context).colorScheme.primary,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // On web, check if we're in a nested Navigator and if we can pop
                // If we're the initial route (can't pop), switch to home page instead
                if (kIsWeb) {
                  final navigator = Navigator.of(context, rootNavigator: false);
                  if (navigator.canPop()) {
                    navigator.pop();
                  } else {
                    // We're the initial route, switch to home page
                    final homeState = context.findAncestorStateOfType<HomePageState>();
                    if (homeState != null) {
                      homeState.switchToWebPage(WebContentPage.home);
                    } else {
                      Navigator.of(context).pop();
                    }
                  }
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name ?? '--',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            actionWidget(),
          ],
        ),
      ),
    );
  }

  Widget actionWidget() {
    if (subscriptionStatus == ESubscriptionStatus.author) {
      return IconButton(
        onPressed: () {
          ChuChuNavigator.pushPage(
            context,
            (context) => ProfileEditPage(relayGroup: widget.relayGroupDB),
          );
        },
        icon: CommonImage(
          iconName: 'setting_icon.png',
          size: 24,
          color: Colors.white,
        ),
      );
    }
    
    return IconButton(
      onPressed: () {
        ChuChuNavigator.pushPage(
          context,
          (context) => ShareProfilePage(pubkey: widget.relayGroupDB.groupId),
        );
      },
      icon: CommonImage(
        iconName: 'share_icon.png',
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    return ChuChuSmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: true,
      onRefresh: () => updateNotesList(true),
      onLoading: () => updateNotesList(false),
      child: _buildListView(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _calculateItemCount(),
      itemBuilder: _buildListItem,
    );
  }

  int _calculateItemCount() {
    if (notesList.isEmpty) return 3; // Header + subscription + content
    switch (subscriptionStatus) {
      case ESubscriptionStatus.author:
      case ESubscriptionStatus.free:
      case ESubscriptionStatus.subscribed:
        return notesList.length + 2;
      case ESubscriptionStatus.unsubscribed:
        return 3;
    }
  }

  Widget _buildListItem(BuildContext context, int index) {
    if (index == 0) {
      return Column(
        children: [
          FeedPersonalHeaderWidget(
            isShowAppBar: _isShowAppBar,
            relayGroupDB: widget.relayGroupDB,
            actionWidget: actionWidget(),
          ),
          dividerWidget(),
        ],
      );
    }

    if (index == 1) {
      if (subscriptionStatus == ESubscriptionStatus.author) {
        return const SizedBox();
      } else {
        return Column(
          children: [
            SubscribedOptionWidget(
              relayGroup: widget.relayGroupDB,
              subscriptionStatus: subscriptionStatus,
              onSubscriptionSuccess: () {
                getSubscriptionStatus();
              },
            ),
            dividerWidget(),
          ],
        );
      }
    }

    if (index == 2) {
      if (subscriptionStatus == ESubscriptionStatus.unsubscribed) {
        return LockedContentSection(creatorName:widget.relayGroupDB.name);
      }
      if (notesList.isEmpty) {
        return _buildEmptyState();
      }
    }

    final noteIndex = index - 2;
    if (noteIndex >= 0 && noteIndex < notesList.length) {
      return Column(
        children: [
          const SizedBox(height: 20),
          _buildFeedItem(notesList[noteIndex]),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isAuthor = subscriptionStatus == ESubscriptionStatus.author;

    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          CommonImage(iconName: 'search_ill_icon.png', size: 150),
          const SizedBox(height: 24),
          Text(
            isAuthor ? 'Start Creating' : 'No Posts Yet',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              isAuthor
                  ? 'Share your first post and connect with your audience'
                  : 'This creator hasn\'t shared any content yet',
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedItem(NotedUIModel? notedUIModel) {
    if (notedUIModel == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: FeedWidget(
        isShowReplyWidget: true,
        feedWidgetLayout: EFeedWidgetLayout.fullScreen,
        notedUIModel: notedUIModel,
        clickMomentCallback:
            (m) => ChuChuNavigator.pushPage(
              context,
              (_) => FeedInfoPage(notedUIModel: m),
            ),
      ),
    );
  }

  Widget dividerWidget() {
    return Container(
      width: double.infinity,
      height: 6,
      color: Theme.of(context).dividerColor.withAlpha(20),
    );
  }

  Future<void> updateNotesList(bool isInit) async {
    try {
      final until = isInit ? null : _allNotesFromDBLastTimestamp;
      List<NoteDBISAR> list =
          await RelayGroup.sharedInstance.loadGroupNotesFromDB(
            widget.relayGroupDB.groupId,
            until: until,
            limit: _limit,
          ) ??
          [];

      if (list.isEmpty) {
        await _fetchNotesFromRelay(isInitial: isInit);
        list =
            await RelayGroup.sharedInstance.loadGroupNotesFromDB(
              widget.relayGroupDB.groupId,
              until: until,
              limit: _limit,
            ) ??
            [];
      }

      debugPrint(
        'FeedPersonalPage: fetched ${list.length} notes from ISAR (group=${widget.relayGroupDB.groupId}, until=$until, init=$isInit)',
      );
      if (list.isEmpty) {
        isInit
            ? _refreshController.refreshCompleted()
            : _refreshController.loadNoData();
        return;
      }

      List<NoteDBISAR> showList = _filterNotes(list);
      _updateUI(showList, isInit, list.length);

      if (list.length < _limit) {
        _refreshController.loadNoData();
      }
    } catch (e) {
      print('Error loading notes: $e');
      _refreshController.loadFailed();
    }
  }

  Future<void> _fetchNotesFromRelay({required bool isInitial}) async {
    if (_isFetchingRemoteNotes) return;
    _isFetchingRemoteNotes = true;
    try {
      final RelayGroupDBISAR group =
          RelayGroup
              .sharedInstance
              .groups[widget.relayGroupDB.groupId]
              ?.value ??
          widget.relayGroupDB;
      await RelayGroup.sharedInstance.fetchGroupNotesFromRelays(
        group,
        limit: _limit,
        until: isInitial ? null : _allNotesFromDBLastTimestamp,
      );
    } catch (e) {
      debugPrint('FeedPersonalPage: remote fetch failed $e');
    } finally {
      _isFetchingRemoteNotes = false;
    }
  }

  void _updateUI(List<NoteDBISAR> showList, bool isInit, int fetchedCount) {
    List<NotedUIModel> list =
        showList.map((note) => NotedUIModel(noteDB: note)).toList();
    if (isInit) {
      notesList = list;
    } else {
      notesList.addAll(list);
    }

    _allNotesFromDBLastTimestamp = showList.last.createAt;

    if (isInit) {
      _refreshController.refreshCompleted();
    } else {
      fetchedCount < _limit
          ? _refreshController.loadNoData()
          : _refreshController.loadComplete();
    }
    setState(() {});
  }

  List<NoteDBISAR> _filterNotes(List<NoteDBISAR> notes) {
    if (notes.isEmpty) return [];

    return notes
        .where(
          (note) =>
              !note.isReaction && (note.root == null || note.root!.isEmpty),
        )
        .toList();
  }

  void _updateUIWithNotes(
    List<NoteDBISAR> filteredNotes,
    bool isInit,
    int fetchedCount,
  ) {
    if (filteredNotes.isEmpty) {
      _handleEmptyFilteredNotes(isInit);
      return;
    }

    final uiModels =
        filteredNotes.map((item) => NotedUIModel(noteDB: item)).toList();

    if (isInit) {
      notesList = uiModels;
    } else {
      notesList.addAll(uiModels);
    }
    if (filteredNotes.isNotEmpty) {
      _allNotesFromDBLastTimestamp = filteredNotes.last.createAt;
    }

    if (isInit) {
      _refreshController.refreshCompleted();
    } else {
      fetchedCount < _limit
          ? _refreshController.loadNoData()
          : _refreshController.loadComplete();
    }

    if (_isInitialLoading) {
      _isInitialLoading = false;
    }

    setState(() {});
  }

  void _handleEmptyFilteredNotes(bool isInit) {
    if (isInit) {
      notesList = [];
    }

    _refreshController.refreshCompleted();

    if (_isInitialLoading) {
      _isInitialLoading = false;
    }

    setState(() {});
  }

  void _handleLoadingError(dynamic error) {
    debugPrint('Error loading notes: $error');
    _refreshController.loadFailed();
    setState(() => _isInitialLoading = false);
  }
}
