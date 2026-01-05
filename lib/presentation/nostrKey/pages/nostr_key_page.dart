import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/account/account.dart';
import '../../../core/manager/chuchu_user_info_manager.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../core/theme/app_theme.dart';

class NostrKeyPage extends StatefulWidget {
  const NostrKeyPage({super.key});

  @override
  State<NostrKeyPage> createState() => _NostrKeyPageState();
}

class _NostrKeyPageState extends State<NostrKeyPage> with ChuChuUIRefreshMixin {
  bool _isPrivateKeyVisible = false;
  
  String get _npubKey {
    final userInfo = ChuChuUserInfoManager.sharedInstance.currentUserInfo;
    if (userInfo == null) return '';
    return Nip19.encodePubkey(userInfo.pubKey);
  }
  
  String get _privateKey {
    return Account.sharedInstance.currentPrivkey;
  }
  
  String get _nsecKey {
    if (_privateKey.isEmpty) return '';
    return Nip19.encodePrivkey(_privateKey);
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
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
          'Nostr Keys',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityWarning(),
            SizedBox(height: 24),
            _buildKeySection(
              theme: theme,
              title: 'Public Key (npub)',
              subtitle: 'Your public identity. Safe to share.',
              value: _npubKey,
              dotColor: Colors.green,
              isPrivate: false,
            ),
            SizedBox(height: 30),
            _buildKeySection(
              theme: theme,
              title: 'Private Key (nsec)',
              subtitle: '',
              value: _nsecKey,
              dotColor: Colors.red,
              isPrivate: true,
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityWarning() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWarningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kWarningBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: kWarningIcon,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Warning',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kWarningText,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Never share your private key (nsec) with anyone. If you lose it, you will lose access to your account forever.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kWarningText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeySection({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String value,
    required Color dotColor,
    bool isPrivate = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTitleColor,
              ),
            ),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
        SizedBox(height: 2),
        if (isPrivate && !_isPrivateKeyVisible)
          // Show reveal button when private key is hidden
          GestureDetector(
            onTap: () {
              setState(() {
                _isPrivateKeyVisible = true;
              });
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CommonImage(
                      iconName: 'key_icon.png',
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reveal Secret Key',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          // Show key content when visible or for public key
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isPrivate ? kBgDark : kBgLight,
              borderRadius: BorderRadius.circular(12),
              border: !isPrivate ? Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ) : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isPrivate ? Colors.white : kTitleColor,
                      height: 1.4,
                      letterSpacing: 0.5,
                    ).copyWith(fontFamily: 'monospace'),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: value.isEmpty ? null : () => _copyToClipboard(value, title),
                  child: CommonImage(
                    iconName: 'copy_bg_white_icon.png',
                    size: 50,
                  ),
                ),
              ],
            ),
          ),
        if (isPrivate && _isPrivateKeyVisible) ...[
          SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isPrivateKeyVisible = false;
              });
            },
            child: Text(
              'Hide key',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }


  void _copyToClipboard(String text, String keyType) {
    if (text.isEmpty) return;
    
    Clipboard.setData(ClipboardData(text: text));
    CommonToast.instance.show(context, '$keyType copied to clipboard', toastType: ToastType.success);
  }
} 