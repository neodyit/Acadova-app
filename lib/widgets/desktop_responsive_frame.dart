import 'package:flutter/material.dart';

/// A widget that limits screen content width on Windows Desktop / Large monitors,
/// centering content with an optional sleek desktop container card effect.
class DesktopResponsiveFrame extends StatelessWidget {
  final Widget child;
  final double maxMobileWidth;
  final bool showDesktopCard;
  final EdgeInsetsGeometry? padding;

  const DesktopResponsiveFrame({
    super.key,
    required this.child,
    this.maxMobileWidth = 600,
    this.showDesktopCard = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > maxMobileWidth;

        if (!isWideScreen) {
          return child;
        }

        return Center(
          child: Padding(
            padding: padding ?? EdgeInsets.symmetric(
              vertical: showDesktopCard ? 24.0 : 0.0,
              horizontal: 16.0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxMobileWidth),
              child: showDesktopCard
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: child,
                      ),
                    )
                  : child,
            ),
          ),
        );
      },
    );
  }
}
