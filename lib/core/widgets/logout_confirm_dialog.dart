import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/storage_key_tool.dart';
import '../../core/manager/cache/chuchu_cache_manager.dart';
import '../../core/manager/chuchu_user_info_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/navigator/navigator.dart';
import '../../presentation/login/pages/new_login_page.dart';
import 'gradient_button.dart';

/// Logout confirmation dialog widget
/// A reusable dialog for confirming user logout with warning message
class LogoutConfirmDialog {
  /// Show logout confirmation dialog
  ///
  /// [context] - BuildContext to show the dialog
  /// [closeDrawer] - Whether to close drawer if open (default: true)
  /// [onLogoutComplete] - Optional callback when logout is complete
  static Future<void> show(
    BuildContext context, {
    bool closeDrawer = true,
    VoidCallback? onLogoutComplete,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout Confirm Dialog',
      barrierColor: Colors.transparent,
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
            Center(
              child: SafeArea(
                child: AlertDialog(
                  insetPadding: EdgeInsets.symmetric(horizontal: 18.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor:
                      theme.dialogTheme.backgroundColor ??
                      theme.colorScheme.surface,
                  // titlePadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.error,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Confirm Logout',
                        style: GoogleFonts.inter(
                          color: kTitleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Are you sure you want to logout?',
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Color(0xFFFFE4E6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please make sure you have backed up your private key before logging out. You will need it to access your account again.',
                                style: GoogleFonts.inter(
                                  color: Color(0xFFC70036),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onSurface,
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: GradientButton(
                              text: 'Logout',
                              onTap: () async {
                                // Close dialog first
                                Navigator.of(context).pop();

                                // Wait a frame to ensure dialog is closed
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );

                                // Close drawer if still open and closeDrawer is true
                                if (closeDrawer &&
                                    Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }

                                // Wait another frame to ensure drawer is closed
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );

                                // Save user pubkey (clear it)
                                await ChuChuCacheManager.defaultOXCacheManager
                                    .saveForeverData(
                                      StorageKeyTool.CHUCHU_USER_PUBKEY,
                                      '',
                                    );

                                // Perform logout
                                await ChuChuUserInfoManager.sharedInstance
                                    .logout(needObserver: true);

                                // Navigate to login page and clear entire navigation stack
                                // Use global navigator key to ensure we navigate from root context
                                final navigatorContext =
                                    ChuChuNavigator
                                        .navigatorKey
                                        .currentContext ??
                                    context;
                                Navigator.of(
                                  navigatorContext,
                                ).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const NewLoginPage(),
                                  ),
                                  (route) =>
                                      false, // Remove all previous routes
                                );

                                // Call optional callback
                                onLogoutComplete?.call();
                              },
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
