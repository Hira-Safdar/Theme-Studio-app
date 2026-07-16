package com.example.theme_studio

import android.accessibilityservice.AccessibilityService
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button

/// Ye service Home Screen ke UPAR overlay draw karti hai -- current launcher
/// ko replace nahi karti, bas uske upar float karti hai (isi liye ye kisi bhi
/// launcher, Samsung One UI ho ya koi third-party, sab ke sath kaam karti hai).
///
/// NOTE: Production quality gesture detection (edge-swipe-down) is se zyada
/// complex hota hai (aksar ek chhota transparent "trigger strip" View screen
/// ke top par rakha jaata hai jo touch events sunta hai). Yahan simplicity
/// ke liye ek basic overlay show/hide ka structure diya gaya hai.
class ControlCenterAccessibilityService : AccessibilityService() {

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addTriggerStrip()
    }

    /// Screen ke top par ek patla transparent strip jo swipe-down detect karta hai.
    private fun addTriggerStrip() {
        val trigger = View(this)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            24, // sirf 24px height ka trigger zone
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP

        trigger.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_MOVE) {
                showControlCenterOverlay()
            }
            false
        }

        windowManager?.addView(trigger, params)
    }

    private fun showControlCenterOverlay() {
        if (overlayView != null) return // already showing

        val inflater = LayoutInflater.from(this)
        overlayView = inflater.inflate(R.layout.control_center_overlay, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP

        // Overlay ke andar ek "close" button -- production me flashlight,
        // wifi-settings-launch, brightness-slider jaise real toggles honge.
        overlayView?.findViewById<Button>(R.id.btn_close)?.setOnClickListener {
            hideControlCenterOverlay()
        }

        windowManager?.addView(overlayView, params)
    }

    private fun hideControlCenterOverlay() {
        overlayView?.let {
            windowManager?.removeView(it)
            overlayView = null
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Is service ko hum sirf overlay ke liye use kar rahe hain,
        // AccessibilityEvent tracking abhi zaroori nahi hai.
    }

    override fun onInterrupt() {
        hideControlCenterOverlay()
    }
}
