import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum ToastType { success, info, warning, error }

class CustomToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? customIcon,
  }) {
    Color backgroundColor;
    Color iconColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        backgroundColor = const Color(0xFF10B981);
        iconColor = Colors.white;
        textColor = Colors.white;
        icon = customIcon ?? Icons.check_circle_outline_rounded;
        break;
      case ToastType.warning:
        backgroundColor = const Color(0xFFF59E0B);
        iconColor = Colors.white;
        textColor = Colors.white;
        icon = customIcon ?? Icons.warning_amber_rounded;
        break;
      case ToastType.error:
        backgroundColor = const Color(0xFFEF4444);
        iconColor = Colors.white;
        textColor = Colors.white;
        icon = customIcon ?? Icons.error_outline_rounded;
        break;
      case ToastType.info:
        backgroundColor = AppTheme.primary;
        iconColor = Colors.white;
        textColor = Colors.white;
        icon = customIcon ?? Icons.info_outline_rounded;
        break;
    }

    final snackBar = SnackBar(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: EdgeInsets.zero,
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty) ...[
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.95),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
