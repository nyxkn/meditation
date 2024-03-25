package com.nyxkn.meditation

import android.app.NotificationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodChannel

import android.content.Intent
import android.provider.Settings

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
        val channel = manager.getNotificationChannel(channelId)
        return channel?.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun openChannelSettings(channelId: String) {
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        }
        startActivity(intent)
    }
}
