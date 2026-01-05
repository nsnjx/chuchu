import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:chuchu/core/utils/navigator/navigator.dart';
import 'package:chuchu/core/account/account.dart';
import 'package:chuchu/core/account/account+profile.dart';
import 'package:chuchu/core/account/model/userDB_isar.dart';
import 'package:chuchu/core/manager/chuchu_user_info_manager.dart';
import 'package:nostr_core_dart/src/keychain.dart';
import 'package:nostr_core_dart/src/nips/nip_019.dart';
import '../../../core/account/secure_account_storage.dart';
import '../../../core/widgets/chuchu_Loading.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
import '../../home/pages/home_page.dart';
import '../../../core/theme/app_theme.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  late Keychain _keychain;
  late String _pub;
  bool _hasBackedUp = false;

  @override
  void initState() {
    super.initState();
    _initRegisterMode();
  }

  void _initRegisterMode() {
    _keychain = Account.generateNewKeychain();
    _pub = Account.getPublicKey(_keychain.private);
  }

  String get _npub {
    return Nip19.encodePubkey(_pub);
  }

  String get _nsec {
    return Nip19.encodePrivkey(_keychain.private);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    CommonToast.instance.show(context, '$label copied to clipboard', toastType: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Base gradient background (light purple to white)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F0FF), // Very light lavender
                    Color(0xFFFAF5FF), // Lighter purple
                    Colors.white,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Top-left purple blur block
            Positioned(
              top: -screenSize.height * 0.3,
              left: -screenSize.width * 0.2,
              child: Container(
                width: screenSize.width * 1.2,
                height: screenSize.height * 0.8,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topLeft,
                    radius: 1.5,
                    colors: [
                      kTertiary.withOpacity(0.3),
                      kTertiary.withOpacity(0.18),
                      kTertiary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.2, 0.5, 1.0],
                  ),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
            // Bottom-right pink blur block
            Positioned(
              bottom: -screenSize.height * 0.3,
              right: -screenSize.width * 0.2,
              child: Container(
                width: screenSize.width * 1.2,
                height: screenSize.height * 0.8,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomRight,
                    radius: 1.5,
                    colors: [
                      kPrimary.withOpacity(0.3),
                      kPrimary.withOpacity(0.18),
                      kPrimary.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.2, 0.5, 1.0],
                  ),
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),
            // Content on top
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
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
                  'New Account',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kTitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                centerTitle: true,
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),

                    // Shield icon section
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CommonImage(
                          iconName: 'safe_bg.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Title
                    Center(
                      child: Text(
                        'Save your Secret Key',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: kTitleColor,
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    // Description
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(text: 'This key is the '),
                              TextSpan(
                                text: 'ONLY',
                                style: GoogleFonts.inter(
                                  color: kTitleColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' way to access your account. If you lose it, your account is gone forever.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 32),

                    // Key information card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Public key section
                                Text(
                                  'YOUR PUBLIC NAME (NPUB)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),

                                SizedBox(height: 8),

                                GestureDetector(
                                  onTap:
                                      () => _copyToClipboard(
                                        _npub,
                                        'Public key',
                                      ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kBgLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFF1F5F9),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _npub,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 24),

                                // Private key section
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: Colors.red[400],
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'PRIVATE KEY (SECRET)',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFB2C36),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 8),

                                GestureDetector(
                                  onTap:
                                      () => _copyToClipboard(
                                        _nsec,
                                        'Private key',
                                      ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFF5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Color(0xFFFFE5F5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _nsec,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 12),

                                // Copy instruction
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.red[300],
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tap to copy. Write this down in a safe place!',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.red[300],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Gradient top border
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: getBrandGradientHorizontal(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _hasBackedUp,
                          onChanged: (value) {
                            setState(() {
                              _hasBackedUp = value ?? false;
                            });
                          },
                          shape: CircleBorder(),
                          activeColor: kPrimary,
                        ),
                        Expanded(
                          child: Text(
                            'I have securely backed up my secret key',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Enter ChuChu button with gradient
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient:
                              _hasBackedUp
                                  ? getBrandGradientDiagonal()
                                  : null,
                          color: _hasBackedUp ? null : Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: ElevatedButton(
                          onPressed: _hasBackedUp ? _createAccount : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Enter ChuChu',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _createAccount() async {
    ChuChuLoading.show();
    String pubkey = Account.getPublicKey(_keychain.private);
    await ChuChuUserInfoManager.sharedInstance.initDB(pubkey);

    UserDBISAR userDB = await Account.newAccount(user: _keychain);

    userDB =
        await Account.sharedInstance.loginWithPriKey(_keychain.private) ??
        userDB;
    await SecureAccountStorage.savePrivateKey(
      _keychain.private,
      pubkey: _keychain.public,
    );

    Account.sharedInstance.updateProfile(userDB);
    await ChuChuUserInfoManager.sharedInstance.loginSuccess(userDB);
    ChuChuLoading.dismiss();
    ChuChuNavigator.pushReplacement(context, const HomePage());
  }
}
