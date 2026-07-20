package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/// Battery/Clock ke ulta -- isko koi external API nahi chahiye, device ki
/// apni date/time hi kaafi hai, isliye ye "TODO" nahi hai, poora functional
/// hai.
class CalendarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val style = WidgetStyleHelper.styleFor(context, "calendar")
        val today = Date()
        val dayName = SimpleDateFormat("EEE", Locale.getDefault()).format(today).uppercase()
        val dateNum = SimpleDateFormat("d", Locale.getDefault()).format(today)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_calendar)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style)
            views.setTextViewText(R.id.calendar_day_text, dayName)
            views.setTextViewText(R.id.calendar_date_text, dateNum)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}