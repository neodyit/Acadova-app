import 'dart:convert';
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
  List<Map<String, dynamic>> _questions = [];
  Map<dynamic, dynamic> _userAnswers = {};
  int _score = 0;
  int _totalQuestions = 0;
  int? _passingMarks;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _score = widget.score;
    _totalQuestions = widget.totalQuestions;
    _questions = List<Map<String, dynamic>>.from(widget.questions);
    _userAnswers = Map<dynamic, dynamic>.from(widget.userAnswers);
    _passingMarks = widget.passingMarks;

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
            if (res['data']['quiz'] != null && res['data']['quiz']['passing_marks'] != null) {
              _passingMarks = int.tryParse(res['data']['quiz']['passing_marks'].toString()) ?? _passingMarks;
            }
            if (res['data']['questions'] is List && (res['data']['questions'] as List).isNotEmpty) {
              _questions = List<Map<String, dynamic>>.from(res['data']['questions']);
            }
            if (res['data']['my_attempt'] is Map) {
              final myAtt = res['data']['my_attempt'];
              _score = int.tryParse(myAtt['score'].toString()) ?? _score;
              _totalQuestions = int.tryParse(myAtt['total_questions'].toString()) ?? _totalQuestions;
              if (myAtt['user_answers'] != null) {
                if (myAtt['user_answers'] is Map) {
                  _userAnswers = Map<dynamic, dynamic>.from(myAtt['user_answers']);
                } else if (myAtt['user_answers'] is String && (myAtt['user_answers'] as String).isNotEmpty) {
                  try {
                    final decoded = jsonDecode(myAtt['user_answers']);
                    if (decoded is Map) {
                      _userAnswers = Map<dynamic, dynamic>.from(decoded);
                    }
                  } catch (_) {}
                }
              }
            }
            if (res['data']['leaderboard'] is List) {
              _leaderboard = List<Map<String, dynamic>>.from(res['data']['leaderboard']);
            }
          } else {
            _statusMessage = res['message'] ?? 'Leaderboard & detailed results will be published after review.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPublished = false;
          _statusMessage = 'Results pending publication by faculty.';
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

  String _formatLocationString(String? locationStr, String? ipStr) {
    if (locationStr == null || locationStr.trim().isEmpty) {
      if (ipStr != null && ipStr.isNotEmpty) return 'IP: $ipStr';
      return 'GPS & Proctoring Verified';
    }

    String loc = locationStr.trim();
    if (loc.contains('0.0000') || loc.toLowerCase() == 'location verified') {
      return (ipStr != null && ipStr.isNotEmpty) ? 'GPS Verified (IP: $ipStr)' : 'GPS & Proctoring Verified';
    }

    if (ipStr != null && ipStr.isNotEmpty && !loc.contains(ipStr)) {
      return '$loc • IP: $ipStr';
    }
    return loc;
  }

  String _formatOptionText(dynamic rawOpt, List optionsList) {
    if (rawOpt == null) return 'Not Answered';
    if (rawOpt is List) {
      return rawOpt.map((e) => _formatOptionText(e, optionsList)).join(', ');
    }

    String optStr = rawOpt.toString().trim();
    int? idx = int.tryParse(optStr);
    if (idx != null && optionsList.isNotEmpty && idx >= 0 && idx < optionsList.length) {
      return optionsList[idx].toString();
    }

    return optStr;
  }

  Widget _buildInitialStatusCard(bool isDesktop) {
    final submissionId = 'SUB-${(widget.quizId ?? 100).toString().padLeft(4, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final formattedLocation = _formatLocationString(widget.location, widget.ipAddress);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 50,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Assessment Submitted!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.mainText,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.quizTitle,
            style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Publication Status Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _statusMessage ?? 'Leaderboard & detailed results will be published after review.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submission Metadata Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                _buildMetaRow(Icons.fingerprint_rounded, 'Submission ID', submissionId),
                const Divider(color: AppTheme.border, height: 16),
                _buildMetaRow(Icons.devices_rounded, 'Mode', widget.submissionType.toUpperCase()),
                const Divider(color: AppTheme.border, height: 16),
                _buildMetaRow(Icons.location_on_rounded, 'Security & Location', formattedLocation),
                if (widget.autoSubmitReason != null && widget.autoSubmitReason!.isNotEmpty) ...[
                  const Divider(color: AppTheme.border, height: 16),
                  _buildMetaRow(Icons.warning_amber_rounded, 'Auto-Submit', widget.autoSubmitReason!, valueColor: AppTheme.error),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.mainText,
            ),
            softWrap: true,
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
              ? [const Color(0xFF15803D), const Color(0xFF16A34A)]
              : [const Color(0xFFB91C1C), const Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (passed ? AppTheme.success : AppTheme.error).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
              size: isDesktop ? 60 : 46,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            passed ? 'Assessment Passed!' : 'Needs Improvement',
            style: TextStyle(
              fontSize: isDesktop ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.quizTitle,
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.87), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
                  '$_score / $_totalQuestions (${percentage.toStringAsFixed(0)}%)',
                  style: const TextStyle(
                    fontSize: 19,
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
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
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded, color: AppTheme.primary, size: 24),
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
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.border),
            itemBuilder: (context, idx) {
              final student = _leaderboard[idx];
              final int rank = student['rank'] ?? (idx + 1);
              final String name = student['name'] ?? 'Student';
              final String rollNo = student['roll_number'] ?? 'N/A';
              final String scoreDisplay = student['score_display'] ?? '${student['score']}/${student['total_questions']}';
              final String? avatar = student['avatar'];
              final int? userId = student['user_id'];

              if (userId != null) {
                ApiService.cacheUserProfile(userId, student);
              }

              final avatarUrl = ApiService.formatMediaUrl(avatar);

              Color rankColor = AppTheme.textMuted;
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
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        scoreDisplay,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.success),
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
    final double percentage = _totalQuestions > 0 ? (_score / _totalQuestions) * 100 : 0;
    final int passingThreshold = _passingMarks ?? 50;
    final bool passed = percentage >= passingThreshold;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 850;
    final int wrongCount = _totalQuestions - _score;

    Widget detailedReviewList = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question Analytics & Answers:',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.mainText),
        ),
        const SizedBox(height: 14),
        ...List.generate(_questions.length, (index) {
          final q = _questions[index];
          final dynamic userAnsRaw = _userAnswers[index] ?? _userAnswers[index.toString()] ?? _userAnswers[q['id']?.toString()];
          final dynamic correctAnsRaw = q['correct_option'];

          final List optionsList = (q['options'] is List) ? (q['options'] as List) : [];
          final String userAnsStr = _formatOptionText(userAnsRaw, optionsList);
          final String correctAnsStr = _formatOptionText(correctAnsRaw, optionsList);

          bool isCorrect = false;
          if (userAnsRaw != null) {
            if (q['type'] == 'multiple') {
              List<String> userList = userAnsRaw is List ? List<String>.from(userAnsRaw) : [userAnsRaw.toString()];
              List<String> correctList = correctAnsRaw is List ? List<String>.from(correctAnsRaw) : [correctAnsRaw.toString()];
              userList.sort();
              correctList.sort();
              isCorrect = userList.length == correctList.length && userList.every((e) => correctList.contains(e));
            } else {
              isCorrect = userAnsRaw.toString().trim() == correctAnsRaw.toString().trim() ||
                  userAnsStr.trim() == correctAnsStr.trim();
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect ? AppTheme.success.withValues(alpha: 0.35) : AppTheme.error.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.03),
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
                        color: (isCorrect ? AppTheme.success : AppTheme.error).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? AppTheme.success : AppTheme.error,
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
                    color: (isCorrect ? AppTheme.success : AppTheme.error).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Your Selection: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                          Expanded(
                            child: Text(
                              userAnsStr,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isCorrect ? AppTheme.success : AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('Correct Solution: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                            Expanded(
                              child: Text(
                                correctAnsStr,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
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
      backgroundColor: AppTheme.background,
      bottomNavigationBar: const SafeArea(
        child: AdBannerWidget(),
      ),
      appBar: AppBar(
        title: const Text('Assessment Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.mainText)),
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _returnHome,
              icon: const Icon(Icons.dashboard_outlined, size: 16, color: AppTheme.primary),
              label: const Text(
                'Workspace',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: !_isPublished
                    ? Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 550),
                          child: Column(
                            children: [
                              _buildInitialStatusCard(isDesktop),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _returnHome,
                                  icon: const Icon(Icons.home_rounded, size: 20),
                                  label: const Text('Back to Home Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
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
                                    _buildStatTile('Total Questions', '$_totalQuestions', Icons.format_list_numbered_rounded, AppTheme.primary),
                                    const SizedBox(height: 12),
                                    _buildStatTile('Correct Answers', '$_score', Icons.check_circle_rounded, AppTheme.success),
                                    const SizedBox(height: 12),
                                    _buildStatTile('Incorrect / Skipped', '$wrongCount', Icons.cancel_rounded, AppTheme.error),
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
                                  Expanded(child: _buildStatTile('Correct', '$_score', Icons.check_circle_rounded, AppTheme.success)),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildStatTile('Wrong', '$wrongCount', Icons.cancel_rounded, AppTheme.error)),
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
