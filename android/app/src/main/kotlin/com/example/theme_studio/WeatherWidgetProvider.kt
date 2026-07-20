package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/// Location ki tarah, temp/condition bhi yahan se seedha fetch nahi hote
/// (network call hai, widget update ke andar karna slow/unsafe hai) --
/// MainActivity.fetchAndCacheCurrentWeather() Open-Meteo se real data
/// laa kar cache karta hai (location fetch hone ke turant baad), yahan se
/// bas padh lete hain. Pehli dafa jab tak cache khaali ho, fallback text
/// dikhta hai.
class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val style = WidgetStyleHelper.styleFor(context, "weather")
        val mode = WidgetStyleHelper.modeFor(context, "weather")
        val prefs = context.getSharedPreferences(WidgetStyleHelper.PREFS_NAME, Context.MODE_PRIVATE)
        val locationText = prefs.getString("weather_location", null)
        val tempText = prefs.getString("weather_temp", null) ?: "--°"
        val conditionText = prefs.getString("weather_condition", null) ?: "Waiting for location…"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_weather)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(
                views, mode,
                primaryIds = listOf(R.id.weather_temp_text),
                secondaryIds = listOf(R.id.weather_condition_text, R.id.weather_location_text)
            )
            views.setTextViewText(R.id.weather_temp_text, tempText)
            views.setTextViewText(R.id.weather_condition_text, conditionText)
            if (locationText.isNullOrBlank()) {
                views.setViewVisibility(R.id.weather_location_text, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.weather_location_text, android.view.View.VISIBLE)
                views.setTextViewText(R.id.weather_location_text, locationText)
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, WeatherWidgetProvider::class.java, "weather", widgetId
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: android.content.Intent) {
        if (intent.action == WidgetClickActions.ACTION_WIDGET_CLICK) {
            val type = intent.getStringExtra(WidgetClickActions.EXTRA_WIDGET_TYPE) ?: return
            WidgetClickActions.handleClick(context, type)
            return
        }
        super.onReceive(context, intent)
    }
}