package com.example.iotroot

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
