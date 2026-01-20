import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:chuchu/core/theme/app_theme.dart';
import 'package:chuchu/core/utils/ui_refresh_mixin.dart';
import 'package:chuchu/core/utils/navigator/navigator.dart';
import 'package:chuchu/presentation/home/pages/home_page.dart';
import 'package:chuchu/presentation/login/pages/register_form.dart';
import 'package:chuchu/core/account/account.dart';
import 'package:chuchu/core/account/account+nip46.dart';
import 'package:chuchu/core/manager/chuchu_user_info_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/chuchu_Loading.dart';
import 'package:chuchu/core/account/model/userDB_isar.dart';
import 'package:chuchu/core/account/secure_account_storage.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import '../../../core/widgets/common_toast.dart';
// Conditional import for Platform class
import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart'
    show Platform;
import 'package:nostr_core_dart/nostr.dart';
import 'package:nostr_core_dart/src/signer/signer_config.dart';
import 'package:nostr_core_dart/src/channel/core_method_channel.dart';

class NewLoginPage extends StatefulWidget {
  const NewLoginPage({super.key});

  @override
  _NewLoginPageState createState() => _NewLoginPageState();
}

class _NewLoginPageState extends State<NewLoginPage> with ChuChuUIRefreshMixin {
  final TextEditingController _privateKeyController = TextEditingController();
  bool _isObscured = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isConnecting = false;
  NIP46ConnectionStatus? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _privateKeyController.addListener(_onTextChanged);
    // Set up NIP-46 connection status callback
    Account.sharedInstance.nip46connectionStatusCallback = (status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
          if (status == NIP46ConnectionStatus.connected) {
            _isConnecting = false;
          } else if (status == NIP46ConnectionStatus.disconnected) {
            _isConnecting = false;
          } else if (status == NIP46ConnectionStatus.connecting) {
            _isConnecting = true;
          }
        });
      }
    };
  }

  @override
  void dispose() {
    _privateKeyController.removeListener(_onTextChanged);
    _privateKeyController.dispose();
    // Clear callback
    Account.sharedInstance.nip46connectionStatusCallback = null;
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      // Clear error when user starts typing
      String currentText = _privateKeyController.text;
      if (_hasError && currentText.isNotEmpty) {
        _hasError = false;
        _errorMessage = '';
      }
    });
  }

  bool get _canLogin {
    final text = _privateKeyController.text.trim();
    if (text.isEmpty) return false;

    // Check if it's a bunker URI
    if (text.startsWith('bunker://') || text.startsWith('nostrconnect://')) {
      return true;
    }

    // Otherwise treat as nsec
    return true;
  }

  Future<void> _handleLogin() async {
    final text = _privateKeyController.text.trim();

    // Check if it's a bunker URI
    if (text.startsWith('bunker://') || text.startsWith('nostrconnect://')) {
      await _bunkerLogin(text);
    } else {
      await _nescLogin();
    }
  }

  Future<void> _nescLogin() async {
    final input = _privateKeyController.text.trim();

    // Validate input
    if (input.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please input private key';
      });
      return;
    }
    ChuChuLoading.show();
    try {
      final privKey = UserDBISAR.decodePrivkey(input);

      if (privKey == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid private key format';
        });
        ChuChuLoading.dismiss();
        return;
      }

      final pubKey = Account.getPublicKey(privKey);
      final ChuChuUserInfoManager instance =
          ChuChuUserInfoManager.sharedInstance;
      final currentUserPubKey = instance.currentUserInfo?.pubKey ?? '';

      await instance.initDB(pubKey);

      var userDB = await Account.sharedInstance.loginWithPriKey(privKey);
      if (userDB != null) {
        await SecureAccountStorage.savePrivateKey(privKey, pubkey: pubKey);
      }
      userDB = await instance.handleSwitchFailures(userDB, currentUserPubKey);

      if (userDB == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Login failed. Please check your credentials.';
        });
        ChuChuLoading.dismiss();
        return;
      }

      ChuChuUserInfoManager.sharedInstance.loginSuccess(userDB);
      ChuChuLoading.dismiss();
      ChuChuNavigator.pushReplacement(context, const HomePage());
    } catch (e) {
      ChuChuLoading.dismiss();
      setState(() {
        _hasError = true;
        _errorMessage = 'Login error: ${e.toString()}';
      });
    }
  }

  Future<void> _bunkerLogin(String uri) async {
    // Validate input
    if (uri.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please input bunker URI';
      });
      return;
    }

    if (!uri.startsWith('bunker://') && !uri.startsWith('nostrconnect://')) {
      setState(() {
        _hasError = true;
        _errorMessage =
            'Invalid URI format. Must start with bunker:// or nostrconnect://';
      });
      return;
    }

    try {
      setState(() {
        _isConnecting = true;
        _hasError = false;
        _errorMessage = '';
      });
      ChuChuLoading.show();
      // Initialize NIP-46 callbacks
      Account.sharedInstance.initNIP46Callback();

      // Login with bunker URI using extension method
      final userDB = await Account.sharedInstance.loginWithNip46URI(uri);

      if (userDB == null) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage =
              'Failed to connect to remote signer. Please check your URI and try again.';
        });
        ChuChuLoading.dismiss();
        return;
      }

      // Initialize user info manager
      final ChuChuUserInfoManager instance =
          ChuChuUserInfoManager.sharedInstance;
      final currentUserPubKey = instance.currentUserInfo?.pubKey ?? '';
      await instance.initDB(userDB.pubKey);

      var finalUserDB = await instance.handleSwitchFailures(
        userDB,
        currentUserPubKey,
      );

      if (finalUserDB == null) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = 'Login failed. Please try again.';
        });
        ChuChuLoading.dismiss();
        return;
      }

      ChuChuUserInfoManager.sharedInstance.loginSuccess(finalUserDB);
      ChuChuLoading.dismiss();
      ChuChuNavigator.pushReplacement(context, const HomePage());
    } catch (e) {
      ChuChuLoading.dismiss();
      setState(() {
        _isConnecting = false;
        _hasError = true;
        _errorMessage = 'Connection error: ${e.toString()}';
      });
    }
  }

  Future<void> _handleSignerLogin() async {
    // NIP-55 login: Use external signer app to get public key
    if (!Platform.isAndroid) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Signer login is only available on Android';
      });
      return;
    }

    // Show signer selection dialog
    String? selectedSignerKey = await _showSignerSelectionDialog();
    if (selectedSignerKey == null) {
      return; // User cancelled
    }

    try {
      setState(() {
        _isConnecting = true;
        _hasError = false;
        _errorMessage = '';
      });

      // Initialize external signer tool
      await ExternalSignerTool.initialize();

      // Set selected signer
      await ExternalSignerTool.setSigner(selectedSignerKey);

      // Get public key from external signer app (this will launch the signer app)
      String? pubkey = await ExternalSignerTool.getPubKey();

      if (pubkey == null || pubkey.isEmpty) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = 'Failed to get public key from signer app';
        });
        return;
      }

      // Convert npub to hex if needed
      String hexPubkey = pubkey;
      if (pubkey.startsWith('npub')) {
        String? decoded = UserDBISAR.decodePubkey(pubkey);
        if (decoded == null || decoded.isEmpty) {
          setState(() {
            _isConnecting = false;
            _hasError = true;
            _errorMessage = 'Failed to decode npub format';
          });
          return;
        }
        hexPubkey = decoded;
      }

      // Login with the public key using androidSigner
      final ChuChuUserInfoManager instance =
          ChuChuUserInfoManager.sharedInstance;
      final currentUserPubKey = instance.currentUserInfo?.pubKey ?? '';
      await instance.initDB(hexPubkey);

      var userDB = await Account.sharedInstance.loginWithPubKey(
        hexPubkey,
        SignerApplication.androidSigner,
        androidSignerKey: selectedSignerKey,
      );
      userDB = await instance.handleSwitchFailures(userDB, currentUserPubKey);

      if (userDB == null) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = 'Login failed. Please try again.';
        });
        return;
      }

      ChuChuUserInfoManager.sharedInstance.loginSuccess(userDB);
      if (mounted) {
        ChuChuNavigator.pushReplacement(context, const HomePage());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = 'Signer login error: ${e.toString()}';
        });
      }
    }
  }

  Future<String?> _showSignerSelectionDialog() async {
    // Get all available signer configurations
    Map<String, SignerConfig> allConfigs = SignerConfigs.getAllConfigs();
    List<MapEntry<String, SignerConfig>> verifiedSigners = [];
    List<MapEntry<String, SignerConfig>> allSigners =
        allConfigs.entries.toList();

    // Try to check which signers are installed (but don't rely on it 100%)
    for (var entry in allConfigs.entries) {
      try {
        bool isInstalled = await CoreMethodChannel.isAppInstalled(
          entry.value.packageName,
        );
        if (isInstalled) {
          verifiedSigners.add(entry);
        }
      } catch (e) {
        // Ignore errors in detection
      }
    }

    // If we found verified signers, use them; otherwise show all signers
    // (Android Intent will handle the actual selection if app is not installed)
    List<MapEntry<String, SignerConfig>> signersToShow =
        verifiedSigners.isNotEmpty ? verifiedSigners : allSigners;

    // If only one signer to show, use it directly
    if (signersToShow.length == 1) {
      return signersToShow.first.key;
    }

    // Show selection dialog with all signers
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Signer App'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: signersToShow.length,
              itemBuilder: (context, index) {
                final entry = signersToShow[index];
                final config = entry.value;
                return Column(
                  children: [
                    ListTile(
                      title: Text(config.displayName),
                      onTap: () {
                        Navigator.of(context).pop(entry.key);
                      },
                    ),
                    if (index < signersToShow.length - 1)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionStatus() {
    String statusText = '';
    Color statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
    IconData statusIcon = Icons.info_outline;

    switch (_connectionStatus) {
      case NIP46ConnectionStatus.connecting:
        statusText = 'Connecting...';
        statusColor = Theme.of(context).colorScheme.primary;
        statusIcon = Icons.sync;
        break;
      case NIP46ConnectionStatus.connected:
        statusText = 'Connected';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case NIP46ConnectionStatus.waitingForSigning:
        statusText = 'Waiting for approval...';
        statusColor = Theme.of(context).colorScheme.primary;
        statusIcon = Icons.hourglass_empty;
        break;
      case NIP46ConnectionStatus.approvedSigning:
        statusText = 'Approved';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case NIP46ConnectionStatus.disconnected:
        statusText = 'Disconnected';
        statusColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.error_outline;
        break;
      default:
        break;
    }

    return Row(
      children: [
        Icon(statusIcon, size: 16, color: statusColor),
        SizedBox(width: 8),
        Text(statusText, style: TextStyle(fontSize: 12, color: statusColor)),
      ],
    );
  }

  void _handleCreateAccount() {
    // Use pageName: null to prevent URL hash from being added in web
    ChuChuNavigator.pushPage(
      context,
      (context) => RegisterForm(),
      pageName: null, // Prevent route name in URL for web
    );
  }

  void _handleGuestMode() {
    // TODO: Implement guest mode
    CommonToast.instance.show(context, 'Guest mode coming soon', toastType: ToastType.info);
  }

  @override
  Widget buildBody(BuildContext context) {
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
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),

                                // NOSTR RELAY CONNECTED status indicator
                                // _buildStatusIndicator(),

                                // const SizedBox(height: 40),

                                // Container wrapping logo, input, and create account
                                Container(
                                  padding: const EdgeInsets.only(
                                    left: 24,
                                    right: 24,
                                    top: 50,
                                    bottom: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Column(
                                        children: [
                                          // App icon with gradient background
                                          _buildAppIcon(),

                                          const SizedBox(height: 8),

                                          // App name
                                          CommonImage(
                                            iconName: 'ChuChu_pink.png',
                                            width: 150,
                                          ),
                                          const SizedBox(height: 20),

                                          // Tagline
                                          Text(
                                            'Support creativity. Pay lightning-fast.',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),

                                          const SizedBox(height: 32),

                                          // Tagline with decorative lines
                                          _buildTagline(),

                                          const SizedBox(height: 32),

                                          // Input field
                                          _buildInputField(),

                                          if (_hasError) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _errorMessage,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 24),

                                          // Create Account button
                                          _buildCreateAccountButton(),

                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                      // Disclaimer text
                                      Text(
                                        'By connecting, you agree to the terms of service',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: theme.colorScheme.outline,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Powered by Nostr
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CommonImage(
                                      iconName: 'lighting_icon.png',
                                      color: Colors.black.withAlpha(50),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Powered by Nostr',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.black.withAlpha(50),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green[600],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'NOSTR RELAY CONNECTED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    return Center(
      child: CommonImage(
        iconName: 'logo_bg.png',
        size: 150,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTagline() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.withOpacity(0.3)],
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OPEN PROTOCOL',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.withOpacity(0.3), Colors.white],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField() {
    final theme = Theme.of(context);
    final isBunkerUri =
        _privateKeyController.text.trim().startsWith('bunker://') ||
        _privateKeyController.text.trim().startsWith('nostrconnect://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: kBgLight,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hasError ? Colors.red[400]! : Color(0xFFE2E8F0),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              CommonImage(
                iconName: 'key_icon.png',
                size: 20,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _privateKeyController,
                  obscureText: !isBunkerUri && _isObscured,

                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kTitleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'nsec1... or bunker://',
                    hintStyle: GoogleFonts.inter(
                      color: theme.colorScheme.outline,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_privateKeyController.text.isNotEmpty) ...[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _privateKeyController.clear();
                      _hasError = false;
                      _errorMessage = '';
                    });
                  },
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[400],
                    ),
                    child: Icon(Icons.close, size: 12, color: Colors.white),
                  ),
                ),
              ],
              if (!isBunkerUri) ...[
                IconButton(
                  icon: Icon(
                    _isObscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey[500],
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscured = !_isObscured;
                    });
                  },
                ),
              ],
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: _canLogin ? getBrandGradientHorizontal() : null,
                  color: _canLogin ? null : Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: GestureDetector(
                  onTap: _canLogin && !_isConnecting ? _handleLogin : null,
                  child: Center(
                    child: CommonImage(
                      iconName: 'arrow_right_icon.png',
                      size: 20,
                      color: _canLogin ? Colors.white : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Connection status indicator (show when input is bunker URI)
        if (_connectionStatus != null &&
            (_privateKeyController.text.trim().startsWith('bunker://') ||
                _privateKeyController.text.trim().startsWith(
                  'nostrconnect://',
                ))) ...[
          SizedBox(height: 12),
          _buildConnectionStatus(),
        ],
      ],
    );
  }

  Widget _buildCreateAccountButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.2),
            blurRadius: 4,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _handleCreateAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFFDF2F8), // Light pink background
          foregroundColor: kPrimary, // Pink text color
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          'Create Account',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActionOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _handleCreateAccount,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Create Account',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
