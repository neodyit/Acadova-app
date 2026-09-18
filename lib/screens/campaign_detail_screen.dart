import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/custom_toast.dart';

class CampaignDetailScreen extends StatelessWidget {
  final Map<String, dynamic> campaign;

  const CampaignDetailScreen({
    super.key,
    required this.campaign,
  });

  Future<void> _openUrl(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.trim().isEmpty || rawUrl.trim().toLowerCase() == 'null') {
      CustomToast.show(context, message: 'No link provided for this event/announcement.', type: ToastType.info);
      return;
    }

    String urlStr = rawUrl.trim();
    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }

    final Uri? uri = Uri.tryParse(urlStr);
    if (uri != null) {
      try {
        final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          if (context.mounted) {
            CustomToast.show(context, message: 'Could not open link: $urlStr', type: ToastType.error);
          }
        }
      } catch (e) {
        if (context.mounted) {
          CustomToast.show(context, message: 'Could not open link.', type: ToastType.error);
        }
      }
    }
  }

  void _showImageLightbox(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    headers: ApiService.authToken != null
                        ? {'Authorization': 'Bearer ${ApiService.authToken}'}
                        : null,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(32),
                      color: Colors.white,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.textMuted),
                          SizedBox(height: 12),
                          Text('Image could not be loaded', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final String title = campaign['title'] ?? 'Event Details';
    final String description = campaign['description'] ?? 'No description available.';
    final String badge = (campaign['badge'] ?? 'Notice').toString();
    final String? imageUrl = campaign['imageUrl'] as String?;
    final String? linkUrl = campaign['linkUrl'] as String?;
    final DateTime? endsAt = campaign['endsAt'] is DateTime ? campaign['endsAt'] : null;
    final List<Color> gradient = (campaign['gradient'] is List<Color>)
        ? campaign['gradient'] as List<Color>
        : [AppTheme.primary, AppTheme.primaryDark];
    final bool hasValidLink = linkUrl != null && linkUrl.trim().isNotEmpty && linkUrl.trim().toLowerCase() != 'null';
    final bool isExpired = endsAt != null && DateTime.now().isAfter(endsAt);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Announcement Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.mainText),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.mainText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: AdBannerWidget(),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Hero Banner / Photo Header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _showImageLightbox(context, imageUrl),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                headers: ApiService.authToken != null
                                    ? {'Authorization': 'Bearer ${ApiService.authToken}'}
                                    : null,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.campaign_rounded, color: Colors.white, size: 56),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Tap to view full image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.campaign_rounded, color: Colors.white, size: 56),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Badges & Time pill row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: gradient[0].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gradient[0].withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: TextStyle(
                        color: gradient[0],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'EVENT ENDED',
                        style: TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (endsAt != null)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.primaryDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ends: ${_formatDateTime(endsAt)}',
                                style: const TextStyle(
                                  color: AppTheme.primaryDark,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Main Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.mainText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 14),
                    SelectableText(
                      description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: AppTheme.mainText,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Link Button
              if (hasValidLink) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(context, linkUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: const Text(
                      'Open Official Event / Registration Link',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
