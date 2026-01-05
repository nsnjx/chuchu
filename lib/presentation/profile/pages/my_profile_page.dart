import 'dart:typed_data';
import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as Path;
import 'package:google_fonts/google_fonts.dart';

import '../../../core/account/web_file_registry_stub.dart'
    if (dart.library.html) 'package:chuchu/core/account/web_file_registry.dart'
    as web_file_registry;

import '../../../core/account/account.dart';
import '../../../core/account/account+profile.dart';
import '../../../core/account/model/userDB_isar.dart';
import '../../../core/manager/chuchu_user_info_manager.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_image.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/services/blossom_uploader.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../core/widgets/common_edit_field_dialog.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/storage_key_tool.dart';
import '../../../core/manager/cache/chuchu_cache_manager.dart';
import '../../../core/utils/navigator/navigator.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/widgets/logout_confirm_dialog.dart';
import '../../login/pages/new_login_page.dart';
import '../../nostrKey/pages/nostr_key_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage>
    with ChuChuUIRefreshMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  String? _selectedAvatarPath; // Local file path for display
  Uint8List? _selectedAvatarBytes; // In-memory image data for web preview
  String? _uploadedAvatarUrl; // Network URL after upload (used when confirming)
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final userInfo = ChuChuUserInfoManager.sharedInstance.currentUserInfo;
    if (userInfo != null) {
      // Use name field first, fallback to nickName if name is empty
      _nameController.text =
          (userInfo.name?.isNotEmpty == true)
              ? userInfo.name!
              : (userInfo.nickName ?? '');
      _aboutController.text = userInfo.about ?? '';
    }
  }

  @override
  void dispose() {
    if (_selectedAvatarPath != null &&
        _selectedAvatarPath!.startsWith('webfile://')) {
      web_file_registry.unregisterWebFileData(_selectedAvatarPath!);
    }
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgLight,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Center(
            child: CommonImage(
              iconName: 'back_arrow_icon.png',
              size: 24,
              color: Colors.black,
            ),
          ),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            color: kTitleColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        elevation: 0,
        backgroundColor: kBgLight,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 32),
              _buildSectionTitle('PROFILE INFO'),
              const SizedBox(height: 4),
              _buildProfileInfoCard(),
              const SizedBox(height: 24),
              _buildSectionTitle('SECURITY'),
              const SizedBox(height: 4),
              _buildOtherInfoCard(),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 16),
              _buildVersionInfo(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kTitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Text(
      'Version 0.0.3',
      style: GoogleFonts.inter(
        fontSize: 14,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _changeProfilePicture,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        // Show selected local image, existing picture, or placeholder
                        ValueListenableBuilder<UserDBISAR>(
                          valueListenable: Account.sharedInstance
                              .getUserNotifier(
                            Account.sharedInstance.currentPubkey,
                          ),
                          builder: (context, user, child) {
                            // Always prioritize local image if available
                            // This ensures smooth experience without any flash of default image
                            // Local image will be used until user selects a new one or page is refreshed
                            if (_selectedAvatarBytes != null) {
                              return Image.memory(
                                _selectedAvatarBytes!,
                                fit: BoxFit.cover,
                                width: 100,
                                height: 100,
                              );
                            } else if (user.picture != null &&
                                user.picture!.isNotEmpty) {
                              return ChuChuCachedNetworkImage(
                                imageUrl: user.picture!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, __) => ClipOval(
                                      child:
                                          FeedWidgetsUtils.badgePlaceholderImage(
                                            size: 100,
                                          ),
                                    ),
                                errorWidget:
                                    (_, __, ___) => ClipOval(
                                      child:
                                          FeedWidgetsUtils.badgePlaceholderImage(
                                            size: 100,
                                          ),
                                ),
                                width: 100,
                                height: 100,
                              );
                            } else {
                              return ClipOval(
                                child: FeedWidgetsUtils.badgePlaceholderImage(
                                  size: 100,
                                ),
                              );
                            }
                          },
                        ),
                        // Show loading overlay when uploading
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.5),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Camera icon overlay on bottom right (outside ClipOval)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E3A5F), // Dark blue
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Show confirm/cancel buttons if avatar is uploaded, otherwise show "Tap to change photo" text
          if (_uploadedAvatarUrl != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: GestureDetector(
                    onTap: _cancelAvatarUpdate,
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    gradient: getBrandGradientHorizontal(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                    onTap: _confirmAvatarUpdate,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                    child: Text(
                      'Confirm',
                      style: GoogleFonts.inter(
                            color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
          Text(
            'Tap to change photo',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            iconName: 'user_ill_icon.png',
            label: 'Nickname',
            value: _nameController.text.isNotEmpty ? _nameController.text : '',
            onTap: () => _editField('Nickname', _nameController),
            isShowUnderline: true,
          ),
          _buildInfoRow(
            iconName: 'bio_icon.png',
            label: 'Bio',
            value:
                _aboutController.text.isNotEmpty ? _aboutController.text : '',
            onTap: () => _editField('Bio', _aboutController),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            iconName: 'keys_icon.png',
            label: 'Nostr Keys',
            value: 'Manage your private & public keys',
            onTap: () => _navigateToBackup(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String iconName,
    required String label,
    required String value,
    required VoidCallback onTap,
    isShowUnderline = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration:
            isShowUnderline
                ? BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 0.5,
              color: Theme.of(context).dividerColor.withOpacity(0.15),
            ),
          ),
                )
                : null,
        child: Row(
          children: [
            CommonImage(iconName: iconName, width: 40, height: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (value.isNotEmpty)
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTitleColor,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _editField(String fieldName, TextEditingController controller) {
    final isNickname = fieldName == 'Nickname';

    CommonEditFieldDialog.show(
      context: context,
      title: 'Edit $fieldName',
      initialValue: controller.text,
      hintText: isNickname ? 'Your display name' : 'Tell us about yourself',
      instructionText: 'Update your $fieldName to personalize your profile',
      headerIcon: CommonImage(
        iconName: isNickname ? 'user_ill_icon.png' : 'bio_icon.png',
        size: 30,
      ),

      maxLines: isNickname ? 1 : 3,
      onSave: (newValue) async {
        try {
          // Get current user info
          final currentUserInfo =
              ChuChuUserInfoManager.sharedInstance.currentUserInfo;
          if (currentUserInfo == null) {
            _showErrorSnackBar(
              'Unable to update $fieldName. Please try again later.',
            );
            return false;
          }

          // Create updated user info using the new value
          if (isNickname) {
            currentUserInfo.name = newValue.trim();
          } else {
            currentUserInfo.about = newValue.trim();
          }

          // Update profile through Account
          final result = await Account.sharedInstance.updateProfile(
            currentUserInfo,
          );

          // Check if the update was successful
          if (result == null) {
            throw Exception('Failed to update profile - no data returned');
          }

          // Update ChuChuUserInfoManager's currentUserInfo
          ChuChuUserInfoManager.sharedInstance.currentUserInfo = result;

          // Update local controllers
          if (isNickname) {
            _nameController.text = newValue;
          } else {
            _aboutController.text = newValue;
          }

          // Show success message
          CommonToast.instance.show(context, '$fieldName updated successfully!', toastType: ToastType.success);

          // Refresh UI
          setState(() {});
          return true;
        } catch (e, stackTrace) {
          // Print detailed error for debugging
          debugPrint('Error updating $fieldName: $e');
          debugPrint('Stack trace: $stackTrace');

          // Show user-friendly error message
          _showErrorSnackBar(
            'Failed to update $fieldName. Please check your connection and try again.',
          );
          return false;
        }
      },
    );
  }

  Future<void> _changeProfilePicture() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (kIsWeb) {
          final virtualPath = web_file_registry.createVirtualFilePath(
            picked.name,
          );
          web_file_registry.registerWebFileData(virtualPath, bytes);
          // Clean up previous virtual file if exists
          if (_selectedAvatarPath != null &&
              _selectedAvatarPath!.startsWith('webfile://')) {
            web_file_registry.unregisterWebFileData(_selectedAvatarPath!);
          }
          setState(() {
            _selectedAvatarPath = virtualPath;
            _selectedAvatarBytes = bytes;
            _uploadedAvatarUrl =
                null; // Clear previous uploaded URL when selecting new image
          });
        } else {
          setState(() {
            _selectedAvatarPath = picked.path;
            _selectedAvatarBytes = bytes;
            _uploadedAvatarUrl =
                null; // Clear previous uploaded URL when selecting new image
          });
        }
        
        // Wait for the next frame to ensure state is updated before uploading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _uploadAvatar();
        });
      }
    } catch (e, stackTrace) {
      // Print detailed error for debugging
      debugPrint('Error picking avatar: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show user-friendly error message
      _showErrorSnackBar('Unable to select photo. Please try again.');
    }
  }

  // Upload avatar image
  Future<void> _uploadAvatar() async {
    if (_selectedAvatarPath == null || _isUploadingAvatar) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      String uploadFilePath;
      String fileName;
      
      if (kIsWeb || _selectedAvatarPath!.startsWith('webfile://')) {
        // For web platform, use the virtual path directly
        // BolssomUploader will handle webfile:// paths internally
        uploadFilePath = _selectedAvatarPath!;
        fileName = uploadFilePath.split('/').last;
      } else {
        // For non-web platforms, remove EXIF and use processed file
        final imageFile = File(_selectedAvatarPath!);
        final processed = await _removeExifWithCompress(imageFile);
        uploadFilePath = (processed ?? imageFile).path;
        fileName = uploadFilePath.split('/').last;
      }
      
      final imageUrl = await BolssomUploader.upload(
        'https://blossom.band',
        uploadFilePath,
        fileName: fileName,
      );

      if (imageUrl != null && mounted) {
        // Save uploaded URL, but don't update profile yet - wait for user confirmation
        setState(() {
          _uploadedAvatarUrl = imageUrl;
        });
        CommonToast.instance.show(
          context,
          'Avatar uploaded successfully. Please confirm to update.',
            toastType:ToastType.success
        );
      } else {
        throw Exception('Upload returned empty URL');
      }
    } catch (e, stackTrace) {
      // Print detailed error for debugging
      debugPrint('Error uploading avatar: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        // Show user-friendly error message
        _showErrorSnackBar(
          'Failed to upload photo. Please check your network connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  // Remove EXIF metadata (including GPS) by re-compressing the image
  Future<File?> _removeExifWithCompress(File file) async {
    try {
      final targetPath = Path.join(
        Path.dirname(file.path),
        '${Path.basenameWithoutExtension(file.path)}_noexif.jpg',
      );
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 95,
      );
      return result != null ? File(result.path) : null;
    } catch (_) {
      return null;
    }
  }

  // Confirm avatar update - actually update the profile
  Future<void> _confirmAvatarUpdate() async {
    if (_uploadedAvatarUrl == null) return;
    
    try {
      final uploadedUrl = _uploadedAvatarUrl!;
      await _updateUserAvatar(uploadedUrl);
      
      // Clear uploaded URL to hide confirm/cancel buttons
      // But keep local image bytes to continue showing local image
      // This prevents any flash of default image or network loading
      if (mounted) {
        setState(() {
          _uploadedAvatarUrl = null;
          // Keep _selectedAvatarBytes and _selectedAvatarPath to continue using local image
        });
      }
      
      CommonToast.instance.show(context, 'Avatar updated successfully',toastType:ToastType.success);
    } catch (e, stackTrace) {
      // Print detailed error for debugging
      debugPrint('Error confirming avatar update: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show user-friendly error message
      if (mounted) {
        _showErrorSnackBar('Failed to update avatar. Please try again.');
      }
    }
  }

  // Cancel avatar update - clear uploaded URL and selected image
  void _cancelAvatarUpdate() {
    if (_selectedAvatarPath != null &&
        _selectedAvatarPath!.startsWith('webfile://')) {
      web_file_registry.unregisterWebFileData(_selectedAvatarPath!);
    }
    setState(() {
      _selectedAvatarPath = null;
      _selectedAvatarBytes = null;
      _uploadedAvatarUrl = null;
    });
  }

  // Update user avatar in profile
  Future<void> _updateUserAvatar(String imageUrl) async {
    try {
      // Get current user info
      final currentUserInfo =
          ChuChuUserInfoManager.sharedInstance.currentUserInfo;
      if (currentUserInfo == null) {
        debugPrint('Error: User info not found when updating avatar');
        _showErrorSnackBar('Unable to update avatar. Please try again later.');
        return;
      }

      // Update picture field
      currentUserInfo.picture = imageUrl;
      debugPrint('📸 Updating avatar with URL: $imageUrl');
      
      // Update profile through Account
      final result = await Account.sharedInstance.updateProfile(
        currentUserInfo,
      );
      
      if (result != null) {
        debugPrint('✅ Avatar updated successfully. Picture URL: ${result.picture}');
        // Update ChuChuUserInfoManager's currentUserInfo
        ChuChuUserInfoManager.sharedInstance.currentUserInfo = result;
      } else {
        debugPrint('❌ Failed to update profile - updateProfile returned null');
        throw Exception('Failed to update profile');
      }
    } catch (e, stackTrace) {
      // Print detailed error for debugging
      debugPrint('Error updating user avatar: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Show user-friendly error message
      _showErrorSnackBar(
        'Failed to update avatar. Please check your connection and try again.',
      );
      rethrow; // Re-throw to let caller handle if needed
    }
  }

  void _navigateToBackup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const NostrKeyPage()));
  }

  void _showErrorSnackBar(String message) {
    CommonToast.instance.show(context, message, toastType: ToastType.failed);
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => LogoutConfirmDialog.show(context, closeDrawer: false),
            borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFFFE4E6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
                Icon(Icons.logout, size: 20, color: Colors.red[600]),
            const SizedBox(width: 8),
            Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
