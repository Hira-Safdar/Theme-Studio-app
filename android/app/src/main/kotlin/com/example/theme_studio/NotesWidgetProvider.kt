package com.example.theme_studio

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

class NotesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val style = WidgetStyleHelper.styleFor(context, "notes")
        val mode = WidgetStyleHelper.modeFor(context, "notes")
        // SharedPreferences se user ka saved note text padhte hain --
        // Flutter side saveNoteText() isi key mein likhta hai.
        val prefs = context.getSharedPreferences("widget_styles", Context.MODE_PRIVATE)
        val noteText = prefs.getString("notes_text", null)
            ?: "Tap to add a note"

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_notes)
            WidgetStyleHelper.applyBackground(views, R.id.widget_root, style, mode)
            WidgetStyleHelper.applyTextColors(views, mode, secondaryIds = listOf(R.id.notes_text))
            WidgetStyleHelper.applyCustomization(context, views, secondaryIds = listOf(R.id.notes_text))
            WidgetStyleHelper.applyBackgroundCustomization(context, views, R.id.widget_root, style, mode)
            views.setTextViewText(R.id.notes_text, noteText)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                WidgetClickActions.buildClickPendingIntent(
                    context, NotesWidgetProvider::class.java, "notes", widgetId
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