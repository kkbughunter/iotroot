package com.example.iotroot

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class HomeWidgetTopic(
    val name: String,
    val topic: String,
    val enabled: Boolean = false,
)

data class HomeWidgetConfig(
    val name: String,
    val topics: List<HomeWidgetTopic>,
)

data class HomeWidgetConnection(
    val host: String,
    val port: Int,
    val tls: Boolean,
    val clientId: String,
    val username: String,
    val password: String,
)

object HomeWidgetStorage {
    private const val PREFS = "iotroot_home_widget"
    private const val CATALOG = "topic_catalog"
    private const val CONNECTION = "connection"
    private const val KEY_ALIAS = "iotroot_home_widget_credentials"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveCatalog(context: Context, topics: List<HomeWidgetTopic>) {
        val array = JSONArray()
        topics.distinctBy { it.topic }.forEach { item ->
            array.put(
                JSONObject()
                    .put("name", item.name)
                    .put("topic", item.topic)
                    .put("enabled", item.enabled),
            )
        }
        prefs(context).edit().putString(CATALOG, array.toString()).apply()
    }

    fun loadCatalog(context: Context): List<HomeWidgetTopic> = try {
        val array = JSONArray(prefs(context).getString(CATALOG, "[]"))
        buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                val topic = item.optString("topic").trim()
                if (topic.isNotEmpty()) {
                    add(
                        HomeWidgetTopic(
                            item.optString("name", topic),
                            topic,
                            item.optBoolean("enabled", false),
                        ),
                    )
                }
            }
        }
    } catch (_: Exception) {
        emptyList()
    }

    fun saveConnection(context: Context, connection: HomeWidgetConnection) {
        val json = JSONObject()
            .put("host", connection.host)
            .put("port", connection.port)
            .put("tls", connection.tls)
            .put("clientId", connection.clientId)
            .put("username", connection.username)
            .put("password", connection.password)
            .toString()
        prefs(context).edit().putString(CONNECTION, encrypt(json)).apply()
    }

    fun loadConnection(context: Context): HomeWidgetConnection? = try {
        val encrypted = prefs(context).getString(CONNECTION, null) ?: return null
        val json = JSONObject(decrypt(encrypted))
        HomeWidgetConnection(
            host = json.getString("host"),
            port = json.getInt("port"),
            tls = json.getBoolean("tls"),
            clientId = json.getString("clientId"),
            username = json.getString("username"),
            password = json.getString("password"),
        )
    } catch (_: Exception) {
        null
    }

    fun clearConnection(context: Context) {
        prefs(context).edit().remove(CONNECTION).remove(CATALOG).apply()
    }

    fun saveConfig(context: Context, widgetId: Int, config: HomeWidgetConfig) {
        val topics = JSONArray()
        config.topics.forEach { item ->
            topics.put(JSONObject().put("name", item.name).put("topic", item.topic))
        }
        val json = JSONObject().put("name", config.name).put("topics", topics)
        prefs(context).edit().putString(configKey(widgetId), json.toString()).apply()
    }

    fun loadConfig(context: Context, widgetId: Int): HomeWidgetConfig? = try {
        val raw = prefs(context).getString(configKey(widgetId), null) ?: return null
        val json = JSONObject(raw)
        val array = json.getJSONArray("topics")
        val topics = buildList {
            for (index in 0 until array.length()) {
                val item = array.getJSONObject(index)
                add(HomeWidgetTopic(item.getString("name"), item.getString("topic")))
            }
        }
        HomeWidgetConfig(json.optString("name", "My home"), topics)
    } catch (_: Exception) {
        null
    }

    fun removeConfig(context: Context, widgetId: Int) {
        val editor = prefs(context).edit().remove(configKey(widgetId))
        prefs(context).all.keys
            .filter { it.startsWith("state:$widgetId:") }
            .forEach(editor::remove)
        editor.apply()
    }

    fun power(context: Context, widgetId: Int, topic: String): Boolean =
        prefs(context).getBoolean(stateKey(widgetId, topic), false)

    fun setPower(context: Context, widgetId: Int, topic: String, enabled: Boolean) {
        prefs(context).edit().putBoolean(stateKey(widgetId, topic), enabled).apply()
    }

    private fun configKey(widgetId: Int) = "config:$widgetId"
    private fun stateKey(widgetId: Int, topic: String) = "state:$widgetId:$topic"

    private fun key(): SecretKey {
        val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray()), Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val bytes = Base64.decode(value, Base64.NO_WRAP)
        require(bytes.size > 12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)))
    }
}
