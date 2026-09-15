import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Custom safe avatar widget that catches 401, network, and missing image errors gracefully
class SafeUserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackInitial;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const SafeUserAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackInitial,
    this.radius = 20,
    this.backgroundColor = const Color(0x266C5CE7),
    this.textColor = const Color(0xFF6C5CE7),
  });

  @override
  Widget build(BuildContext context) {
    final initialStr = fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : 'U';
    final String? formattedUrl = ApiService.formatMediaUrl(avatarUrl);

    if (formattedUrl == null || formattedUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor,
        child: Text(
          initialStr,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.network(
          formattedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: backgroundColor,
              alignment: Alignment.center,
              child: Text(
                initialStr,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.85,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
