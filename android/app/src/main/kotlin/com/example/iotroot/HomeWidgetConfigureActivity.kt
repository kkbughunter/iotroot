package com.example.iotroot

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class HomeWidgetConfigureActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.home_widget_configure)

        val existing = HomeWidgetStorage.loadConfig(this, widgetId)
        val catalog = HomeWidgetStorage.loadCatalog(this)
        val topics = if (catalog.isEmpty()) existing?.topics.orEmpty() else catalog
        val selectedPaths = existing?.topics?.mapTo(mutableSetOf()) { it.topic }.orEmpty()

        val name = findViewById<EditText>(R.id.widget_config_name).apply {
            setText(existing?.name ?: "My home")
        }
        val topicsContainer = findViewById<LinearLayout>(R.id.widget_config_topics)
        val empty = findViewById<TextView>(R.id.widget_config_empty)
        val count = findViewById<TextView>(R.id.widget_config_count)
        val addButton = findViewById<Button>(R.id.widget_config_add)
        val checks = mutableListOf<CheckBox>()

        fun refreshSelection() {
            val selectedCount = checks.count(CheckBox::isChecked)
            count.text = if (selectedCount == 1) "1 selected" else "$selectedCount selected"
            addButton.isEnabled = selectedCount > 0
            addButton.alpha = if (selectedCount > 0) 1f else .72f
        }

        topics.forEach { topic ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.CENTER_VERTICAL
                minimumHeight = dp(74)
                setPadding(dp(13), dp(10), dp(10), dp(10))
                isClickable = true
                isFocusable = true
                contentDescription = "Select ${topic.name}"
            }
            val icon = ImageView(this).apply {
                setImageResource(
                    if (topic.enabled) R.drawable.ic_widget_power_on
                    else R.drawable.ic_widget_power_off,
                )
                scaleType = ImageView.ScaleType.CENTER_INSIDE
            }
            row.addView(icon, LinearLayout.LayoutParams(dp(40), dp(40)).apply {
                marginEnd = dp(12)
            })

            val labels = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
            }
            labels.addView(TextView(this).apply {
                text = topic.name
                textSize = 15f
                setTextColor(Color.rgb(21, 33, 27))
                typeface = Typeface.DEFAULT_BOLD
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.END
            }, matchWrap())
            labels.addView(TextView(this).apply {
                text = topic.topic
                textSize = 11f
                setTextColor(Color.rgb(104, 117, 110))
                maxLines = 1
                ellipsize = android.text.TextUtils.TruncateAt.MIDDLE
                setPadding(0, dp(3), 0, 0)
            }, matchWrap())
            row.addView(labels, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))

            val check = CheckBox(this).apply {
                tag = topic
                isChecked = topic.topic in selectedPaths ||
                    (existing == null && topics.size == 1)
                buttonTintList = ColorStateList(
                    arrayOf(
                        intArrayOf(android.R.attr.state_checked),
                        intArrayOf(),
                    ),
                    intArrayOf(Color.rgb(20, 125, 90), Color.rgb(139, 150, 144)),
                )
            }
            checks += check
            row.addView(check, LinearLayout.LayoutParams(dp(48), dp(48)))

            fun refreshRow() {
                row.setBackgroundResource(
                    if (check.isChecked) R.drawable.widget_config_topic_selected_background
                    else R.drawable.widget_config_topic_background,
                )
                row.isSelected = check.isChecked
                row.contentDescription =
                    "${topic.name}, ${if (check.isChecked) "selected" else "not selected"}"
            }
            check.setOnCheckedChangeListener { _, _ ->
                refreshRow()
                refreshSelection()
            }
            row.setOnClickListener { check.performClick() }
            refreshRow()
            topicsContainer.addView(row, matchWrap().apply { bottomMargin = dp(10) })
        }

        empty.visibility = if (topics.isEmpty()) View.VISIBLE else View.GONE
        topicsContainer.visibility = if (topics.isEmpty()) View.GONE else View.VISIBLE
        refreshSelection()

        addButton.setOnClickListener {
            val selected = checks
                .filter(CheckBox::isChecked)
                .map { it.tag as HomeWidgetTopic }
            if (selected.isEmpty()) {
                Toast.makeText(this, "Choose at least one topic", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            HomeWidgetStorage.saveConfig(
                this,
                widgetId,
                HomeWidgetConfig(name.text.toString().trim().ifEmpty { "My home" }, selected),
            )
            selected.forEach { topic ->
                HomeWidgetStorage.setPower(this, widgetId, topic.topic, topic.enabled)
            }
            HomeControlWidget.update(this, AppWidgetManager.getInstance(this), widgetId)
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
            )
            finish()
        }
    }

    private fun matchWrap() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
