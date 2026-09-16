import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineQuizSyncService {
  static const String _pendingSubmissionsKey = 'acadova_pending_quiz_submissions';
  static bool _isSyncing = false;

  /// Save quiz attempt locally when offline or when backend submission fails
  static Future<void> savePendingSubmission({
    required int quizId,
    required Map<dynamic, dynamic> userAnswers,
    required int violationsCount,
    String? location,
    String? latitude,
    String? longitude,
    String? ipAddress,
    String submissionType = 'manual',
    String? autoSubmitReason,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingList = prefs.getStringList(_pendingSubmissionsKey) ?? [];

      final Map<String, dynamic> formattedAnswers = {};
      userAnswers.forEach((key, value) {
        formattedAnswers[key.toString()] = value;
      });

      final Map<String, dynamic> payload = {
        'quiz_id': quizId,
        'user_answers': formattedAnswers,
        'violations_count': violationsCount,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'ip_address': ipAddress,
        'submission_type': submissionType,
        'auto_submit_reason': autoSubmitReason,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Avoid duplicates: check if same quiz submission payload is already pending
      bool exists = pendingList.any((item) {
        try {
          final decoded = jsonDecode(item);
          return decoded['quiz_id'] == quizId;
        } catch (_) {
          return false;
        }
      });

      if (!exists) {
        pendingList.add(jsonEncode(payload));
        await prefs.setStringList(_pendingSubmissionsKey, pendingList);
        debugPrint('OfflineQuizSyncService: Saved pending quiz submission for quiz #$quizId');
      }
    } catch (e) {
      debugPrint('OfflineQuizSyncService: Error saving offline submission: $e');
    }
  }

  /// Sync all stored offline quiz submissions when internet returns
  static Future<int> syncPendingSubmissions() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    int syncedCount = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingList = prefs.getStringList(_pendingSubmissionsKey) ?? [];
      if (pendingList.isEmpty) {
        _isSyncing = false;
        return 0;
      }

      List<String> remainingList = [];

      for (String item in pendingList) {
        try {
          final data = jsonDecode(item) as Map<String, dynamic>;
          final int quizId = data['quiz_id'];
          final Map<dynamic, dynamic> userAnswers = data['user_answers'] ?? {};
          final int violationsCount = data['violations_count'] ?? 0;
          final String? location = data['location'];
          final String? latitude = data['latitude'];
          final String? longitude = data['longitude'];
          final String? ipAddress = data['ip_address'];
          final String submissionType = data['submission_type'] ?? 'offline_synced';
          final String? autoSubmitReason = data['auto_submit_reason'];

          final res = await ApiService.submitQuizAttempt(
            quizId: quizId,
            userAnswers: userAnswers,
            violationsCount: violationsCount,
            location: location,
            latitude: latitude,
            longitude: longitude,
            ipAddress: ipAddress,
            submissionType: submissionType,
            autoSubmitReason: autoSubmitReason,
          );

          if (res['success'] == true || res['statusCode'] == 200 || res['statusCode'] == 201) {
            syncedCount++;
            debugPrint('OfflineQuizSyncService: Successfully synced offline submission for quiz #$quizId');
          } else {
            // Keep in remaining list if failed due to connectivity or server error
            remainingList.add(item);
          }
        } catch (e) {
          remainingList.add(item);
        }
      }

      await prefs.setStringList(_pendingSubmissionsKey, remainingList);
    } catch (e) {
      debugPrint('OfflineQuizSyncService: Error during sync process: $e');
    } finally {
      _isSyncing = false;
    }

    return syncedCount;
  }
}
