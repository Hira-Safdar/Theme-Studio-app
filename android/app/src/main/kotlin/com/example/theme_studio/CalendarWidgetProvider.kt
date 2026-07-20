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
        val mode = WidgetStyleHelper.modeFor(context, "calendar")
        val today = Date()
        val dayName = SimpleDateFormat("EEE", Locale.getDefault()).format(today).uppercase()
        val dateNum = SimpleDateFormat("d", Locale.getDefault()).format(today)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_calendar)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(
                views, mode,
                secondaryIds = listOf(R.id.calendar_day_text),
                primaryIds = listOf(R.id.calendar_date_text)
            )
            views.setTextViewText(R.id.calendar_day_text, dayName)
            views.setTextViewText(R.id.calendar_date_text, dateNum)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, CalendarWidgetProvider::class.java, "calendar", widgetId
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