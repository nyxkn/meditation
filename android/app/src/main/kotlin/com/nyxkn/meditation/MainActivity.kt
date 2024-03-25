package com.nyxkn.meditation

import android.app.NotificationManager
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.content.Context
import androidx.annotation.NonNull

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nyxkn.meditation/channelHelper"
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "openChannelSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    channelId?.let {
                        openChannelSettings(it)
                        result.success(null)
                    } ?: result.error("UNAVAILABLE", "Channel ID not available.", null)
                }

                "isChannelEnabled" -> {
                    val channelId = call.argument<String>("channelId")
                    channelId?.let {
                        result.success(isNotificationChannelEnabled(it))
                    } ?: result.error("UNAVAILABLE", "Channel ID not available.", null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isNotificationChannelEnabled(channelId: String): Boolean {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // For Android Oreo and above, check if the specific channel is enabled
            val channel = manager.getNotificationChannel(channelId)
            return channel?.importance != NotificationManager.IMPORTANCE_NONE
        } else {
            // For older versions, just assume true. Hopefully AwesomeNotifications takes care of that well enough
            return true;
        }
    }

    private fun openChannelSettings(channelId: String) {
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        }
        startActivity(intent)
    }
}
