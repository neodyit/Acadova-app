import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseAnalyticsObserver? observer;
  bool _initialized = false;

  FirebaseAnalytics? get analytics => _analytics;

  /// Initialize Firebase Analytics safely across platforms
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      if (kDebugMode) {
        print('AnalyticsService: Firebase Analytics initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AnalyticsService: Firebase initialization skipped/failed: $e');
      }
    }
  }

  /// Log a custom event to Google Analytics
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      if (_analytics != null) {
        await _analytics!.logEvent(
          name: name,
          parameters: parameters,
        );
      }
    } catch (e) {
      debugPrint('AnalyticsService: logEvent ($name) error: $e');
    }
  }

  /// Log a screen view event to Google Analytics
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      if (_analytics != null) {
        await _analytics!.logScreenView(
          screenName: screenName,
          screenClass: screenClass ?? screenName,
        );
      }
    } catch (e) {
      debugPrint('AnalyticsService: logScreenView ($screenName) error: $e');
    }
  }

  /// Associate Google Analytics sessions with current authenticated user ID
  Future<void> setUserId(String? userId) async {
    try {
      if (_analytics != null) {
        await _analytics!.setUserId(id: userId);
      }
    } catch (_) {}
  }

  /// Set user dimensions/properties (e.g. role: 'student' or 'faculty', department, college)
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      if (_analytics != null && value != null) {
        await _analytics!.setUserProperty(name: name, value: value);
      }
    } catch (_) {}
  }

  // Common App-Specific Helper Analytics Methods

  /// Log User Login
  Future<void> logLogin({
    required String method,
    String? role,
  }) async {
    await logEvent('login', parameters: {
      'method': method,
      if (role != null) 'role': role!,
    });
  }

  /// Log User Registration
  Future<void> logSignUp({
    required String method,
    String? role,
  }) async {
    await logEvent('sign_up', parameters: {
      'method': method,
      if (role != null) 'role': role!,
    });
  }

  /// Log Quiz Attempt Start
  Future<void> logQuizStart({
    required int quizId,
    required String title,
    String? subject,
  }) async {
    await logEvent('quiz_started', parameters: {
      'quiz_id': quizId,
      'quiz_title': title,
      'subject': subject ?? 'General',
    });
  }

  /// Log Quiz Attempt Completion / Submission
  Future<void> logQuizSubmit({
    required int quizId,
    required String title,
    required int score,
    required int total,
  }) async {
    final pct = total > 0 ? ((score / total) * 100).round() : 0;
    await logEvent('quiz_submitted', parameters: {
      'quiz_id': quizId,
      'quiz_title': title,
      'score': score,
      'total_questions': total,
      'percentage': pct,
      'passed': pct >= 50 ? 1 : 0,
    });
  }

  /// Log Quiz Result Review View
  Future<void> logViewResult({
    required int quizId,
    required String title,
  }) async {
    await logEvent('view_result', parameters: {
      'quiz_id': quizId,
      'quiz_title': title,
    });
  }

  /// Log Campaign Banner Click
  Future<void> logCampaignClick({
    required int campaignId,
    required String title,
  }) async {
    await logEvent('campaign_click', parameters: {
      'campaign_id': campaignId,
      'campaign_title': title,
    });
  }
}
