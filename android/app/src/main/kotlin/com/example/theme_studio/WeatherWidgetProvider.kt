package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/// NOTE: Abhi koi real weather API wire nahi hui -- ye demo/placeholder
/// data dikhata hai. Jab weather API (jaise OpenWeatherMap) integrate ho,
/// bas neeche wali 2 lines (temp/condition) real data se replace karni
/// hongi -- style/layout system already ready hai, alag se kuch nahi
/// badalna padega.
class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val style = WidgetStyleHelper.styleFor(context, "weather")
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_weather)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style)
            views.setTextViewText(R.id.weather_temp_text, "24°") // TODO: real weather API
            views.setTextViewText(R.id.weather_condition_text, "Partly cloudy") // TODO: real weather API
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}