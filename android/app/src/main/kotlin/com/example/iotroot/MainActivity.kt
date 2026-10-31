package com.example.iotroot

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astraval.iotroot/background_connection",
        ).setMethodCallHandler { call, result ->
            val service = Intent(this, MqttConnectionService::class.java)
            when (call.method) {
                "start" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(service)
                    } else {
                        startService(service)
                    }
                    result.success(null)
                }
                "stop" -> {
                    stopService(service)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.astraval.iotroot/home_widget",
        ).also { channel ->
            activeWidgetChannel = channel
        }
        widgetChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "addWidget", "syncWidgetData" -> {
                    try {
                        val arguments = call.arguments as? Map<*, *>
                            ?: throw IllegalArgumentException("Missing widget details")
                        val topics = (arguments["topics"] as? List<*>)
                            .orEmpty()
                            .mapNotNull { raw ->
                                val item = raw as? Map<*, *> ?: return@mapNotNull null
                                val topic = item["topic"]?.toString()?.trim().orEmpty()
                                if (topic.isEmpty()) null else HomeWidgetTopic(
                                    item["name"]?.toString()?.trim().orEmpty().ifEmpty { topic },
                                    topic,
                                    item["enabled"] as? Boolean ?: false,
                                )
                            }
                        if (topics.isEmpty()) throw IllegalArgumentException("No publish topics")
                        HomeWidgetStorage.saveCatalog(this, topics)
                        HomeWidgetStorage.saveConnection(
                            this,
                            HomeWidgetConnection(
                                host = arguments["host"]?.toString()?.trim().orEmpty(),
                                port = (arguments["port"] as Number).toInt(),
                                tls = arguments["tls"] as? Boolean ?: false,
                                clientId = arguments["clientId"]?.toString().orEmpty(),
                                username = arguments["username"]?.toString().orEmpty(),
                                password = arguments["password"]?.toString().orEmpty(),
                            ),
                        )
                        HomeControlWidget.syncStates(this, topics)
                        if (call.method == "syncWidgetData") {
                            result.success(null)
                        } else {
                            val manager = AppWidgetManager.getInstance(this)
                            val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                manager.isRequestPinAppWidgetSupported
                            val requested = supported && manager.requestPinAppWidget(
                                ComponentName(this, HomeControlWidget::class.java),
                                null,
                                null,
                            )
                            result.success(requested)
                        }
                    } catch (error: Exception) {
                        result.error("WIDGET_SETUP_FAILED", error.message, null)
                    }
                }
                "clearConnection" -> {
                    HomeWidgetStorage.clearConnection(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (activeWidgetChannel === widgetChannel) activeWidgetChannel = null
        widgetChannel = null
        super.onDestroy()
    }

    companion object {
        @Volatile private var activeWidgetChannel: MethodChannel? = null

        fun publishWidgetToggle(
            topic: String,
            enabled: Boolean,
            completion: (handled: Boolean, delivered: Boolean) -> Unit,
        ): Boolean {
            val channel = activeWidgetChannel ?: return false
            channel.invokeMethod(
                "publishToggle",
                mapOf("topic" to topic, "enabled" to enabled),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val response = result as? Map<*, *>
                        completion(
                            response?.get("handled") == true,
                            response?.get("delivered") == true,
                        )
                    }
                    override fun error(code: String, message: String?, details: Any?) = completion(true, false)
                    override fun notImplemented() = completion(false, false)
                },
            )
            return true
        }
    }
}
