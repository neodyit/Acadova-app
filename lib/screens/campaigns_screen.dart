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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        foregroundColor: AppTheme.mainText,
        title: const Text(
          'Campaigns & Events',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.mainText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.mainText),
            onPressed: _fetchCampaigns,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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

              // Filter Selector Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            ],
          ),
        ),
      ),
      body: SafeArea(
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
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredCampaigns.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final campaign = _filteredCampaigns[index];
                          return _buildCampaignCard(campaign);
                        },
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Top Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c['badge'].toString().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
                  const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c['description'],
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                if (c['linkUrl'] != null && c['linkUrl'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final String urlStr = c['linkUrl'].toString().trim();
                        final Uri? uri = Uri.tryParse(urlStr);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (mounted) {
                            CustomToast.show(
                              context,
                              title: 'Link Error',
                              message: 'Cannot launch URL: $urlStr',
                              type: ToastType.warning,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open External Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gradient.first,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
