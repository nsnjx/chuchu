import 'dart:io';
import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';

import '../../../core/account/account.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/config/config.dart' as AppConfig;
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/relayGroups/relayGroup+info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';

/// Share Profile Page
/// Displays user profile with QR code for sharing
class ShareProfilePage extends StatefulWidget {
  final String pubkey;

  const ShareProfilePage({
    super.key,
    required this.pubkey,
  });

  @override
  State<ShareProfilePage> createState() => _ShareProfilePageState();
}

class _ShareProfilePageState extends State<ShareProfilePage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  UserDBISAR? _userInfo;
  RelayGroupDBISAR? _relayGroup;
  String? _npub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final pubkey = widget.pubkey;

      // Get user info
      final userInfo = await Account.sharedInstance.getUserInfo(pubkey);

      // Get relay group info
      final relayGroup = await RelayGroup.sharedInstance
          .searchGroupsMetadataWithGroupID(
        pubkey,
        AppConfig.Config.sharedInstance.recommendGroupRelays.first,
      );

      final npub = Nip19.encodePubkey(pubkey);

      setState(() {
        _userInfo = userInfo;
        _relayGroup = relayGroup;
        _npub = npub;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CommonToast.instance.show(context, 'Failed to load user info', toastType: ToastType.failed);
      }
    }
  }

  String _getDisplayName() {
    if (_userInfo == null) return '--';
    return _userInfo!.name ?? _userInfo!.nickName ?? _getTruncatedNpub();
  }

  String _getTruncatedNpub() {
    if (_npub == null || _npub!.length < 12) return '--';
    return '${_npub!.substring(0, 6)}...${_npub!.substring(_npub!.length - 6)}';
  }

  void _copyLink() {
    if (_npub == null) return;

    Clipboard.setData(ClipboardData(text: _npub!));
    CommonToast.instance.show(context, 'Copied to clipboard', toastType: ToastType.success);
  }

  Future<void> _saveImage() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        CommonToast.instance.show(context, 'Failed to capture image', toastType: ToastType.failed);
        return;
      }

      final result = await ImageGallerySaverPlus.saveImage(
        image,
        quality: 100,
        name: 'profile_${widget.pubkey.substring(0, 8)}',
      );

      if (result['isSuccess'] == true) {
        CommonToast.instance.show(context, 'Image saved to gallery', toastType: ToastType.success);
      } else {
        CommonToast.instance.show(context, 'Failed to save image', toastType: ToastType.failed);
      }
    } catch (e) {
      CommonToast.instance.show(context, 'Failed to save image', toastType: ToastType.failed);
    }
  }

  Future<void> _share() async {
    try {
      final image = await _screenshotController.capture();
      if (image == null) {
        CommonToast.instance.show(context, 'Failed to capture image', toastType: ToastType.failed);
        return;
      }

      // Save temporarily for sharing
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/profile_share_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(image);

      // Use platform channel to share (or use share_plus package if available)
      if (Platform.isAndroid || Platform.isIOS) {
        // For now, copy the npub to clipboard as fallback
        _copyLink();
        CommonToast.instance.show(context, 'Profile link copied. Share functionality coming soon.', toastType: ToastType.info);
      } else {
        _copyLink();
      }
    } catch (e) {
      _copyLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Share Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: kTitleColor,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: kTitleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Card
            Screenshot(
              controller: _screenshotController,
              child: _buildProfileCard(theme),
            ),
            const SizedBox(height: 40),
            // Action Buttons
            _buildActionButtons(theme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }



  Widget _buildProfileCard(ThemeData theme) {

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient background with avatar
          // Container(
          //   width: double.infinity,
          //   padding: const EdgeInsets.only(top: 40, bottom: 20),
          //   decoration: BoxDecoration(
          //     borderRadius: BorderRadius.only(
          //       topLeft: Radius.circular(20),
          //       topRight: Radius.circular(20),
          //     ),
          //     gradient: LinearGradient(
          //       begin: Alignment.topLeft,
          //       end: Alignment.topRight,
          //       colors: [
          //         Color(0xFFFFE4E6),
          //         Color(0xFFE9D5FF),
          //       ],
          //     ),
          //   ),
          //   child: Column(
          //     children: [
          //       // Profile Picture
          //       Container(
          //         width: 100,
          //         height: 100,
          //         decoration: BoxDecoration(
          //           shape: BoxShape.circle,
          //           border: Border.all(
          //             color: Colors.white,
          //             width: 4,
          //           ),
          //         ),
          //         child: ClipOval(
          //           child: _userInfo?.picture != null && _userInfo!.picture!.isNotEmpty
          //               ? ChuChuCachedNetworkImage(
          //                   imageUrl: _userInfo!.picture!,
          //                   fit: BoxFit.cover,
          //                   width: 100,
          //                   height: 100,
          //                   placeholder: (_, __) => FeedWidgetsUtils.badgePlaceholderImage(),
          //                   errorWidget: (_, __, ___) => FeedWidgetsUtils.badgePlaceholderImage(),
          //                 )
          //               : FeedWidgetsUtils.badgePlaceholderImage(),
          //         ),
          //       ),
          //       const SizedBox(height: 20),
          //       // Name
          //       Text(
          //         _getDisplayName(),
          //         style: GoogleFonts.inter(
          //           fontWeight: FontWeight.bold,
          //           fontSize: 24,
          //           color: kTitleColor,
          //         ),
          //       ),
          //       const SizedBox(height: 8),
          //       // Npub
          //       Text(
          //         _getTruncatedNpub(),
          //         style: GoogleFonts.inter(
          //           fontSize: 14,
          //           color: theme.colorScheme.onSurfaceVariant,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // QR Code Section

          Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient banner at top
              _relayGroup == null || _relayGroup!.picture.isEmpty
                  ? pictureView
                  : ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: ChuChuCachedNetworkImage(
                  imageUrl: _relayGroup!.picture,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => pictureView,
                  errorWidget: (context, url, error) => pictureView,
                  height: 200,
                  width: double.infinity,
                ),
              ),
              // Profile picture overlapping banner
              ValueListenableBuilder<UserDBISAR>(
                valueListenable: Account.sharedInstance.getUserNotifier(
                  widget.pubkey,
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
                                _relayGroup?.name ?? _getDisplayName(),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kTitleColor,
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Bio
                    if (_relayGroup != null && _relayGroup!.about.isNotEmpty)
                      Text(
                        _relayGroup!.about,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: _npub != null
                      ? QrImageView(
                    data: _npub!,
                    version: QrVersions.auto,
                    size: 188,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    errorStateBuilder: (context, error) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'QR Error',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                      : Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 16),
                Text(
                  'SCAN TO FOLLOW',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.copy,
            label: 'Copy Link',
            onTap: _copyLink,
          ),
          _buildActionButton(
            icon: Icons.download,
            label: 'Save Image',
            onTap: _saveImage,
          ),
          _buildActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: _share,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: kTitleColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kTitleColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortNpub(String pubkey) {
    if (pubkey.length < 12) return pubkey;
    return '${pubkey.substring(0, 6)}...${pubkey.substring(pubkey.length - 6)}';
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
}

