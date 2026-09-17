package com.neodyit.acadova

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.neodyit.acadova/security"
    private var previousFilter: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

            when (call.method) {
                "enableSecureScreen" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

                    // Enable DND (Do Not Disturb) mode if policy access granted
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        try {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                previousFilter = notificationManager.currentInterruptionFilter
                                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "disableSecureScreen" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    try {
                        stopLockTask()
                    } catch (e: Exception) {}

                    // Restore previous DND mode
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        try {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                val filterToRestore = previousFilter ?: NotificationManager.INTERRUPTION_FILTER_ALL
                                notificationManager.setInterruptionFilter(filterToRestore)
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(true)
                }
                "startLockTask" -> {
                    try {
                        startLockTask()
                    } catch (e: Exception) {}
                    result.success(true)
                }
                "stopLockTask" -> {
                    try {
                        stopLockTask()
                    } catch (e: Exception) {}
                    result.success(true)
                }
                "isDndPermissionGranted" -> {
                    var isGranted = true
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        isGranted = notificationManager.isNotificationPolicyAccessGranted
                    }
                    result.success(isGranted)
                }
                "requestDndPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        if (!notificationManager.isNotificationPolicyAccessGranted) {
                            try {
                                val intent = android.content.Intent(android.provider.Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                startActivity(intent)
                            } catch (e: Exception) {}
                        }
                    }
                    result.success(true)
                }
                "enableDndMode" -> {
                    var success = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        try {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                previousFilter = notificationManager.currentInterruptionFilter
                                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                                success = true
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(success)
                }
                "disableDndMode" -> {
                    var success = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        try {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                val filterToRestore = previousFilter ?: NotificationManager.INTERRUPTION_FILTER_ALL
                                notificationManager.setInterruptionFilter(filterToRestore)
                                success = true
                            }
                        } catch (e: Exception) {}
                    }
                    result.success(success)
                }
                "isDndActive" -> {
                    var isActive = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && notificationManager != null) {
                        try {
                            isActive = notificationManager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_NONE ||
                                       notificationManager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY ||
                                       notificationManager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALARMS
                        } catch (e: Exception) {}
                    }
                    result.success(isActive)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
