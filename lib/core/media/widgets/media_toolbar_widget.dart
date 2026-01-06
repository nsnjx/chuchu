import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common_image.dart';

class MediaToolbarWidget extends StatelessWidget {
  final VoidCallback onPickImages;
  final VoidCallback onPickVideos;
  final bool hideVideoButton;
  final bool hideToolbar;
  final EdgeInsetsGeometry padding;

  const MediaToolbarWidget({
    super.key,
    required this.onPickImages,
    required this.onPickVideos,
    this.hideVideoButton = false,
    this.hideToolbar = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (hideToolbar) return const SizedBox();

    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: _buildButton(
              context: context,
              theme: theme,
              iconName: 'image_bg_icon.png',
              label: 'Add images',
              onTap: onPickImages,
            ),
          ),
          if (!hideVideoButton) ...[
            const SizedBox(width: 12),
            Expanded(
              child: _buildButton(
                context: context,
                theme: theme,
                iconName: 'video_bg_icon.png',
                label: 'Add video',
                onTap: onPickVideos,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required ThemeData theme,
    required String iconName,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CommonImage(iconName: iconName, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
