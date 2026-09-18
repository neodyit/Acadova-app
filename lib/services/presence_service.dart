import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/app_config.dart';
import 'analytics_service.dart';
import 'api_service.dart';

class PresenceService with WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _heartbeatTimer;
  Timer? _flushTimer;

  String _appVersion = AppConfig.appVersion;
  String _platform = 'unknown';
  String _sessionId = '';
  bool _initialized = false;

  final List<Map<String, dynamic>> _eventBuffer = [];
  String? _currentScreen;
  DateTime? _screenStartTime;

  /// Get active session identifier
  String get sessionId => _sessionId;

  /// Initialize presence tracker, fetch app version and device platform
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecondsSinceEpoch % 8999))}';

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = AppConfig.appVersion;
    }

    if (kIsWeb) {
      _platform = 'web';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _platform = 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _platform = 'ios';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      _platform = 'windows';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      _platform = 'macos';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      _platform = 'linux';
    }

    WidgetsBinding.instance.addObserver(this);
    startTracking();
  }

  /// Start periodic heartbeats and engagement flushes
  void startTracking() {
    stopTracking();

    // Instant heartbeat on startup
    _sendHeartbeat();

    // Periodic heartbeat every 60 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendHeartbeat();
    });

    // Periodic engagement flush every 60 seconds
    _flushTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      flushEngagementEvents();
    });
  }

  /// Stop timers (e.g. when app is backgrounded or user logs out)
  void stopTracking() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Record entering a screen
  void trackScreen(String screenName, {String? action, Map<String, dynamic>? metadata}) {
    final now = DateTime.now();

    // Calculate duration on previous screen
    if (_currentScreen != null && _screenStartTime != null) {
      final duration = now.difference(_screenStartTime!).inSeconds;
      if (duration > 0) {
        _queueEvent(
          screenName: _currentScreen!,
          action: 'view_duration',
          durationSeconds: duration,
        );
      }
    }

    _currentScreen = screenName;
    _screenStartTime = now;

    // Log screen entry
    _queueEvent(
      screenName: screenName,
      action: action ?? 'enter_screen',
      metadata: metadata,
    );
  }

  /// Queue an engagement event into memory buffer
  void _queueEvent({
    required String screenName,
    String? action,
    int durationSeconds = 0,
    Map<String, dynamic>? metadata,
  }) {
    _eventBuffer.add({
      'screen_name': screenName,
      'action': action,
      'duration_seconds': durationSeconds,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Flush automatically if buffer grows beyond 15 items
    if (_eventBuffer.length >= 15) {
      flushEngagementEvents();
    }
  }

  /// Asynchronously send queued engagement logs to backend
  Future<void> flushEngagementEvents() async {
    if (_eventBuffer.isEmpty) return;

    final eventsToSend = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();

    unawaited(
      ApiService.sendEngagementEvents(
        sessionId: _sessionId,
        events: eventsToSend,
      ).catchError((_) => false),
    );
  }

  /// Fire instant heartbeat
  void _sendHeartbeat() {
    if (ApiService.authToken == null || ApiService.authToken!.isEmpty) return;

    unawaited(
      ApiService.sendHeartbeat(
        appVersion: _appVersion,
        platform: _platform,
      ).catchError((_) => false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startTracking();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Record remaining duration on active screen
      if (_currentScreen != null && _screenStartTime != null) {
        final duration = DateTime.now().difference(_screenStartTime!).inSeconds;
        if (duration > 0) {
          _queueEvent(
            screenName: _currentScreen!,
            action: 'backgrounded_duration',
            durationSeconds: duration,
          );
        }
        _screenStartTime = DateTime.now();
      }
      flushEngagementEvents();
      stopTracking();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopTracking();
  }
}

class PresenceNavigatorObserver extends NavigatorObserver {
  final PresenceService _presence = PresenceService();

  void _sendScreenView(Route<dynamic>? route) {
    if (route != null && route.settings.name != null && route.settings.name!.isNotEmpty) {
      final name = route.settings.name!;
      _presence.trackScreen(name);
      AnalyticsService().logScreenView(screenName: name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sendScreenView(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _sendScreenView(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _sendScreenView(newRoute);
  }
}
