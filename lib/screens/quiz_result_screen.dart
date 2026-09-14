import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class QuizResultScreen extends StatelessWidget {
  final String quizTitle;
  final int score;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions;
  final Map<dynamic, dynamic> userAnswers;

  const QuizResultScreen({
    super.key,
    required this.quizTitle,
    required this.score,
    required this.totalQuestions,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = totalQuestions > 0 ? (score / totalQuestions) * 100 : 0;
    final bool passed = percentage >= 50;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Quiz Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.mainText,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.mainText),
          onPressed: () {
            Navigator.of(context).pop();
          },
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: AppTheme.primary, size: 26),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            tooltip: 'Return to Dashboard',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Result Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: passed
                        ? [AppTheme.primary, AppTheme.primaryLight]
                        : [AppTheme.error, const Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (passed ? AppTheme.primary : AppTheme.error).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      passed ? 'Congratulations!' : 'Keep Practicing!',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      quizTitle,
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$score / $totalQuestions (${percentage.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detailed Review:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.mainText),
                ),
              ),
              const SizedBox(height: 12),

              // Question Breakdown
              ...List.generate(questions.length, (index) {
                final q = questions[index];
                final dynamic userAnsRaw = userAnswers[index];
                final dynamic correctAnsRaw = q['correct_option'];

                final String userAnsStr = userAnsRaw is List ? userAnsRaw.join(', ') : (userAnsRaw?.toString() ?? 'Not Answered');
                final String correctAnsStr = correctAnsRaw is List ? correctAnsRaw.join(', ') : correctAnsRaw.toString();

                bool isCorrect = false;
                if (q['type'] == 'multiple') {
                  List<String> userList = userAnsRaw is List ? List<String>.from(userAnsRaw) : (userAnsRaw is String ? [userAnsRaw] : []);
                  List<String> correctList = correctAnsRaw is List ? List<String>.from(correctAnsRaw) : [correctAnsRaw.toString()];
                  userList.sort();
                  correctList.sort();
                  isCorrect = userList.length == correctList.length && userList.every((e) => correctList.contains(e));
                } else {
                  isCorrect = userAnsRaw.toString() == correctAnsRaw.toString();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCorrect ? AppTheme.success.withValues(alpha: 0.4) : AppTheme.error.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isCorrect ? AppTheme.success : AppTheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Q${index + 1}. ${q['question']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.mainText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Answer: $userAnsStr',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isCorrect ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Correct Answer: $correctAnsStr',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success),
                        ),
                      ],
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home_rounded, size: 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: const Text(
                    'Return to Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
