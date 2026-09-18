import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/ad_service.dart';
import '../services/api_service.dart';
import '../widgets/ad_banner_widget.dart';

class QuizResultScreen extends StatefulWidget {
  final int? quizId;
  final String quizTitle;
  final int score;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions;
  final Map<dynamic, dynamic> userAnswers;
  final int? passingMarks;
  final String submissionType;
  final String? autoSubmitReason;
  final String? location;
  final String? ipAddress;

  const QuizResultScreen({
    super.key,
    this.quizId,
    required this.quizTitle,
    required this.score,
    required this.totalQuestions,
    required this.questions,
    required this.userAnswers,
    this.passingMarks,
    this.submissionType = 'manual',
    this.autoSubmitReason,
    this.location,
    this.ipAddress,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  static const MethodChannel _securityChannel = MethodChannel('com.neodyit.acadova/security');

  bool _isLoading = true;
  bool _isPublished = false;
  // ignore: unused_field
  Map<String, dynamic>? _quizData;
  List<Map<String, dynamic>> _leaderboard = [];
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _releaseProctoringSecurity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showInterstitialAdIfReady();
    });
    _fetchResultStatusAndLeaderboard();
  }

  Future<void> _releaseProctoringSecurity() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isAndroid)) {
        await _securityChannel.invokeMethod('disableSecureScreen');
      }
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  Future<void> _fetchResultStatusAndLeaderboard() async {
    if (widget.quizId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await ApiService.getQuizLeaderboard(widget.quizId!);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPublished = res['is_published'] == true;
          if (_isPublished && res['data'] != null) {
            _quizData = res['data']['quiz'];
            if (res['data']['leaderboard'] is List) {
              _leaderboard = List<Map<String, dynamic>>.from(res['data']['leaderboard']);
            }
          } else {
            _statusMessage = res['message'] ?? 'Results have not been published by your faculty or administrator yet.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPublished = false;
          _statusMessage = 'Results pending publication.';
        });
      }
    }
  }

  void _returnHome() {
    AdService().showInterstitialAdIfReady(
      forceShow: true,
      onDismissed: () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );
  }

  Widget _buildInitialStatusCard(bool isDesktop) {
    final submissionId = 'SUB-${(widget.quizId ?? 100).toString().padLeft(4, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 54,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Assessment Submitted!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.quizTitle,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Publication Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _statusMessage ?? 'Results Pending Publication by Faculty',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submission Metadata Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                _buildMetaRow(Icons.fingerprint_rounded, 'Submission ID', submissionId),
                const Divider(color: Colors.white12, height: 16),
                _buildMetaRow(Icons.devices_rounded, 'Submission Mode', widget.submissionType.toUpperCase()),
                const Divider(color: Colors.white12, height: 16),
                _buildMetaRow(Icons.location_on_rounded, 'Location / IP', widget.location ?? 'Captured securely'),
                if (widget.autoSubmitReason != null && widget.autoSubmitReason!.isNotEmpty) ...[
                  const Divider(color: Colors.white12, height: 16),
                  _buildMetaRow(Icons.warning_amber_rounded, 'Auto-Submit', widget.autoSubmitReason!, valueColor: const Color(0xFFF87171)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {Color valueColor = Colors.white}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white60),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.white60, fontWeight: FontWeight.w500)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPublishedSummaryCard(bool isDesktop, double percentage, bool passed) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: passed
              ? [const Color(0xFF047857), const Color(0xFF10B981)]
              : [const Color(0xFFB91C1C), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (passed ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
              size: isDesktop ? 64 : 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            passed ? 'Assessment Passed!' : 'Needs Improvement',
            style: TextStyle(
              fontSize: isDesktop ? 26 : 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.quizTitle,
            style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${widget.score} / ${widget.totalQuestions} (${percentage.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardSection() {
    if (_leaderboard.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 10),
              Text(
                'Quiz Leaderboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.mainText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaderboard.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, idx) {
              final student = _leaderboard[idx];
              final int rank = student['rank'] ?? (idx + 1);
              final String name = student['name'] ?? 'Student';
              final String rollNo = student['roll_number'] ?? 'N/A';
              final String scoreDisplay = student['score_display'] ?? '${student['score']}/${student['total_questions']}';
              final String? avatar = student['avatar'];
              final int? userId = student['user_id'];

              // Cache user profile
              if (userId != null) {
                ApiService.cacheUserProfile(userId, student);
              }

              final avatarUrl = ApiService.formatMediaUrl(avatar);

              Color rankColor = const Color(0xFF64748B);
              Widget? rankBadge;
              if (rank == 1) {
                rankColor = const Color(0xFFD97706);
                rankBadge = const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 22);
              } else if (rank == 2) {
                rankColor = const Color(0xFF475569);
                rankBadge = const Icon(Icons.military_tech_rounded, color: Color(0xFF94A3B8), size: 22);
              } else if (rank == 3) {
                rankColor = const Color(0xFFB45309);
                rankBadge = const Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 22);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: rankBadge ?? Text(
                        '#$rank',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rankColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mainText)),
                          Text('Roll No: $rollNo', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        scoreDisplay,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = widget.totalQuestions > 0 ? (widget.score / widget.totalQuestions) * 100 : 0;
    final int passingThreshold = widget.passingMarks ?? 50;
    final bool passed = percentage >= passingThreshold;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 850;
    final int wrongCount = widget.totalQuestions - widget.score;

    Widget detailedReviewList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Analytics & Answers:',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.mainText),
        ),
        const SizedBox(height: 14),
        ...List.generate(widget.questions.length, (index) {
          final q = widget.questions[index];
          final dynamic userAnsRaw = widget.userAnswers[index];
          final dynamic correctAnsRaw = q['correct_option'];

          final String userAnsStr = userAnsRaw is List ? userAnsRaw.join(', ') : (userAnsRaw?.toString() ?? 'Not Answered');
          final String correctAnsStr = correctAnsRaw is List ? correctAnsRaw.join(', ') : (correctAnsRaw?.toString() ?? 'N/A');

          bool isCorrect = false;
          if (q['type'] == 'multiple') {
            List<String> userList = userAnsRaw is List ? List<String>.from(userAnsRaw) : (userAnsRaw is String ? [userAnsRaw] : []);
            List<String> correctList = correctAnsRaw is List ? List<String>.from(correctAnsRaw) : [correctAnsRaw?.toString() ?? ''];
            userList.sort();
            correctList.sort();
            isCorrect = userList.length == correctList.length && userList.every((e) => correctList.contains(e));
          } else {
            isCorrect = userAnsRaw.toString() == correctAnsRaw.toString();
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFFEF4444).withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Q${index + 1}. ${q['question']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.mainText, height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Your Selection: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                          Expanded(
                            child: Text(
                              userAnsStr,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Correct Solution: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                            Expanded(
                              child: Text(
                                correctAnsStr,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      bottomNavigationBar: const SafeArea(
        child: AdBannerWidget(),
      ),
      appBar: AppBar(
        title: const Text('Assessment Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.mainText,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _returnHome,
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text('Return to Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: !_isPublished
                    ? Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            children: [
                              _buildInitialStatusCard(isDesktop),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _returnHome,
                                icon: const Icon(Icons.home_rounded),
                                label: const Text('Back to Home Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : (isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column - Stats & Result Banner
                              SizedBox(
                                width: 380,
                                child: Column(
                                  children: [
                                    _buildPublishedSummaryCard(true, percentage, passed),
                                    const SizedBox(height: 20),
                                    _buildStatTile('Total Questions', '${widget.totalQuestions}', Icons.format_list_numbered_rounded, AppTheme.primary),
                                    const SizedBox(height: 12),
                                    _buildStatTile('Correct Answers', '${widget.score}', Icons.check_circle_rounded, const Color(0xFF10B981)),
                                    const SizedBox(height: 12),
                                    _buildStatTile('Incorrect / Skipped', '$wrongCount', Icons.cancel_rounded, const Color(0xFFEF4444)),
                                    _buildLeaderboardSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),

                              // Right Column - Detailed Review
                              Expanded(child: detailedReviewList),
                            ],
                          )
                        : Column(
                            children: [
                              _buildPublishedSummaryCard(false, percentage, passed),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: _buildStatTile('Correct', '${widget.score}', Icons.check_circle_rounded, const Color(0xFF10B981))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildStatTile('Wrong', '$wrongCount', Icons.cancel_rounded, const Color(0xFFEF4444))),
                                ],
                              ),
                              _buildLeaderboardSection(),
                              const SizedBox(height: 24),
                              detailedReviewList,
                            ],
                          )),
              ),
            ),
    );
  }
}
