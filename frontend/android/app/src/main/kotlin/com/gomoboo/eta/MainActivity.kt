package com.gomoboo.eta

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val pokeChannelId = "eta_poke_notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eta/system_notifications"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showPoke" -> {
                    val id = call.argument<String>("id")
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")

                    if (id == null || title == null || body == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "찌르기 알림 정보가 필요합니다.",
                            null
                        )
                    } else {
                        try {
                            result.success(showPoke(id, title, body))
                        } catch (error: Exception) {
                            result.error(
                                "NOTIFICATION_ERROR",
                                error.message,
                                null
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun showPoke(
        id: String,
        title: String,
        body: String
    ): Boolean {

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val manager = getSystemService(NOTIFICATION_SERVICE)
            as NotificationManager

        val sound = RingtoneManager.getDefaultUri(
            RingtoneManager.TYPE_NOTIFICATION
        )

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                pokeChannelId,
                "찌르기 알림",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "친구가 보낸 찌르기 알림"
                enableVibration(true)
                setSound(
                    sound,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
            }

            manager.createNotificationChannel(channel)
            Notification.Builder(this, pokeChannelId)
        } else {
            Notification.Builder(this)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_ALL)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_eta_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .build()

        manager.notify(id, 52, notification)
        return true
    }
}
