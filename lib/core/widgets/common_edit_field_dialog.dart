import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'common_toast.dart';
import 'gradient_button.dart';

class CommonEditFieldDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;
  final String instructionText;
  final Widget? headerIcon;
  final int maxLines;
  final Future<bool> Function(String value) onSave;
  final VoidCallback? onCancel;
  final String? Function(String)? validator;

  const CommonEditFieldDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.instructionText,
    this.headerIcon,
    this.maxLines = 1,
    required this.onSave,
    this.onCancel,
    this.validator,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String initialValue,
    required String hintText,
    required String instructionText,
    Widget? headerIcon,
    int maxLines = 1,
    required Future<bool> Function(String value) onSave,
    VoidCallback? onCancel,
    String? Function(String)? validator,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit field dialog',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext context, Animation<double> anim1, Animation<double> anim2) {
        return CommonEditFieldDialog(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          instructionText: instructionText,
          headerIcon: headerIcon,
          maxLines: maxLines,
          onSave: onSave,
          onCancel: onCancel,
          validator: validator,
        );
      },
    );
  }

  @override
  State<CommonEditFieldDialog> createState() => _CommonEditFieldDialogState();
}

class _CommonEditFieldDialogState extends State<CommonEditFieldDialog> {
  late TextEditingController _editController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final value = _editController.text.trim();

    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        CommonToast.instance.show(context, error, toastType: ToastType.failed);
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await widget.onSave(value);
      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        CommonToast.instance.show(context, 'Error: $e', toastType: ToastType.failed);
      }
    }
  }

  void _handleCancel() {
    if (widget.onCancel != null) {
      widget.onCancel!();
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _handleCancel,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
        ),
        // Dialog 内容
        Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon and title
                  Row(
                    children: [
                      if (widget.headerIcon != null) ...[
                        widget.headerIcon!,
                        SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kTitleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  // Input field with icon
                  Container(
                    decoration: BoxDecoration(
                      color: kBgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _editController,
                      enabled: !_isSaving,
                      maxLines: widget.maxLines,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: kTitleColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: GoogleFonts.inter(
                          fontSize: 16,
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Instruction text
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.instructionText,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _handleCancel,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kTitleColor,
                            side: BorderSide(color: Colors.grey[200]!),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: kTitleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Save button with gradient
                      Expanded(
                        child: GradientButton(
                          text: 'Save',
                          onTap: _handleSave,
                          isLoading: _isSaving,
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          fontWeight: FontWeight.w700,
                          gradientStyle: GradientButtonStyle.vertical,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
