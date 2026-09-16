import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../services/offline_quiz_sync_service.dart';
import '../widgets/custom_toast.dart';
import 'quiz_result_screen.dart';

class QuizAttemptScreen extends StatefulWidget {
  final int? quizId;
  final String quizTitle;
  final String? subject;
  final int durationMinutes;
  final List<Map<String, dynamic>> questions;
  final String? location;
  final String? latitude;
  final String? longitude;

  const QuizAttemptScreen({
    super.key,
    this.quizId,
    required this.quizTitle,
    this.subject,
    this.durationMinutes = 15,
    required this.questions,
    this.location,
    this.latitude,
    this.longitude,
  });

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> with WidgetsBindingObserver {
  static const MethodChannel _securityChannel = MethodChannel('com.neodyit.acadova/security');

  int _currentIndex = 0;
  late int _remainingSeconds;
  Timer? _timer;
  late List<Map<String, dynamic>> _shuffledQuestions;
  final Map<int, dynamic> _selectedAnswers = {};
  final Set<int> _markedForReview = {};
  bool _isSubmitted = false;

  // Anti-cheat tracking
  int _tabSwitchCount = 0;
  static const int _maxAllowedSwitches = 3;
  late final DateTime _initTime;

  @override
  void initState() {
    super.initState();
    _initTime = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    
    // Enable High-Security Proctored Kiosk Environment
    _enableProctoringSecurity();

    // Shuffle questions on quiz start for each attempt
    _shuffledQuestions = List<Map<String, dynamic>>.from(widget.questions)..shuffle();
    
    _remainingSeconds = widget.durationMinutes * 60;
    _startTimer();
  }

  Future<void> _enableProctoringSecurity() async {
    try {
      // Hide status bar & navigation bar
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

      // Invoke native security channel for both Windows desktop and Android mobile
      if (!kIsWeb && (Platform.isWindows || Platform.isAndroid)) {
        await _securityChannel.invokeMethod('enableSecureScreen');
      }
    } catch (_) {}
  }

  Future<void> _disableProctoringSecurity() async {
    try {
      // Disable secure kiosk mode & DND first
      if (!kIsWeb && (Platform.isWindows || Platform.isAndroid)) {
        await _securityChannel.invokeMethod('disableSecureScreen');
      }

      // Small delay to allow Android OS lock task transition before updating UI mode
      await Future.delayed(const Duration(milliseconds: 150));

      // Restore default system UI edge-to-edge
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disableProctoringSecurity();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Ignore lifecycle transitions during the initial 2.5s startup window (full-screen window resize / setup)
    if (DateTime.now().difference(_initTime).inMilliseconds < 2500) {
      return;
    }

    if (!_isSubmitted) {
      // If user turns screen off or display sleeps (inactive/hidden), don't treat it as cheating switch
      if (state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
        return;
      }

      // Only count actual app switching (paused)
      if (state == AppLifecycleState.paused) {
        _tabSwitchCount++;

        if (_tabSwitchCount >= _maxAllowedSwitches) {
          _autoSubmitDueToViolation();
        } else {
          _showWarningDialog();
        }
      }
    }
  }

  void _showWarningDialog() {
    CustomToast.show(
      context,
      title: 'Anti-Cheat Warning ($_tabSwitchCount/$_maxAllowedSwitches)',
      message: 'App switching or split-screen is strictly forbidden! Auto-submission will occur on $_maxAllowedSwitches violations.',
      type: ToastType.warning,
    );
  }

  void _autoSubmitDueToViolation() {
    if (_isSubmitted) return;

    CustomToast.show(
      context,
      title: 'Test Auto-Submitted',
      message: 'Max violation limit reached ($_maxAllowedSwitches app switches)! Your attempt has been recorded.',
      type: ToastType.error,
    );

    _submitQuiz(
      isTimeUp: false,
      submissionType: 'auto',
      autoSubmitReason: 'Exceeded anti-cheat app switch violation limit ($_maxAllowedSwitches switches)',
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _submitQuiz(
          isTimeUp: true,
          submissionType: 'auto',
          autoSubmitReason: 'Time expired (Duration: ${widget.durationMinutes} mins)',
        );
      }
    });
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _shuffledQuestions.length; i++) {
      final q = _shuffledQuestions[i];
      final dynamic userAns = _selectedAnswers[i];
      final dynamic correctAns = q['correct_option'];

      if (q['type'] == 'multiple') {
        List<String> userList = userAns is List
            ? List<String>.from(userAns)
            : (userAns is String ? [userAns] : []);
        List<String> correctList = correctAns is List
            ? List<String>.from(correctAns)
            : (correctAns is String ? [correctAns] : []);

        if (correctAns is String) {
          try {
            final parsed = jsonDecode(correctAns);
            if (parsed is List) {
              correctList = List<String>.from(parsed);
            }
          } catch (_) {}
        }

        userList.sort();
        correctList.sort();
        if (userList.length == correctList.length &&
            userList.every((e) => correctList.contains(e))) {
          score++;
        }
      } else {
        if (userAns != null && userAns.toString() == correctAns.toString()) {
          score++;
        }
      }
    }
    return score;
  }

  void _submitQuiz({
    bool isTimeUp = false,
    String submissionType = 'manual',
    String? autoSubmitReason,
  }) {
    if (_isSubmitted) return;
    _isSubmitted = true;
    _timer?.cancel();
    _disableProctoringSecurity();

    int score = _calculateScore();

    if (widget.quizId != null) {
      final Map<dynamic, dynamic> questionIdAnswers = {};
      _selectedAnswers.forEach((index, ans) {
        if (index < _shuffledQuestions.length) {
          final qId = _shuffledQuestions[index]['id'];
          if (qId != null) {
            questionIdAnswers[qId] = ans;
          }
        }
      });

      ApiService.submitQuizAttempt(
        quizId: widget.quizId!,
        userAnswers: questionIdAnswers,
        violationsCount: _tabSwitchCount,
        location: widget.location,
        latitude: widget.latitude,
        longitude: widget.longitude,
        submissionType: submissionType,
        autoSubmitReason: autoSubmitReason,
      ).then((res) {
        if (res['success'] != true && res['statusCode'] != 200 && res['statusCode'] != 201) {
          // Save locally if server/network fails
          OfflineQuizSyncService.savePendingSubmission(
            quizId: widget.quizId!,
            userAnswers: questionIdAnswers,
            violationsCount: _tabSwitchCount,
            location: widget.location,
            latitude: widget.latitude,
            longitude: widget.longitude,
            submissionType: 'offline_saved',
            autoSubmitReason: autoSubmitReason,
          );
        } else {
          // Trigger background sync for any past pending submissions
          OfflineQuizSyncService.syncPendingSubmissions();
        }
      }).catchError((_) {
        // Save locally if exception occurs during submission
        OfflineQuizSyncService.savePendingSubmission(
          quizId: widget.quizId!,
          userAnswers: questionIdAnswers,
          violationsCount: _tabSwitchCount,
          location: widget.location,
          latitude: widget.latitude,
          longitude: widget.longitude,
          submissionType: 'offline_saved',
          autoSubmitReason: autoSubmitReason,
        );
      });
    }

    if (isTimeUp) {
      CustomToast.show(
        context,
        title: "Time's Up!",
        message: 'Your quiz response has been automatically submitted.',
        type: ToastType.warning,
      );
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quizTitle: widget.quizTitle,
          score: score,
          totalQuestions: _shuffledQuestions.length,
          questions: _shuffledQuestions,
          userAnswers: _selectedAnswers,
        ),
      ),
    );
  }

  void _openQuestionPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final answeredCount = _selectedAnswers.length;
            final reviewCount = _markedForReview.length;
            final unattemptedCount = _shuffledQuestions.length - answeredCount;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Question Overview Grid',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(AppTheme.success, 'Answered ($answeredCount)'),
                      _buildLegendItem(AppTheme.primary, 'Review ($reviewCount)'),
                      _buildLegendItem(Colors.grey.shade200, 'Unanswered ($unattemptedCount)', textColor: Colors.black87),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Grid of Questions
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(_shuffledQuestions.length, (index) {
                          final isAnswered = _selectedAnswers.containsKey(index);
                          final isReview = _markedForReview.contains(index);
                          final isCurrent = index == _currentIndex;

                          Color bgColor = Colors.grey.shade100;
                          Color textColor = const Color(0xFF2D3436);
                          Border? border = Border.all(color: Colors.grey.shade300);

                          if (isReview) {
                            bgColor = AppTheme.primary;
                            textColor = Colors.white;
                            border = null;
                          } else if (isAnswered) {
                            bgColor = AppTheme.success;
                            textColor = Colors.white;
                            border = null;
                          }

                          if (isCurrent) {
                            border = Border.all(color: const Color(0xFF2D3436), width: 2.5);
                          }

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: border,
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (isReview)
                                    const Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(Icons.flag, size: 10, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Submit Button inside Palette
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showSubmissionConfirmationDialog();
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Submit Final Test', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7675),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, {Color textColor = Colors.white}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: color == Colors.grey.shade200 ? Border.all(color: Colors.grey.shade400) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF636E72)),
        ),
      ],
    );
  }

  void _showSubmissionConfirmationDialog() {
    final int total = _shuffledQuestions.length;
    final int answered = _selectedAnswers.length;
    final int unattempted = total - answered;
    final int reviewCount = _markedForReview.length;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Icon Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Submit Assessment?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mainText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to finish your test?\nOnce submitted, you cannot alter your answers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              // Summary Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      icon: Icons.list_alt_rounded,
                      label: 'Total Questions',
                      value: '$total',
                      valueColor: AppTheme.mainText,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildStatRow(
                      icon: Icons.check_circle_rounded,
                      label: 'Answered',
                      value: '$answered',
                      valueColor: AppTheme.success,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildStatRow(
                      icon: Icons.flag_rounded,
                      label: 'Marked for Review',
                      value: '$reviewCount',
                      valueColor: AppTheme.primary,
                    ),
                    const Divider(height: 16, thickness: 0.8),
                    _buildStatRow(
                      icon: Icons.error_outline_rounded,
                      label: 'Unanswered',
                      value: '$unattempted',
                      valueColor: AppTheme.error,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Keep Solving',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _submitQuiz();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Submit Test',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: valueColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = _shuffledQuestions[_currentIndex];
    final List<String> options = List<String>.from(currentQ['options']);
    final bool isMarked = _markedForReview.contains(_currentIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        CustomToast.show(
          context,
          title: 'Action Blocked',
          message: 'Back navigation is strictly disabled during an active test!',
          type: ToastType.error,
        );
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: const Color(0xFF2D3436),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quizTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                'Question ${_currentIndex + 1} of ${_shuffledQuestions.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            // Grid Palette Icon
            IconButton(
              tooltip: 'Question Overview Grid',
              icon: const Icon(Icons.grid_view_rounded, color: AppTheme.primary),
              onPressed: _openQuestionPalette,
            ),
            // Timer Badge
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60 ? const Color(0xFFFFECEC) : AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _remainingSeconds < 60 ? AppTheme.error : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _shuffledQuestions.length,
                backgroundColor: Colors.grey.shade200,
                color: AppTheme.primary,
                minHeight: 4,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Q${_currentIndex + 1}',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                // Difficulty Badge
                                Builder(
                                  builder: (context) {
                                    final String diff = (currentQ['difficulty'] ?? 'easy').toString().toLowerCase();
                                    Color badgeColor = const Color(0xFF00B894);
                                    String label = 'EASY';
                                    if (diff == 'hard') {
                                      badgeColor = const Color(0xFFFF7675);
                                      label = 'HARD';
                                    } else if (diff == 'medium') {
                                      badgeColor = const Color(0xFFE17055);
                                      label = 'MEDIUM';
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Mark for Review Button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isMarked) {
                                        _markedForReview.remove(_currentIndex);
                                      } else {
                                        _markedForReview.add(_currentIndex);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isMarked ? AppTheme.primary : AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isMarked ? AppTheme.primary : AppTheme.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isMarked ? Icons.flag : Icons.flag_outlined,
                                          size: 14,
                                          color: isMarked ? Colors.white : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isMarked ? 'Review Marked' : 'Mark for Review',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isMarked ? Colors.white : AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Container(
                                //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                //   decoration: BoxDecoration(
                                //     color: Colors.green.shade50,
                                //     borderRadius: BorderRadius.circular(6),
                                //     border: Border.all(color: Colors.green.shade200),
                                //   ),
                                //   child: Row(
                                //     mainAxisSize: MainAxisSize.min,
                                //     children: [
                                //       Icon(Icons.security, size: 13, color: Colors.green.shade700),
                                //       const SizedBox(width: 4),
                                //       Text(
                                //         'Proctored',
                                //         style: TextStyle(fontSize: 10.5, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              currentQ['question'],
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D3436),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              currentQ['type'] == 'multiple' ? 'Select Answer(s):' : 'Select Answer:',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF636E72)),
                            ),
                          ),
                          if (currentQ['type'] == 'multiple') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B894).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Multiple Select',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00B894)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      ...options.map((opt) {
                        final bool isMultiple = currentQ['type'] == 'multiple';
                        final dynamic userAns = _selectedAnswers[_currentIndex];
                        
                        bool isSelected = false;
                        if (isMultiple) {
                          final List<String> currentSelectedList = userAns is List ? List<String>.from(userAns) : (userAns is String ? [userAns] : []);
                          isSelected = currentSelectedList.contains(opt);
                        } else {
                          isSelected = userAns == opt;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isMultiple) {
                                  List<String> list = userAns is List
                                      ? List<String>.from(userAns)
                                      : (userAns is String ? [userAns] : <String>[]);
                                  if (list.contains(opt)) {
                                    list.remove(opt);
                                  } else {
                                    list.add(opt);
                                  }
                                  if (list.isEmpty) {
                                    _selectedAnswers.remove(_currentIndex);
                                  } else {
                                    _selectedAnswers[_currentIndex] = list;
                                  }
                                } else {
                                  if (isSelected) {
                                    _selectedAnswers.remove(_currentIndex);
                                  } else {
                                    _selectedAnswers[_currentIndex] = opt;
                                  }
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primary : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : [],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                                      borderRadius: isMultiple ? BorderRadius.circular(6) : null,
                                      color: isSelected ? AppTheme.primary : Colors.white,
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      opt,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? AppTheme.primary : const Color(0xFF2D3436),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Bottom Action Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Previous Question Button
                    if (_currentIndex > 0) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentIndex--;
                          });
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Prev'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2D3436),
                          side: const BorderSide(color: Color(0xFFDFE6E9)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    const Spacer(),

                    // Universal Submit Button
                    OutlinedButton.icon(
                      onPressed: _showSubmissionConfirmationDialog,
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.error),
                      label: const Text('Submit', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Next / Last Question Button
                    ElevatedButton(
                      onPressed: () {
                        if (_currentIndex < _shuffledQuestions.length - 1) {
                          setState(() {
                            _currentIndex++;
                          });
                        } else {
                          _showSubmissionConfirmationDialog();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentIndex < _shuffledQuestions.length - 1 ? 'Next' : 'Finish',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
