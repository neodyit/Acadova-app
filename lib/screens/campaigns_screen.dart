import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_toast.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'notice', 'event'

  bool _isLoading = true;
  List<Map<String, dynamic>> _campaigns = [];

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaigns() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawList = await ApiService.getCampaigns(status: 'all');
      final now = DateTime.now();

      final List<Map<String, dynamic>> mappedList = [];
      for (var c in rawList) {
        List<Color> gradient = [AppTheme.primary, AppTheme.primaryDark];
        final colorKey = c['banner_color']?.toString().toLowerCase() ?? 'amber';
        if (colorKey == 'orange' || colorKey == 'coral' || colorKey == 'rust') {
          gradient = [const Color(0xFFC2410C), const Color(0xFFEA580C)];
        } else if (colorKey == 'teal' || colorKey == 'emerald' || colorKey == 'green') {
          gradient = [const Color(0xFF15803D), const Color(0xFF22C55E)];
        } else if (colorKey == 'blue' || colorKey == 'ocean') {
          gradient = [const Color(0xFF0369A1), const Color(0xFF0284C7)];
        } else if (colorKey == 'purple') {
          gradient = [const Color(0xFF6C5CE7), const Color(0xFFA29BFE)];
        }

        DateTime? endsAt = ApiService.parseDateTime(c['ends_at']);
        final bool isExpired = endsAt != null && now.isAfter(endsAt);

        mappedList.add({
          'id': c['id'],
          'title': c['title'] ?? 'Announcement',
          'description': c['description'] ?? 'No description provided.',
          'badge': c['badge'] ?? 'Notice',
          'imageUrl': ApiService.formatMediaUrl(
            (c['image_url'] ?? c['image'] ?? c['banner_url'] ?? c['image_path'])?.toString(),
          ),
          'linkUrl': c['link_url'],
          'endsAt': endsAt,
          'isExpired': isExpired,
          'status': c['status'] ?? 'active',
          'gradient': gradient,
        });
      }

      if (mounted) {
        setState(() {
          _campaigns = mappedList;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCampaigns {
    return _campaigns.where((c) {
      final matchesQuery = _searchQuery.isEmpty ||
          c['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

      if (_selectedCategory == 'notice') {
        return matchesQuery && (c['badge'].toString().toLowerCase().contains('notice'));
      } else if (_selectedCategory == 'event') {
        return matchesQuery && (c['badge'].toString().toLowerCase().contains('event') || c['badge'].toString().toLowerCase().contains('workshop'));
      }

      return matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;
    final int crossAxisCount = screenWidth >= 1200 ? 3 : (screenWidth >= 750 ? 2 : 1);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.mainText,
        automaticallyImplyLeading: !isDesktop,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                const Text(
                  'Campaigns & Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.mainText),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.mainText),
                  onPressed: _fetchCampaigns,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // Search Input Bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 24.0 : 16.0,
                      vertical: 4.0,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search announcements & events...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                    ),
                  ),

                  // Filter Selector Row (Horizontally Scrollable)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 16.0, vertical: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip('All Announcements', 'all'),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Notices', 'notice'),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Events', 'event'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _fetchCampaigns,
                    child: _filteredCampaigns.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.campaign_outlined,
                                          size: 48,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Announcements Available',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3436),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Check back later for news, upcoming events, and official campus notices.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : (crossAxisCount > 1
                            ? GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(24),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 20,
                                  mainAxisSpacing: 20,
                                  mainAxisExtent: 440,
                                ),
                                itemCount: _filteredCampaigns.length,
                                itemBuilder: (context, index) {
                                  final campaign = _filteredCampaigns[index];
                                  return _buildCampaignCard(campaign);
                                },
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredCampaigns.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final campaign = _filteredCampaigns[index];
                                  return _buildCampaignCard(campaign);
                                },
                              )),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final bool isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.mainText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> c) {
    final List<Color> gradient = c['gradient'] as List<Color>;
    final bool isExpired = c['isExpired'] == true;
    final String? imageUrl = c['imageUrl'] as String?;
    final DateTime? endsAt = c['endsAt'] as DateTime?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Section (Image or Gradient Header)
          if (imageUrl != null && imageUrl.isNotEmpty)
            Stack(
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
                          colors: isExpired
                              ? [Colors.grey.shade600, Colors.grey.shade400]
                              : gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.campaign_rounded, color: Colors.white, size: 48),
                      ),
                    ),
                  ),
                ),
                // Gradient Overlay for Badge contrast
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                // Top Tag Bar over Image
                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          c['badge'].toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ENDED',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          else
            // Header Bar without Image
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isExpired
                      ? [Colors.grey.shade600, Colors.grey.shade400]
                      : gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      c['badge'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ended',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                ],
              ),
            ),

          // Body Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c['title'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3436),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  if (endsAt != null) ...[
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isExpired
                                ? 'Ended on ${endsAt.day}/${endsAt.month}/${endsAt.year}'
                                : 'Valid until ${endsAt.day}/${endsAt.month}/${endsAt.year} ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isExpired ? Colors.red.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (c['linkUrl'] != null && c['linkUrl'].toString().trim().isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final String rawUrl = c['linkUrl'].toString().trim();
                          if (rawUrl.isEmpty || rawUrl.toLowerCase() == 'null') return;

                          var formattedUrl = rawUrl;
                          if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
                            formattedUrl = 'https://$formattedUrl';
                          }

                          final Uri? uri = Uri.tryParse(formattedUrl);
                          if (uri != null && uri.host.isNotEmpty) {
                            try {
                              bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                              if (!launched) {
                                launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
                              }
                              if (!launched && mounted) {
                                CustomToast.show(
                                  context,
                                  title: 'Link Error',
                                  message: 'Cannot launch URL: $formattedUrl',
                                  type: ToastType.warning,
                                );
                              }
                            } catch (_) {
                              if (mounted) {
                                CustomToast.show(
                                  context,
                                  title: 'Link Error',
                                  message: 'Unable to open link in browser',
                                  type: ToastType.warning,
                                );
                              }
                            }
                          } else {
                            if (mounted) {
                              CustomToast.show(
                                context,
                                title: 'Link Error',
                                message: 'Invalid URL format: $rawUrl',
                                type: ToastType.warning,
                               );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Open External Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gradient.first,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
