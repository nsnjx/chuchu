import 'package:chuchu/core/relayGroups/model/relayGroupDB_isar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/account/account.dart';
import '../../../core/account/account+profile.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/config/config.dart' as AppConfig;
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/relayGroups/relayGroup+info.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';

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
  RelayGroupDBISAR? _relayGroup;
  String? _npub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
    _loadUserInfo();
  }

  void _loadFromDatabase() {
    final pubkey = widget.pubkey;
    final npub = Nip19.encodePubkey(pubkey);
    RelayGroupDBISAR? relayGroup = RelayGroup.sharedInstance.groups[pubkey]?.value;
    
    setState(() {
      _npub = npub;
      _relayGroup = relayGroup;
      _isLoading = false;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final pubkey = widget.pubkey;
      UserDBISAR? userInfo = await Account.sharedInstance.getUserInfo(pubkey);
      
      if (userInfo != null) {
        try {
          await Account.sharedInstance.reloadProfileFromRelay(pubkey);
        } catch (e) {
          // Ignore
        }
      }

      try {
        final relayGroup = await RelayGroup.sharedInstance
            .getGroupMetadataFromRelay(
          pubkey,
          relay:  AppConfig.Config.sharedInstance.recommendGroupRelays.first,
          author: pubkey,
        );
        if (mounted) {
          setState(() {
            _relayGroup = relayGroup;
          });
        }
      } catch (e) {
        // Ignore
      }
    } catch (e) {
      // Ignore
    }
  }

  String _getDisplayNameFromUser(UserDBISAR userInfo) {
    if (userInfo.name != null && userInfo.name!.isNotEmpty) {
      return userInfo.name!;
    }
    if (userInfo.nickName != null && userInfo.nickName!.isNotEmpty) {
      return userInfo.nickName!;
    }
    if (_npub != null && _npub!.length >= 12) {
      return '${_npub!.substring(0, 6)}...${_npub!.substring(_npub!.length - 6)}';
    }
    return '--';
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
    return CommonToast.instance.show(context, 'Comming soon', toastType: ToastType.info);
    if (_npub == null) {
      if (mounted) {
        CommonToast.instance.show(context, 'Profile not loaded', toastType: ToastType.failed);
      }
      return;
    }

    try {
      final userInfo = await Account.sharedInstance.getUserInfo(widget.pubkey);
      
      String name = _relayGroup?.name ??
          (userInfo?.name ?? userInfo?.nickName ?? 'User');
      
      String avatar = _relayGroup?.picture.isNotEmpty == true
          ? _relayGroup!.picture 
          : (userInfo?.picture ?? '');
      
      final shareLink = 'http://192.168.2.175:3000/invite?name=${Uri.encodeComponent(name)}&npub=${Uri.encodeComponent(_npub!)}&avatar=${Uri.encodeComponent(avatar)}&scheme=${Uri.encodeComponent('chuchu://')}';
      
      await Share.share(
        shareLink,
        subject: 'Share My Posts',
      );
    } catch (e) {
      if (mounted) {
        CommonToast.instance.show(context, 'Failed to share link', toastType: ToastType.failed);
      }
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Screenshot(
                    controller: _screenshotController,
                    child: _buildProfileCard(theme),
                  ),
                  const SizedBox(height: 40),
                  _buildActionButtons(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    const double bannerHeight = 120.0;
    const double avatarSize = 100.0;
    const double avatarBorderWidth = 3.0;

    Widget pictureView = Container(
      height: bannerHeight,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: bannerHeight + (avatarSize / 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
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
                          height: bannerHeight,
                          width: double.infinity,
                        ),
                      ),
                ValueListenableBuilder<UserDBISAR>(
                  valueListenable: Account.sharedInstance.getUserNotifier(
                    widget.pubkey,
                  ),
                  builder: (context, userInfo, child) {
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: bannerHeight - avatarSize / 2,
                      child: Center(
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: avatarBorderWidth),
                          ),
                          child: ClipOval(
                            child: userInfo.picture != null &&
                                    userInfo.picture!.isNotEmpty
                                ? ChuChuCachedNetworkImage(
                                    imageUrl: userInfo.picture!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => CommonImage(
                                      iconName: 'icon_user_default.png',
                                      width: avatarSize,
                                      height: avatarSize,
                                    ),
                                    errorWidget: (context, url, error) => CommonImage(
                                      iconName: 'icon_user_default.png',
                                      width: avatarSize,
                                      height: avatarSize,
                                    ),
                                    width: avatarSize,
                                    height: avatarSize,
                                  )
                                : CommonImage(
                                    iconName: 'icon_user_default.png',
                                    width: avatarSize,
                                    height: avatarSize,
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: ValueListenableBuilder<UserDBISAR>(
              valueListenable: Account.sharedInstance.getUserNotifier(
                widget.pubkey,
              ),
              builder: (context, userInfo, child) {
                String displayName = _relayGroup?.name ?? _getDisplayNameFromUser(userInfo);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kTitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    if (_relayGroup != null && _relayGroup!.about.isNotEmpty)
                      Text(
                        _relayGroup!.about,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30),
            child: Column(
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: _npub != null
                      ? QrImageView(
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black,
                          ),
                          data: _npub!,
                          version: QrVersions.auto,
                          size: 188,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          errorStateBuilder: (context, error) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text(
                                    'QR Error',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 16),
                Text(
                  'SCAN TO VIEW CREATOR',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kTitleColor,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionButton(
            iconName: 'copy_icon.png',
            label: 'Copy npub',
            onTap: _copyLink,
            theme: theme,
          ),
          _buildActionButton(
            iconName: 'down_image_icon.png',
            label: 'Save Image',
            onTap: _saveImage,
            theme: theme,
          ),
          _buildActionButton(
            iconName: 'share_icon.png',
            label: 'Share',
            onTap: _share,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String iconName,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
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
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: CommonImage(
                iconName: iconName,
                size: 24,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kTitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

