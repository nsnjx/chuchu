import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/relayGroups/relayGroup+info.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:chuchu/core/account/model/userDB_isar.dart';
import 'package:chuchu/presentation/feed/pages/feed_personal_page.dart';
import 'package:chuchu/presentation/home/pages/home_page.dart';
import 'package:chuchu/presentation/home/widgets/drawer_menu.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/account/account.dart';
import '../../../core/account/account+profile.dart';
import '../../../core/config/config.dart';
import '../../../core/utils/log_utils.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/theme/app_theme.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with ChuChuUIRefreshMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isSearching = false;
  List<RelayGroupDBISAR> _searchResults = [];
  bool _hasSearched = false;
  List<String> _searchHistory = [];
  static const String _searchHistoryKey = 'search_history_pubkeys';
  static const int _maxHistoryCount = 10;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
          'Search',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Column(
            children: [
              _buildSearchHeader(),
              Expanded(child: _buildSearchContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CommonImage(iconName: 'search_icon.png', size: 20),

                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search npub...',
                        hintStyle: GoogleFonts.inter(
                          color: theme.colorScheme.outline,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                              suffixIconConstraints:BoxConstraints(
                                maxHeight: 16,
                                maxWidth: 16
                              ),
                            suffixIcon: value.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _hasSearched = false;
                                        _searchResults.clear();
                                      });
                                    },
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      child: Icon(
                                        Icons.close,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : null,
                      ),
                      style: GoogleFonts.inter(
                        color: kTitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            _hasSearched = false;
                            _searchResults.clear();
                          });
                        } else {
                          _performSearch(value);
                        }
                      },
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _performSearch(value);
                        }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    final theme = Theme.of(context);

    if (!_hasSearched) {
      if (_searchHistory.isEmpty) {
      return Column(
        children: [
          CommonImage(iconName: 'search_ill_icon.png', width: 187),
          const SizedBox(height: 20),
          Text(
            'Search by npub',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a npub address to discover\nand subscribe to creators',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).setPaddingOnly(top: 60.0);
      } else {
        return _buildSearchHistory();
      }
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Column(
        children: [
          CommonImage(iconName: 'no_result_ill.png', width: 187, height: 150),
          const SizedBox(height: 20),
          Text(
            'No creators found',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with a different npub',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ).setPaddingOnly(top: 60.0);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _authorCard(_searchResults[index]);
      },
    );
  }

  Widget _authorCard(RelayGroupDBISAR relayGroup) {
    final theme = Theme.of(context);
    Widget pictureView = Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00CED1),
            Color(0xFFFFB900),
            Color(0xFFFF4444),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
    return GestureDetector(
      onTap: () {
        // On web, if it's current user's page, switch to myPosts; otherwise push in nested Navigator
        if (kIsWeb) {
          final currentPubkey = Account.sharedInstance.currentPubkey;
          final isCurrentUser = relayGroup.groupId == currentPubkey;
          
          if (isCurrentUser) {
            // Switch to myPosts page
            final homeState = context.findAncestorStateOfType<HomePageState>();
            if (homeState != null) {
              homeState.switchToWebPage(WebContentPage.myPosts);
              return;
            }
          } else {
            // For other users, push in nested Navigator
            // Get nested Navigator context from home page
            final homeState = context.findAncestorStateOfType<HomePageState>();
            final nestedContext = homeState?.getNestedNavigatorContext(WebContentPage.home);
            if (nestedContext != null) {
              ChuChuNavigator.pushPage(
                context,
                (context) => FeedPersonalPage(relayGroupDB: relayGroup),
                nestedNavigatorContext: nestedContext,
                fullscreenDialog: false,
              );
            } else {
              // Fallback: use normal navigation
              ChuChuNavigator.pushPage(
                context,
                (context) => FeedPersonalPage(relayGroupDB: relayGroup),
              );
            }
            return;
          }
        }
        
        // Mobile: use normal navigation
        ChuChuNavigator.pushPage(
          context,
          (context) => FeedPersonalPage(relayGroupDB: relayGroup),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            relayGroup.picture.isEmpty
                ? pictureView
                : ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: ChuChuCachedNetworkImage(
                    imageUrl: relayGroup.picture,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => pictureView,
                    errorWidget: (context, url, error) => pictureView,
                    height: 100,
                    width: double.infinity,
                  ),
                ),
            ValueListenableBuilder<UserDBISAR>(
              valueListenable: Account.sharedInstance.getUserNotifier(
                relayGroup.groupId,
              ),
              builder: (context, userInfo, child) {
                return Positioned(
                  left: 16,
                  top: 50,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: ClipOval(
                      child:
                          userInfo.picture != null &&
                                  userInfo.picture!.isNotEmpty
                              ? ChuChuCachedNetworkImage(
                                imageUrl: userInfo.picture!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => CommonImage(
                                      iconName: 'icon_user_default.png',
                                      width: 80,
                                      height: 80,
                                    ),
                                errorWidget:
                                    (context, url, error) => CommonImage(
                                      iconName: 'icon_user_default.png',
                                      width: 80,
                                      height: 80,
                                    ),
                                width: 80,
                                height: 80,
                              )
                              : CommonImage(
                                iconName: 'icon_user_default.png',
                                width: 80,
                                height: 80,
                              ),
                    ),
                  ),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                100 + 30,
                16,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              relayGroup.name,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kTitleColor,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '@${_getShortNpub(relayGroup.groupId)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: kPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: kTitleColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Collect',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  if (relayGroup.about.isNotEmpty)
                    Text(
                      relayGroup.about,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatFollowersCount(relayGroup.members?.length ?? 0),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kTitleColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Followers',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getShortNpub(String pubkey) {
    try {
      final npub = Nip19.encodePubkey(pubkey);
    if (npub.length < 12) return npub;
      return '${npub.substring(0, 6)}:${npub.substring(npub.length - 6)}';
    } catch (e) {
      if (pubkey.length < 12) return pubkey;
      return '${pubkey.substring(0, 6)}:${pubkey.substring(pubkey.length - 6)}';
    }
  }

  String _formatFollowersCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      double k = count / 1000;
      if (k % 1 == 0) {
        return '${k.toInt()}k';
      } else {
        return '${k.toStringAsFixed(1)}k';
      }
    } else {
      double m = count / 1000000;
      if (m % 1 == 0) {
        return '${m.toInt()}M';
      } else {
        return '${m.toStringAsFixed(1)}M';
      }
    }
  }

  bool _isValidNpub1(String input) {
    if (!input.startsWith('npub1')) {
      return false;
    }

    if (input.length < 63) {
      return false;
    }

    String bech32Part = input.substring(5);
    RegExp bech32Regex = RegExp(r'^[qpzry9x8gf2tvdw0s3jn54khce6mua7l]+$');
    if (!bech32Regex.hasMatch(bech32Part)) {
      return false;
    }

    if (input.length != 63) {
      return false;
    }

    return true;
  }

  void _performSearch(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults.clear();
    });

    try {
      String? pubkey;
      if (trimmedQuery.startsWith('npub1')) {
        if (!_isValidNpub1(trimmedQuery)) {
          LogUtils.d(() => 'Search: Invalid npub1 format: $trimmedQuery');
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return;
        }
        pubkey = UserDBISAR.decodePubkey(trimmedQuery);
        LogUtils.d(() => 'Search: Valid npub1, decoded pubkey: $pubkey');
      }

      if (pubkey == null || pubkey.isEmpty) {
        LogUtils.d(() => 'Search: Failed to decode pubkey from: $trimmedQuery');
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }

      RelayGroupDBISAR? relayGroup = await RelayGroup.sharedInstance
          .searchGroupsMetadataWithGroupID(
            pubkey,
            Config.sharedInstance.recommendGroupRelayOrDefault,
          );
      LogUtils.d(() => 'Search: npub=$trimmedQuery pubkey=$pubkey relayGroup=${relayGroup?.groupId} name=${relayGroup?.name}');
      if (relayGroup != null) {
        await _saveSearchHistory(relayGroup.groupId);
        Account.sharedInstance
            .reloadProfileFromRelay(pubkey)
            .then((updatedUser) {
              LogUtils.d(() => 'Search: User from relay pubkey=${updatedUser.pubKey} name=${updatedUser.name}');
            })
            .catchError((e) {
              LogUtils.w(() => 'Search: Error reloading profile from relay: $e');
            });
      }

      if (mounted) {
        setState(() {
          _isSearching = false;
          if (relayGroup != null) {
            _searchResults = [relayGroup];
          } else {
            _searchResults = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
      }
      LogUtils.w(() => 'Search failed: $e');
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_searchHistoryKey) ?? [];
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      LogUtils.w(() => 'Failed to load search history: $e');
    }
  }

  Future<void> _saveSearchHistory(String pubkey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];
      
      history.remove(pubkey);
      history.insert(0, pubkey);
      
      if (history.length > _maxHistoryCount) {
        history = history.sublist(0, _maxHistoryCount);
      }
      
      await prefs.setStringList(_searchHistoryKey, history);
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      LogUtils.w(() => 'Failed to save search history: $e');
    }
  }

  Widget _buildSearchHistory() {
    final theme = Theme.of(context);
    final historyGroups = <RelayGroupDBISAR>[];
    
    for (var pubkey in _searchHistory) {
      final group = RelayGroup.sharedInstance.groups[pubkey]?.value;
      if (group != null && group.lastUpdatedTime > 0) {
        historyGroups.add(group);
      }
    }

    if (historyGroups.isEmpty) {
      return Column(
        children: [
          CommonImage(iconName: 'search_ill_icon.png', width: 187),
          const SizedBox(height: 20),
          Text(
            'Search by npub',
            style: GoogleFonts.inter(
              fontSize: 25,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a npub address to discover\nand subscribe to creators',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).setPaddingOnly(top: 60.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTitleColor,
                ),
              ),
              if (_searchHistory.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove(_searchHistoryKey);
                    setState(() {
                      _searchHistory.clear();
                    });
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: historyGroups.length,
            itemBuilder: (context, index) {
              return _authorCard(historyGroups[index]);
            },
          ),
        ),
      ],
    );
  }
}
