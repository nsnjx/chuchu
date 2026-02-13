import 'dart:typed_data';
import 'dart:io'
    if (dart.library.html) 'package:chuchu/core/account/platform_stub.dart';
import 'package:chuchu/core/relayGroups/relayGroup+admin.dart';
import 'package:chuchu/core/widgets/common_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:ui';

import 'package:nostr_core_dart/src/ok.dart';
import '../../../core/relayGroups/model/relayGroupDB_isar.dart';
import '../../../core/relayGroups/relayGroup.dart';
import '../../../core/services/blossom_uploader.dart';
import '../../../core/utils/feed_widgets_utils.dart';
import '../../../core/utils/log_utils.dart';
import '../../../core/widgets/common_toast.dart';
import '../../../core/widgets/chuchu_cached_network_Image.dart';
import '../../../core/widgets/common_edit_field_dialog.dart';
import '../../../core/utils/ui_refresh_mixin.dart';
import '../../../core/account/web_file_registry_stub.dart'
    if (dart.library.html) 'package:chuchu/core/account/web_file_registry.dart'
    as web_file_registry;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/gradient_button.dart';

class ProfileEditPage extends StatefulWidget {
  final RelayGroupDBISAR relayGroup;
  const ProfileEditPage({super.key, required this.relayGroup});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage>
    with ChuChuUIRefreshMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  String?
  _selectedCoverPhotoPath; // Local/virtual file path for display & upload
  Uint8List?
  _selectedCoverPhotoBytes; // In-memory image for preview (web compatible)
  String? _uploadedCoverPhotoUrl; // Network URL after upload (used when saving)
  bool _isUploadingCoverPhoto = false;
  bool _isSavingCoverPhoto = false; // Track if cover photo is being saved to relay

  late RelayGroupDBISAR groupInfo;

  int subscriptionPrice = 0;
  late ValueNotifier<bool> _hasChangesNotifier;

  @override
  void initState() {
    super.initState();
    _hasChangesNotifier = ValueNotifier<bool>(false);
    getGroupInfo();
    _addListeners();
  }

  void _addListeners() {
    // Listen to text field changes
    _usernameController.addListener(_onFieldChanged);
    _aboutController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _hasChangesNotifier.value = _hasChanges();
  }

  // Check if relay group metadata has changed
  bool _hasGroupMetadataChanges() {
    final originalName = widget.relayGroup.name;
    final originalAbout = widget.relayGroup.about;
    final originalPicture = widget.relayGroup.picture;
    final originalSubscriptionAmount = widget.relayGroup.subscriptionAmount;
    
    final updatedName = _usernameController.text.trim();
    final updatedAbout = _aboutController.text.trim();
    // If user selected a new image (local path exists), consider it a change
    // Use uploaded URL if available for comparison, otherwise check if local path exists
    final hasPictureChange =
        _selectedCoverPhotoPath != null &&
        (_uploadedCoverPhotoUrl != originalPicture ||
            _uploadedCoverPhotoUrl == null);
    final updatedSubscriptionAmount = subscriptionPrice;
    
    // Check if any group metadata values have actually changed
    return updatedName != originalName ||
           updatedAbout != originalAbout ||
           hasPictureChange ||
           updatedSubscriptionAmount != originalSubscriptionAmount;
  }

  // Check if any values have changed (for UI state)
  bool _hasChanges() {
    return _hasGroupMetadataChanges();
  }

  void getGroupInfo() {
    // Get the latest group data from RelayGroup.sharedInstance
    // This ensures we always have the most up-to-date information
    final latestGroup =
        RelayGroup.sharedInstance.groups[widget.relayGroup.groupId]?.value;
    final groupToUse = latestGroup ?? widget.relayGroup;

    _usernameController.text = groupToUse.name;
    _aboutController.text = groupToUse.about;
    subscriptionPrice = groupToUse.subscriptionAmount;
    setState(() {});
  }

  @override
  void dispose() {
    if (_selectedCoverPhotoPath != null &&
        _selectedCoverPhotoPath!.startsWith('webfile://')) {
      web_file_registry.unregisterWebFileData(_selectedCoverPhotoPath!);
    }
    _hasChangesNotifier.dispose();
    _usernameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget buildBody(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // White status bar icons
      child: Scaffold(body: _buildBody()),
    );
  }

  // Build main body content
  Widget _buildBody() {
    return Scaffold(
      backgroundColor: kBgLight,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Column(
          children: [
            _buildGradientHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentitySection(),
                    const SizedBox(height: 32),
                    _buildMonetizationSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build gradient header with blurred background
  Widget _buildGradientHeader() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kGradientColors,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Cover photo background
          Positioned.fill(child: _buildCoverPhotoContent(context)),
          // Navigation bar
          SafeArea(child: Column(children: [_buildNavigationBar()])),
          // Uploading indicator
          if (_isUploadingCoverPhoto)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          // Change Cover button or Cancel/Confirm buttons positioned at bottom right
          Positioned(
            bottom: 16,
            right: 20,
            child: _buildCoverPhotoActionButtons(),
          ),
        ],
      ),
    );
  }

  // Build cover photo action buttons (Change Cover or Cancel/Confirm)
  Widget _buildCoverPhotoActionButtons() {
    // If cover photo is uploaded but not confirmed, show Cancel and Confirm buttons
    if (_uploadedCoverPhotoUrl != null && !_isSavingCoverPhoto) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cancel button
          GestureDetector(
            onTap: _cancelCoverPhotoUpload,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Icon(Icons.close, size: 18, color: kTitleColor),
                  SizedBox(width: 8),
                  Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Confirm button
          GradientButton(
            text: 'Confirm',
            onTap: _confirmCoverPhotoUpload,
            icon: const Icon(Icons.check, size: 18, color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            fontSize: 14,
            gradientStyle: GradientButtonStyle.vertical,
          ),
        ],
      );
    }
    
    // Default: Show Change Cover button
    return GestureDetector(
      onTap: _isSavingCoverPhoto ? null : _setImages,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isSavingCoverPhoto 
              ? Colors.grey.withOpacity(0.7)
              : Color(0xFF1E3A5F), // Dark blue
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSavingCoverPhoto)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(Icons.camera_alt, size: 18, color: Colors.white),
            if (!_isSavingCoverPhoto) SizedBox(width: 8),
            if (!_isSavingCoverPhoto)
              Text(
                'Change Cover',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
            ),
          ),
        ],
        ),
      ),
    );
  }

  // Build navigation bar
  Widget _buildNavigationBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 40,
            margin: EdgeInsets.only(left: 16),
            decoration: BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(
                      0xFFFFE5F5,
                    ).withOpacity(0.3), // Light pink with transparency
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: CommonImage(
                      iconName: 'back_arrow_icon.png',
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build Identity section
  Widget _buildIdentitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IDENTITY',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kTitleColor,
          ),
        ),
        const SizedBox(height: 2),
        Container(
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
          label: 'Display Name',
                value:
                    _usernameController.text.isNotEmpty
                        ? _usernameController.text
                        : '',
          onTap: () {
            // Navigate to edit display name
            _showEditDialog(
              title: 'Display Name',
              controller: _usernameController,
              maxLines: 1,
            );
          },
                isShowUnderline: true,
              ),
              _buildInfoRow(
                iconName: 'bio_icon.png',
          label: 'Bio',
                value:
                    _aboutController.text.isNotEmpty
                        ? _aboutController.text
                        : '',
          onTap: () {
            // Navigate to edit bio
            _showEditDialog(
              title: 'Bio',
              controller: _aboutController,
              maxLines: 3,
            );
          },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build Monetization section
  Widget _buildMonetizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MONETIZATION',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: kTitleColor,
          ),
        ),
        const SizedBox(height: 2),
        _buildInfoCard(
          iconName: 'lighting_bg_icon.png',
          label: 'Subscription Price',
          value:
              subscriptionPrice > 0
              ? '${subscriptionPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} sats / month'
              : 'Free',
          onTap: () {
            // Show subscription settings dialog
            _showSetPriceDialog();
          },
        ),
      ],
    );
  }

  // Build info row widget (similar to my_profile_page.dart)
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

  // Build info card widget (kept for Monetization section)
  Widget _buildInfoCard({
    required String iconName,
    required String label,
    required String value,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
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
        child: Row(
          children: [
            CommonImage(iconName: iconName, size: 40),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value.length > 40 ? '${value.substring(0, 40)}...' : value,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kTitleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF9C4), // Light yellow
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kTitleColor,
                  ),
                ),
              ),
              SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Show edit dialog
  void _showEditDialog({
    required String title,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    final isDisplayName = title == 'Display Name';

    CommonEditFieldDialog.show(
      context: context,
      title: title,
      initialValue: controller.text,
      hintText: isDisplayName ? 'Enter your display name' : 'Enter your bio',
      instructionText: isDisplayName ? 'Enter your display name' : 'Tell us about yourself',
      headerIcon: CommonImage(iconName:isDisplayName ? 'bio_icon.png' :  'user_ill_icon.png',size: 30,),
          maxLines: maxLines,
      validator: isDisplayName
          ? (value) {
              if (value.isEmpty) {
                return 'Display name cannot be empty';
              }
              return null;
            }
          : null,
      onSave: (newValue) async {
        try {
          controller.text = newValue;
          OKEvent event = await _submitGroupMetadata(reason: '$title updated');
          
          if (event.status) {
            getGroupInfo();
            setState(() {});
            if (mounted) {
              FeedWidgetsUtils.showMessage(
                context,
                '$title updated successfully',
                isError: false,
              );
            }
            return true;
          } else {
            // Restore original value on failure
            final latestGroup =
                RelayGroup.sharedInstance.groups[widget.relayGroup.groupId]?.value ??
                    widget.relayGroup;
            controller.text = isDisplayName ? latestGroup.name : latestGroup.about;
            if (mounted) {
              FeedWidgetsUtils.showMessage(
                context,
                event.message.isNotEmpty ? event.message : 'Failed to update $title',
                isError: true,
              );
            }
            return false;
          }
        } catch (e) {
          // Restore original value on error
          final latestGroup =
              RelayGroup.sharedInstance.groups[widget.relayGroup.groupId]?.value ??
                  widget.relayGroup;
          controller.text = isDisplayName ? latestGroup.name : latestGroup.about;
          if (mounted) {
            FeedWidgetsUtils.showMessage(
              context,
              'Error updating $title: $e',
              isError: true,
            );
          }
          return false;
        }
      },
    );
  }

  // Show set price dialog
  void _showSetPriceDialog() {
    final TextEditingController priceController = TextEditingController(
      text: subscriptionPrice > 0 ? subscriptionPrice.toString() : '',
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with title and close button
                      Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 16, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Set Price',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: kTitleColor,
                              ),
                            ),
                            if (!isSaving)
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 20,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Warning info box
                            Container(
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
                                  CommonImage(
                                    iconName: 'start_yellow_icon.png',
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Set a monthly subscription price in Satoshis. Your followers will pay this amount to access your exclusive content.',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: kWarningText,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            // Price input field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: KBorderColor,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: priceController,
                                      keyboardType: TextInputType.number,
                                      enabled: !isSaving,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary,
                                      ),
          decoration: InputDecoration(
                                        hintText: '1000',
                                        hintStyle: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: kTextTertiary,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.only(right: 8),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
                                    child: Text(
                                      'SATS',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            // Save Changes button
                            SizedBox(
                              width: double.infinity,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient:
                                      isSaving ? null : getBrandGradient(),
                                  color: isSaving ? Colors.grey[300] : null,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap:
                                        isSaving
                                            ? null
                                            : () async {
                                              await _handleSaveSubscriptionPrice(
                                                priceText:
                                                    priceController.text.trim(),
                                                setSaving: (saving) =>
                                                    setDialogState(
                                                        () => isSaving = saving),
                                                closeDialog: () =>
                                                    Navigator.of(context).pop(),
                                                showMessage:
                                                    (msg, {bool isError = false}) {
                                                  if (mounted) {
                                                    FeedWidgetsUtils.showMessage(
                                                      context,
                                                      msg,
                                                      isError: isError,
                                                    );
                                                  }
                                                },
                                              );
                                            },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      alignment: Alignment.center,
                                      child:
                                          isSaving
                                              ? SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.white),
                                                ),
                                              )
                                              : Text(
                                                'Save Changes',
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildCoverPhotoContent(BuildContext context) {
    if (_selectedCoverPhotoBytes != null) {
      return Image.memory(
        _selectedCoverPhotoBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
      );
    }
    if (widget.relayGroup.picture.isNotEmpty) {
      return ChuChuCachedNetworkImage(
        imageUrl: widget.relayGroup.picture,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        placeholder: (_, __) => _buildCoverPlaceholder(context),
        errorWidget: (_, __, ___) => _buildCoverPlaceholder(context),
      );
    }
    return _buildCoverPlaceholder(context);
  }

  Widget _buildCoverPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: kGradientColors.map((color) => color).toList(),
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setImages() async {
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
          if (_selectedCoverPhotoPath != null &&
              _selectedCoverPhotoPath!.startsWith('webfile://')) {
            web_file_registry.unregisterWebFileData(_selectedCoverPhotoPath!);
          }
          setState(() {
            _selectedCoverPhotoPath = virtualPath;
            _selectedCoverPhotoBytes = bytes;
            _uploadedCoverPhotoUrl =
                null; // Clear previous uploaded URL when selecting new image
          });
        } else {
          setState(() {
            _selectedCoverPhotoPath = picked.path;
            _selectedCoverPhotoBytes = bytes;
            _uploadedCoverPhotoUrl =
                null; // Clear previous uploaded URL when selecting new image
          });
        }
        _hasChangesNotifier.value = _hasChanges();
        // Wait for the next frame to ensure state is updated before uploading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _uploadCoverPhoto();
        });
      }
    } catch (e, stackTrace) {
      LogUtils.w(() => 'Error picking cover photo: $e');
      LogUtils.d(() => 'Stack trace: $stackTrace');
      FeedWidgetsUtils.showMessage(
        context,
        'Unable to open photo picker. Please try again.',
        isError: true,
      );
    }
  }

  // Action methods

  // Upload cover photo
  Future<void> _uploadCoverPhoto() async {
    if (_selectedCoverPhotoPath == null || _isUploadingCoverPhoto) return;

    setState(() {
      _isUploadingCoverPhoto = true;
    });

    try {
      String uploadFilePath;
      String fileName;
      
      if (kIsWeb || _selectedCoverPhotoPath!.startsWith('webfile://')) {
        // For web platform, use the virtual path directly
        // BolssomUploader will handle webfile:// paths internally
        uploadFilePath = _selectedCoverPhotoPath!;
        fileName = uploadFilePath.split('/').last;
      } else {
        // For non-web platforms, use file path
        final imageFile = File(_selectedCoverPhotoPath!);
        uploadFilePath = imageFile.path;
        fileName = uploadFilePath.split('/').last;
      }
      
      final imageUrl = await BolssomUploader.upload(
        'https://blossom.band',
        uploadFilePath,
        fileName: fileName,
      );
      LogUtils.d(() => 'ProfileEdit: upload result: $imageUrl');
      if (imageUrl != null && mounted) {
        // Save uploaded URL separately, keep local path for display
        _uploadedCoverPhotoUrl = imageUrl;
        LogUtils.d(() => 'ProfileEdit: saved uploaded URL: $_uploadedCoverPhotoUrl');
        _hasChangesNotifier.value = _hasChanges();
        setState(() {});
        CommonToast.instance.show(context, 'Cover photo uploaded successfully. Please confirm to save.',toastType:ToastType.success);
      } else {
        throw Exception('Upload returned empty URL');
      }
    } catch (e, stackTrace) {
      LogUtils.w(() => 'Error uploading cover photo: $e');
      LogUtils.d(() => 'Stack trace: $stackTrace');
      if (mounted) {
        CommonToast.instance.show(context, 'Cover photo upload failed: $e',      toastType:ToastType.failed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCoverPhoto = false;
        });
      }
    }
  }

  /// Submit group metadata to server (name/about/picture/subscription)
  Future<OKEvent> _submitGroupMetadata({
    int? subscriptionAmountOverride,
    String reason = 'Profile updated',
  }) async {
    // Use latest group data if available
    final relayGroup =
        RelayGroup.sharedInstance.groups[widget.relayGroup.groupId]?.value ??
        widget.relayGroup;

    LogUtils.d(() => 'ProfileEdit: submitGroupMetadata groupId=${relayGroup.groupId} picture=${relayGroup.picture} uploadedUrl=$_uploadedCoverPhotoUrl');
        final updatedName = _usernameController.text.trim();
        final updatedAbout = _aboutController.text.trim();
        final updatedPicture = _uploadedCoverPhotoUrl ?? relayGroup.picture;
    final updatedSubscriptionAmount =
        subscriptionAmountOverride ?? subscriptionPrice;

    LogUtils.d(() => 'ProfileEdit: editMetadata picture=$updatedPicture');
        OKEvent event = await RelayGroup.sharedInstance.editMetadata(
          relayGroup.groupId,
          updatedName,
          updatedAbout,
          updatedPicture,
          relayGroup.closed,
          relayGroup.private,
      reason,
          subscriptionAmount: updatedSubscriptionAmount,
          groupWalletId: relayGroup.groupWalletId,
        );

    LogUtils.d(() => 'ProfileEdit: editMetadata result status=${event.status} message=${event.message}');
        if (event.status) {
      // Sync local state so _hasChanges() returns correct value
      relayGroup.name = updatedName;
      relayGroup.about = updatedAbout;
      relayGroup.picture = updatedPicture;
      relayGroup.subscriptionAmount = updatedSubscriptionAmount;
      subscriptionPrice = updatedSubscriptionAmount;
      LogUtils.d(() => 'ProfileEdit: local state synced picture=${relayGroup.picture}');
        } else {
      LogUtils.w(() => 'ProfileEdit: failed to update metadata: ${event.message}');
    }

    return event;
  }

  /// Cancel cover photo upload - clear uploaded URL and reset state
  void _cancelCoverPhotoUpload() {
    LogUtils.d(() => 'ProfileEdit: cancel cover photo upload');
    setState(() {
      _uploadedCoverPhotoUrl = null;
      _selectedCoverPhotoPath = null;
      _selectedCoverPhotoBytes = null;
    });
    _hasChangesNotifier.value = _hasChanges();
    CommonToast.instance.show(context, 'Cover photo upload canceled',      toastType:ToastType.failed);
  }

  /// Confirm cover photo upload - save to relay
  Future<void> _confirmCoverPhotoUpload() async {
    if (_uploadedCoverPhotoUrl == null) return;
    LogUtils.d(() => 'ProfileEdit: confirm cover photo upload');
    setState(() {
      _isSavingCoverPhoto = true;
    });

    try {
      OKEvent event = await _submitGroupMetadata(reason: 'Cover photo updated');
      if (event.status) {
        LogUtils.d(() => 'ProfileEdit: cover photo saved to relay');
        getGroupInfo();
        setState(() {
          _isSavingCoverPhoto = false;
          // Clear uploaded URL after successful save - it's now in relayGroup.picture
          _uploadedCoverPhotoUrl = null;
        });
        if (mounted) {
          FeedWidgetsUtils.showMessage(
            context,
            'Cover photo saved successfully',
            isError: false,
          );
        }
      } else {
        LogUtils.w(() => 'ProfileEdit: failed to save cover photo: ${event.message}');
        setState(() {
          _isSavingCoverPhoto = false;
        });
        if (mounted) {
          FeedWidgetsUtils.showMessage(
            context,
            event.message.isNotEmpty ? event.message : 'Failed to save cover photo',
            isError: true,
          );
        }
      }
    } catch (e) {
      LogUtils.w(() => 'ProfileEdit: error saving cover photo: $e');
      setState(() {
        _isSavingCoverPhoto = false;
      });
      if (mounted) {
        FeedWidgetsUtils.showMessage(
          context,
          'Error saving cover photo: $e',
          isError: true,
        );
      }
    }
  }

  /// Handle saving subscription price inside bottom sheet
  Future<void> _handleSaveSubscriptionPrice({
    required String priceText,
    required void Function(bool) setSaving,
    required VoidCallback closeDialog,
    required void Function(String message, {bool isError}) showMessage,
  }) async {
    int newPrice = 0;
    if (priceText.isNotEmpty) {
      try {
        newPrice = int.parse(priceText);
      } catch (_) {
        showMessage('Please enter a valid number', isError: true);
          return;
        }
      }

    setSaving(true);
    try {
      OKEvent event = await _submitGroupMetadata(
        subscriptionAmountOverride: newPrice,
        reason: 'Subscription price updated',
      );

      if (event.status) {
        subscriptionPrice = newPrice;
        getGroupInfo();
        closeDialog();
        showMessage('Subscription price updated successfully', isError: false);
      } else {
        setSaving(false);
        showMessage(
          event.message.isNotEmpty
              ? event.message
              : 'Failed to update subscription price',
          isError: true,
        );
      }
    } catch (e) {
      setSaving(false);
      showMessage('Error updating subscription price: $e', isError: true);
    }
  }
}
