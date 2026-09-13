import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.activeApiUrl;

  static String? authToken;
  static Map<String, dynamic>? currentUser;

  /// Callback executed when 401 Unauthorized / session invalid is returned
  static Function()? onUnauthorized;

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'user_data';

  /// Check response status code and trigger session clearance if 401 Unauthenticated / User Deleted
  static void _checkUnauthorized(int statusCode) {
    if (statusCode == 401) {
      clearSession();
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
    }
  }

  /// Helper to convert technical exceptions (SocketException, HandshakeException, Timeout, etc.)
  /// into user-friendly error messages like "No Internet Connection".
  static String _formatExceptionMessage(dynamic error, {String defaultMessage = 'Connection failed'}) {
    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('failed host lookup') ||
        str.contains('no address associated with hostname') ||
        str.contains('network is unreachable') ||
        str.contains('connection refused') ||
        str.contains('clientexception')) {
      return 'No Internet Connection. Please check your network & try again.';
    }
    if (str.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }
    return defaultMessage;
  }

  /// Utility to parse server date/time string accurately into Local DateTime.
  /// Server timestamps are stored in UTC. If 'Z' is missing, it appends 'Z' so it converts to correct local timezone.
  static DateTime? parseDateTime(dynamic raw) {
    if (raw == null) return null;
    String str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return null;

    if (!str.contains('T') && str.contains(' ')) {
      str = str.replaceAll(' ', 'T');
    }
    if (!str.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(str)) {
      str = '${str}Z';
    }

    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      return DateTime.tryParse(raw.toString())?.toLocal();
    }
  }

  /// Load persisted session from SharedPreferences
  static Future<bool> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_keyToken);
    final userJson = prefs.getString(_keyUser);

    if (userJson != null) {
      try {
        currentUser = jsonDecode(userJson);
      } catch (_) {}
    }

    if (authToken != null && authToken!.isNotEmpty) {
      // Validate token with backend /me endpoint
      final profileResp = await getProfile();
      if (profileResp['success'] == true) {
        final profileData = profileResp['data'];
        currentUser = (profileData is Map && profileData.containsKey('user'))
            ? profileData['user']
            : profileData;
        await prefs.setString(_keyUser, jsonEncode(currentUser));
        return true;
      } else {
        await clearSession();
        return false;
      }
    }
    return false;
  }

  /// Save session to persistent storage
  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    authToken = token;
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user));
  }

  /// Clear persistent session
  static Future<void> clearSession() async {
    authToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  /// Register a new Student or Faculty user in Laravel backend
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String role,
    required String password,
    required String passwordConfirmation,
    String? rollNumber,
    String? facultyId,
    String? department,
  }) async {
    final url = Uri.parse('$baseUrl/register');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'role': role,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'roll_number': rollNumber,
          'faculty_id': facultyId,
          'department': department,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 201 && data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];
        await saveSession(token, user);
      }

      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Registration status (${response.statusCode})',
        'data': data['data'] ?? {},
        'errors': data['errors'] ?? {},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': _formatExceptionMessage(e, defaultMessage: 'Connection failed. Please check backend server.'),
        'error': e.toString(),
      };
    }
  }

  /// Login user and retrieve Sanctum Bearer token
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];
        await saveSession(token, user);
      }

      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'message': data['message'] ?? (response.statusCode == 401 ? 'Invalid email or password' : 'Server error (${response.statusCode})'),
        'data': data['data'] ?? {},
        'errors': data['errors'] ?? {},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': _formatExceptionMessage(e, defaultMessage: 'Connection failed'),
        'error': e.toString(),
      };
    }
  }

  /// Login or register via Google credentials synced with backend MySQL
  static Future<Map<String, dynamic>> googleLogin({
    required String email,
    required String name,
    String? googleId,
    String? avatar,
    String? role,
    String? rollNumber,
  }) async {
    final url = Uri.parse('$baseUrl/google-login');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'name': name,
          'google_id': googleId,
          'avatar': avatar,
          'role': role,
          'roll_number': rollNumber,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];
        await saveSession(token, user);
      }

      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Google sign in status (${response.statusCode})',
        'data': data['data'] ?? {},
        'errors': data['errors'] ?? {},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': _formatExceptionMessage(e, defaultMessage: 'Connection error during Google login'),
        'error': e.toString(),
      };
    }
  }

  /// Logout user
  static Future<void> logout() async {
    if (authToken != null) {
      final url = Uri.parse('$baseUrl/logout');
      try {
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
        );
      } catch (_) {}
    }
    await clearSession();
  }

  /// Fetch authenticated user details
  /// Fetch user profile details
  static Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse('$baseUrl/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      final data = jsonDecode(response.body);
      _checkUnauthorized(response.statusCode);
      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'data': data['data'] ?? {},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': 'Failed to fetch user profile',
      };
    }
  }

  /// Update user profile in backend
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
    String? rollNumber,
    String? facultyId,
    String? department,
    String? bio,
    String? avatar,
  }) async {
    final url = Uri.parse('$baseUrl/profile');
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'roll_number': rollNumber,
          'faculty_id': facultyId,
          'department': department,
          'bio': bio,
          'avatar': avatar,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      _checkUnauthorized(response.statusCode);

      if (response.statusCode == 200 && data['success'] == true) {
        final updatedUser = data['data']['user'];
        if (authToken != null && updatedUser is Map<String, dynamic>) {
          await saveSession(authToken!, updatedUser);
        }
      }

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Profile update response',
        'data': data['data'] ?? {},
        'errors': data['errors'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to update profile ($e)'};
    }
  }

  /// Change user password
  static Future<Map<String, dynamic>> changePassword({
    String oldPassword = '',
    required String newPassword,
    required String confirmPassword,
  }) async {
    final url = Uri.parse('$baseUrl/change-password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirmation': confirmPassword,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      _checkUnauthorized(response.statusCode);

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Password update response',
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to change password ($e)'};
    }
  }

  /// Formats media URLs to use the production media route (/api/media/file/)
  static String? formatMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    String clean = rawUrl.trim();
    if (clean.contains('/storage/')) {
      clean = clean.replaceAll('/storage/', '/api/media/file/');
    }
    return clean;
  }

  /// Upload media file to structured backend storage (avatars, campaigns, questions, general)
  static Future<Map<String, dynamic>> uploadMedia({
    required List<int> fileBytes,
    required String fileName,
    String folder = 'general',
  }) async {
    final url = Uri.parse('$baseUrl/upload');
    try {
      final request = http.MultipartRequest('POST', url);
      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.fields['folder'] = folder;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      _checkUnauthorized(response.statusCode);

      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Media upload completed',
        'data': data['data'] ?? {},
      };
    } catch (e) {
      return {'success': false, 'message': 'Media upload failed ($e)'};
    }
  }

  /// Get list of active campaigns / announcements
  static Future<List<Map<String, dynamic>>> getCampaigns({String status = 'active'}) async {
    final url = Uri.parse('$baseUrl/campaigns?status=$status');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      _checkUnauthorized(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get list of active / upcoming quizzes
  static Future<List<Map<String, dynamic>>> getQuizzes({String status = 'active'}) async {
    final url = Uri.parse('$baseUrl/quizzes?status=$status');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      _checkUnauthorized(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Get details of a single quiz with questions
  static Future<Map<String, dynamic>?> getQuizDetails(int quizId) async {
    final url = Uri.parse('$baseUrl/quizzes/$quizId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      _checkUnauthorized(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Submit quiz attempt to backend with location, IP, and violation details
  static Future<Map<String, dynamic>> submitQuizAttempt({
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
    final url = Uri.parse('$baseUrl/quizzes/$quizId/submit');

    final Map<String, dynamic> formattedAnswers = {};
    userAnswers.forEach((key, value) {
      formattedAnswers[key.toString()] = value;
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'user_answers': formattedAnswers,
          'violations_count': violationsCount,
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
          'ip_address': ipAddress,
          'submission_type': submissionType,
          'auto_submit_reason': autoSubmitReason,
        }),
      );

      _checkUnauthorized(response.statusCode);

      final data = jsonDecode(response.body);
      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'data': data['data'] ?? {},
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': 'Failed to record quiz submission',
      };
    }
  }

  /// Get user's past quiz attempts
  static Future<List<Map<String, dynamic>>> getUserAttempts() async {
    final url = Uri.parse('$baseUrl/attempts');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      _checkUnauthorized(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  // --- ACADEMIC STRUCTURE FETCHERS FOR DROPDOWNS ---
  static Future<List<Map<String, dynamic>>> getUniversities() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/universities'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getColleges() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/colleges'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/departments'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/courses'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/branches'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSections() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/sections'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getSubsections() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/academic/subsections'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// Update user profile academic fields & mandatory phone
  static Future<Map<String, dynamic>> updateAcademicProfile({
    String? phone,
    String? facultyId,
    int? universityId,
    int? collegeId,
    int? departmentId,
    int? courseId,
    int? branchId,
    int? sectionId,
    int? subsectionId,
  }) async {
    final url = Uri.parse('$baseUrl/profile');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          if (phone != null) 'phone': phone,
          if (facultyId != null) 'faculty_id': facultyId,
          'university_id': universityId,
          'college_id': collegeId,
          'department_id': departmentId,
          'course_id': courseId,
          'branch_id': branchId,
          'section_id': sectionId,
          'subsection_id': subsectionId,
        }),
      );

      _checkUnauthorized(response.statusCode);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final updatedUser = data['data']['user'];
        if (updatedUser is Map<String, dynamic>) {
          await saveSession(authToken!, updatedUser);
        }
      }

      return {
        'statusCode': response.statusCode,
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Academic profile updated',
        'data': data['data'] ?? {},
        'errors': data['errors'],
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'success': false,
        'message': 'Failed to save academic profile',
      };
    }
  }

  /// Helper to extract clean user-facing error message from API response
  static String getErrorMessage(Map<String, dynamic> res, [String defaultMsg = 'An error occurred']) {
    if (res['errors'] != null && res['errors'] is Map && (res['errors'] as Map).isNotEmpty) {
      final errMap = res['errors'] as Map;
      final firstKey = errMap.keys.first;
      final firstVal = errMap[firstKey];
      if (firstVal is List && firstVal.isNotEmpty) {
        return firstVal.first.toString();
      } else if (firstVal is String) {
        return firstVal;
      }
    }
    if (res['message'] != null && res['message'].toString().isNotEmpty && res['message'] != 'Validation errors occurred') {
      return res['message'].toString();
    }
    return defaultMsg;
  }

  /// Get statistics summary for Faculty Dashboard
  static Future<Map<String, dynamic>?> getFacultyStats() async {
    final url = Uri.parse('$baseUrl/faculty/stats');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );
      _checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Get student submissions log for Faculty Dashboard
  static Future<List<Map<String, dynamic>>> getFacultySubmissions() async {
    final url = Uri.parse('$baseUrl/faculty/submissions');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );
      _checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['data'] as List).map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (_) {}
    return [];
  }

  /// Create a new Quiz (Faculty)
  static Future<Map<String, dynamic>> createQuiz({
    required String title,
    required String subject,
    required String instructor,
    required int durationMinutes,
    required String status,
    String? description,
    String? scheduledAt,
  }) async {
    final url = Uri.parse('$baseUrl/quizzes');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'title': title,
          'subject': subject,
          'instructor': instructor,
          'duration_minutes': durationMinutes,
          'status': status,
          'description': description ?? '',
          'scheduled_at': scheduledAt,
        }),
      );
      _checkUnauthorized(response.statusCode);
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Quiz creation response',
        'data': data['data'],
        'errors': data['errors'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to create quiz ($e)'};
    }
  }

  /// Delete a Quiz (Faculty)
  static Future<bool> deleteQuiz(int quizId) async {
    final url = Uri.parse('$baseUrl/quizzes/$quizId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );
      _checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Get subject & section allocations assigned to current faculty member
  static Future<List<Map<String, dynamic>>> getMyFacultyAllocations() async {
    final url = Uri.parse('$baseUrl/faculty/my-allocations');
    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );
      _checkUnauthorized(response.statusCode);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Add a Question to Quiz (Faculty)
  static Future<Map<String, dynamic>> addQuestionToQuiz({
    required int quizId,
    required String question,
    required String type,
    required List<String> options,
    required dynamic correctOption,
  }) async {
    final url = Uri.parse('$baseUrl/quizzes/$quizId/questions');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'question': question,
          'type': type,
          'options': options,
          'correct_option': correctOption,
        }),
      );
      _checkUnauthorized(response.statusCode);
      final data = jsonDecode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Add question response',
        'data': data['data'],
        'errors': data['errors'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to add question ($e)'};
    }
  }

  /// Checks if user profile setup is incomplete (Mandatory check for both Students & Faculty)
  static bool isProfileIncomplete(Map<String, dynamic> userData) {
    final role = (userData['role'] ?? 'student').toString().toLowerCase();

    if (role == 'faculty') {
      return (userData['phone'] == null || userData['phone'].toString().trim().isEmpty) ||
             (userData['university_id'] == null && userData['university'] == null) ||
             (userData['faculty_id'] == null || userData['faculty_id'].toString().trim().isEmpty);
    } else {
      return (userData['phone'] == null || userData['phone'].toString().trim().isEmpty) ||
             (userData['roll_number'] == null || userData['roll_number'].toString().trim().isEmpty) ||
             (userData['university_id'] == null && userData['university'] == null) ||
             (userData['college_id'] == null && userData['college'] == null) ||
             (userData['department_id'] == null && userData['department_model'] == null) ||
             (userData['course_id'] == null && userData['course'] == null) ||
             (userData['branch_id'] == null && userData['branch'] == null) ||
             (userData['section_id'] == null && userData['section'] == null) ||
             (userData['subsection_id'] == null && userData['subsection'] == null);
    }
  }
}
