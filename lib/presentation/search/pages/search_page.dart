import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:chuchu/core/relayGroups/relayGroup+info.dart';
import 'package:chuchu/core/utils/widget_tool_utils.dart';
import 'package:flutter/material.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:chuchu/core/account/model/userDB_isar.dart';
import 'package:chuchu/presentation/feed/pages/feed_personal_page.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:nostr_core_dart/src/nips/nip_019.dart';

import '../../../core/account/account.dart';
import '../../../core/account/account+profile.dart';
import '../../../core/config/config.dart';
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

  @override
  void initState() {
    super.initState();
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
              // Search header
              _buildSearchHeader(),

              // Search content
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
          // Search input field
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
      // Show search icon placeholder
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

    if (_isSearching) {
      // Show loading
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
      // Show no data icon
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

    // Show search results
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
            Color(0xFF00CED1), // Blue-teal
            Color(0xFFFFB900), // Golden yellow
            Color(0xFFFF4444), // Red
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
    return GestureDetector(
      onTap: () {
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
            // Gradient banner at top
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
            // Profile picture overlapping banner
            ValueListenableBuilder<UserDBISAR>(
              valueListenable: Account.sharedInstance.getUserNotifier(
                relayGroup.groupId,
              ),
              builder: (context, userInfo, child) {
                return Positioned(
                  left: 16,
                  top: 50, // Half of banner height (100/2) to center overlap
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

            // Content section - starts from banner bottom, accounting for avatar overlap
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                100 + 30,
                16,
                16,
              ), // banner height + half avatar height
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display name and Follow button row
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
                            // Username (npub short format)
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
                      // Follow button
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
                            onTap: () {
                              // Handle follow action
                            },
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
                  // Bio
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
                  // Followers and mutual connections
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

  /// Validate npub1 format
  /// npub1 format: starts with 'npub1' followed by bech32 encoded data
  bool _isValidNpub1(String input) {
    if (!input.startsWith('npub1')) {
      return false;
    }

    // npub1 should be at least 63 characters long (npub1 + 58 chars of bech32 data)
    if (input.length < 63) {
      return false;
    }

    // Extract the bech32 part (after 'npub1')
    String bech32Part = input.substring(5);

    // Check if it contains only valid bech32 characters (qpzry9x8gf2tvdw0s3jn54khce6mua7l)
    RegExp bech32Regex = RegExp(r'^[qpzry9x8gf2tvdw0s3jn54khce6mua7l]+$');
    if (!bech32Regex.hasMatch(bech32Part)) {
      return false;
    }

    // Additional length check for npub1 (should be around 63 characters)
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
        // Validate npub1 format
        if (!_isValidNpub1(trimmedQuery)) {
          print('🔍Invalid npub1 format: $trimmedQuery');
          setState(() {
            _isSearching = false;
            _searchResults = [];
          });
          return;
        }
        // Decode npub to get pubkey
        pubkey = UserDBISAR.decodePubkey(trimmedQuery);
        print('🔍Valid npub1 format, decoded pubkey: $pubkey');
      }

      if (pubkey == null || pubkey.isEmpty) {
        print('🔍Failed to decode pubkey from: $trimmedQuery');
        setState(() {
          _isSearching = false;
          _searchResults = [];
        });
        return;
      }

      // Get user info from Account
      RelayGroupDBISAR? relayGroup = await RelayGroup.sharedInstance
          .searchGroupsMetadataWithGroupID(
            pubkey,
            Config.sharedInstance.recommendGroupRelays.first,
          );
      print('🔍npub: $trimmedQuery');
      print('🔍pubkey: $pubkey');
      print('🔍relayGroup: $relayGroup');
      print('🔍relayGroupId: ${relayGroup?.groupId}');
      print('🔍name: ${relayGroup?.name}');
      print('🔍subscriptionAmount: ${relayGroup?.subscriptionAmount}');

      // Trigger user info loading (including avatar) after getting relayGroup
      if (relayGroup != null) {
        // Always reload profile from relay to get the latest user info (including avatar)
        // This ensures we always show the most up-to-date information, even if user updated their avatar
        print('🔍Reloading user profile from relay to get latest info...');
        Account.sharedInstance
            .reloadProfileFromRelay(pubkey)
            .then((updatedUser) {
              print('🔍User Info (from relay):');
              print('  - pubkey: ${updatedUser.pubKey}');
              print('  - name: ${updatedUser.name}');
              print('  - picture: ${updatedUser.picture ?? "null"}');
              print('  - about: ${updatedUser.about ?? "null"}');
              print('  - lastUpdatedTime: ${updatedUser.lastUpdatedTime}');
            })
            .catchError((e) {
              print('🔍Error reloading profile from relay: $e');
            });

        // getUserNotifier in _authorCard will return the user info from cache
        // reloadProfileFromRelay will update the ValueNotifier when user info is loaded from relay
        // This ensures the UI updates automatically when the latest info is available
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
      debugPrint('Search failed: $e');
    }
  }
}
