package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_clock)
            val time = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
            views.setTextViewText(R.id.clock_text, time)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
