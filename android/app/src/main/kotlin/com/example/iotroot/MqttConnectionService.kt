package com.example.iotroot

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import org.eclipse.paho.client.mqttv3.MqttClient
import org.eclipse.paho.client.mqttv3.MqttConnectOptions
import org.eclipse.paho.client.mqttv3.persist.MemoryPersistence
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MqttConnectionService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val pendingWidgetPublishes = AtomicInteger(0)
    @Volatile private var keepAliveRequested = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        if (intent?.action == ACTION_WIDGET_PUBLISH) {
            publishWidgetCommand(intent)
        } else {
            keepAliveRequested = true
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Removing IoTRoot from recents is an explicit request to end the
        // background connection. Ending the process also closes the MQTT
        // socket immediately instead of leaving a cached process connected.
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Device connection",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the IoTRoot device connection active in the background"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("IoTRoot is connected")
            .setContentText("Your device connection is active in the background")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun publishWidgetCommand(intent: Intent) {
        val widgetId = intent.getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        val topic = intent.getStringExtra(HomeControlWidget.EXTRA_TOPIC).orEmpty()
        val enabled = intent.getBooleanExtra(HomeControlWidget.EXTRA_POWER, false)
        val previous = intent.getBooleanExtra(HomeControlWidget.EXTRA_PREVIOUS_POWER, !enabled)
        pendingWidgetPublishes.incrementAndGet()
        executor.execute {
            var succeeded = false
            try {
                val connection = HomeWidgetStorage.loadConnection(this)
                    ?: throw IllegalStateException("Widget credentials are unavailable")
                require(topic.isNotBlank())
                val scheme = if (connection.tls) "ssl" else "tcp"
                val server = "$scheme://${connection.host}:${connection.port}"
                val client = MqttClient(server, connection.clientId, MemoryPersistence())
                try {
                    client.connect(MqttConnectOptions().apply {
                        userName = connection.username
                        password = connection.password.toCharArray()
                        isCleanSession = true
                        connectionTimeout = 10
                        keepAliveInterval = 20
                        isAutomaticReconnect = false
                    })
                    client.publish(
                        topic,
                        "{\"status\":\"${if (enabled) "on" else "off"}\"}".toByteArray(),
                        1,
                        true,
                    )
                    succeeded = true
                } finally {
                    if (client.isConnected) client.disconnect(1_000)
                    client.close()
                }
            } catch (_: Exception) {
                // The optimistic state below is rolled back when delivery fails.
            } finally {
                if (!succeeded && widgetId >= 0) {
                    HomeWidgetStorage.setPower(this, widgetId, topic, previous)
                }
                HomeControlWidget.updateAll(this)
                if (pendingWidgetPublishes.decrementAndGet() == 0 && !keepAliveRequested) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        }
    }

    companion object {
        const val ACTION_WIDGET_PUBLISH = "com.astraval.iotroot.widget.PUBLISH"
        private const val CHANNEL_ID = "iotroot_device_connection"
        private const val NOTIFICATION_ID = 1101
    }
}
