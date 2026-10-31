package com.example.iotroot

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews

class HomeControlWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { update(context, appWidgetManager, it) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_TOGGLE) return
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        val topic = intent.getStringExtra(EXTRA_TOPIC) ?: return
        val config = HomeWidgetStorage.loadConfig(context, widgetId) ?: return
        if (config.topics.none { it.topic == topic }) return

        val oldValue = HomeWidgetStorage.power(context, widgetId, topic)
        val newValue = !oldValue
        HomeWidgetStorage.setPower(context, widgetId, topic, newValue)
        update(context, AppWidgetManager.getInstance(context), widgetId)

        val pendingResult = goAsync()
        if (MainActivity.publishWidgetToggle(topic, newValue) { handled, delivered ->
                if (!handled) {
                    startNativePublish(context, widgetId, topic, newValue, oldValue)
                } else if (delivered) {
                    updateAll(context)
                } else {
                    HomeWidgetStorage.setPower(context, widgetId, topic, oldValue)
                    update(context, AppWidgetManager.getInstance(context), widgetId)
                }
                pendingResult.finish()
            }) {
            return
        }
        startNativePublish(context, widgetId, topic, newValue, oldValue)
        pendingResult.finish()
    }

    private fun startNativePublish(
        context: Context,
        widgetId: Int,
        topic: String,
        enabled: Boolean,
        previous: Boolean,
    ) {
        val publish = Intent(context, MqttConnectionService::class.java).apply {
            action = MqttConnectionService.ACTION_WIDGET_PUBLISH
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(EXTRA_TOPIC, topic)
            putExtra(EXTRA_POWER, enabled)
            putExtra(EXTRA_PREVIOUS_POWER, previous)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(publish)
        } else {
            context.startService(publish)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { HomeWidgetStorage.removeConfig(context, it) }
    }

    companion object {
        const val ACTION_TOGGLE = "com.astraval.iotroot.widget.TOGGLE"
        const val EXTRA_TOPIC = "widget_topic"
        const val EXTRA_POWER = "widget_power"
        const val EXTRA_PREVIOUS_POWER = "widget_previous_power"

        fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.home_control_widget)
            val config = HomeWidgetStorage.loadConfig(context, widgetId)
            views.removeAllViews(R.id.widget_topic_list)
            views.setTextViewText(R.id.widget_name, config?.name ?: "IoTRoot")
            if (config == null || config.topics.isEmpty()) {
                views.setTextViewText(R.id.widget_empty, "Open IoTRoot to set up this widget")
                views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
                val slots = listOf(
                    R.id.widget_slot_1,
                    R.id.widget_slot_2,
                    R.id.widget_slot_3,
                    R.id.widget_slot_4,
                )
                config.topics.chunked(4).forEachIndexed { rowIndex, topics ->
                    val row = RemoteViews(context.packageName, R.layout.home_control_widget_row)
                    topics.forEachIndexed { columnIndex, topic ->
                        val topicIndex = rowIndex * 4 + columnIndex
                        row.addView(
                            slots[columnIndex],
                            topicTile(context, widgetId, topicIndex, topic),
                        )
                    }
                    views.addView(R.id.widget_topic_list, row)
                }
            }

            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
                views.setOnClickPendingIntent(
                    R.id.widget_header,
                    PendingIntent.getActivity(
                        context,
                        widgetId,
                        launch,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            manager.updateAppWidget(widgetId, views)
        }

        private fun topicTile(
            context: Context,
            widgetId: Int,
            index: Int,
            item: HomeWidgetTopic,
        ): RemoteViews {
            val enabled = HomeWidgetStorage.power(context, widgetId, item.topic)
            val tile = RemoteViews(context.packageName, R.layout.home_control_widget_topic)
            tile.setTextViewText(R.id.widget_topic_name, item.name)
            tile.setImageViewResource(
                R.id.widget_power,
                if (enabled) R.drawable.ic_widget_power_on else R.drawable.ic_widget_power_off,
            )
            tile.setContentDescription(
                R.id.widget_topic_tile,
                "Turn ${item.name} ${if (enabled) "off" else "on"}",
            )
            val toggle = Intent(context, HomeControlWidget::class.java).apply {
                action = ACTION_TOGGLE
                data = Uri.parse("iotroot://widget/$widgetId/$index")
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(EXTRA_TOPIC, item.topic)
            }
            val toggleIntent = PendingIntent.getBroadcast(
                context,
                widgetId * 1000 + index,
                toggle,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            tile.setOnClickPendingIntent(R.id.widget_topic_tile, toggleIntent)
            tile.setOnClickPendingIntent(R.id.widget_power, toggleIntent)
            return tile
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HomeControlWidget::class.java))
            ids.forEach { update(context, manager, it) }
        }

        fun syncStates(context: Context, topics: List<HomeWidgetTopic>) {
            val byPath = topics.associateBy { it.topic }
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, HomeControlWidget::class.java))
            ids.forEach { widgetId ->
                HomeWidgetStorage.loadConfig(context, widgetId)?.topics?.forEach { configured ->
                    byPath[configured.topic]?.let { current ->
                        HomeWidgetStorage.setPower(
                            context,
                            widgetId,
                            configured.topic,
                            current.enabled,
                        )
                    }
                }
                update(context, manager, widgetId)
            }
        }
    }
}
