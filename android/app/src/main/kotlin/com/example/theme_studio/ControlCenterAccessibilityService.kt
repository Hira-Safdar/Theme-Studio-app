package com.example.theme_studio

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.SeekBar
import android.widget.Switch

/// Ye service Home Screen ke UPAR overlay draw karti hai -- current launcher
/// ko replace nahi karti, bas uske upar float karti hai (isi liye ye kisi bhi
/// launcher, Samsung One UI ho ya koi third-party, sab ke sath kaam karti hai).
///
/// Screen 50-50 split: right half swipe-down = our control center,
/// left half swipe-down = system control center (Android default).
class ControlCenterAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "ControlCenter"
    }

    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    
    // Swipe-down gesture tracking
    private var initialY = 0f
    private val swipeThreshold = 80 // minimum vertical pixels to trigger

    override fun onServiceConnected() {
        super.onServiceConnected()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addTriggerStrip()
        Log.d(TAG, "Service connected, trigger strip added")
    }

    /// Custom View that reliably receives touch events from WindowManager
    private inner class TriggerView(context: Context) : View(context) {
        init {
            isClickable = true
            isFocusable = true
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialY = event.y
                    Log.d(TAG, "ACTION_DOWN at y=${event.y}")
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaY = event.y - initialY
                    Log.d(TAG, "ACTION_MOVE deltaY=$deltaY")
                    if (deltaY > swipeThreshold) {
                        Log.d(TAG, "Swipe threshold reached, showing overlay")
                        showControlCenterOverlay()
                        initialY = Float.MAX_VALUE // prevent re-trigger
                    }
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    Log.d(TAG, "ACTION_UP/CANCEL")
                    return true
                }
            }
            return super.onTouchEvent(event)
        }
    }

    /// Screen ke RIGHT 50% ke TOP par ek transparent strip jo
    /// swipe-down detect karta hai.
    private fun addTriggerStrip() {
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val halfWidth = screenWidth / 2
        val triggerHeight = 200 // px -- top par strip

        val params = WindowManager.LayoutParams(
            halfWidth,
            triggerHeight,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.END or Gravity.TOP

        val trigger = TriggerView(this)
        windowManager?.addView(trigger, params)
        Log.d(TAG, "Trigger added: ${halfWidth}x${triggerHeight} at top-right")
    }

    private fun showControlCenterOverlay() {
        if (overlayView != null) return // already showing

        val inflater = LayoutInflater.from(this)
        overlayView = inflater.inflate(R.layout.control_center_overlay, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP

        setupControlToggles()

        windowManager?.addView(overlayView, params)
    }

    private fun setupControlToggles() {
        overlayView ?: return

        // Close button
        overlayView?.findViewById<Button>(R.id.btn_close)?.setOnClickListener {
            hideControlCenterOverlay()
        }

        // WiFi toggle
        overlayView?.findViewById<Switch>(R.id.switch_wifi)?.apply {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            isChecked = wifiManager.isWifiEnabled
            @Suppress("DEPRECATION")
            setOnCheckedChangeListener { _, isChecked ->
                @Suppress("DEPRECATION")
                wifiManager.isWifiEnabled = isChecked
            }
        }

        // Bluetooth toggle (opens settings since direct toggle requires permissions)
        overlayView?.findViewById<View>(R.id.btn_bluetooth)?.setOnClickListener {
            val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }

        // Flashlight toggle
        overlayView?.findViewById<Switch>(R.id.switch_flashlight)?.apply {
            setOnCheckedChangeListener { _, isChecked ->
                toggleFlashlight(isChecked)
            }
        }

        // Brightness slider
        overlayView?.findViewById<SeekBar>(R.id.seekbar_brightness)?.apply {
            max = 255
            progress = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                128
            )
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        try {
                            Settings.System.putInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS,
                                progress
                            )
                        } catch (e: Exception) {
                            // WRITE_SETTINGS permission not granted
                        }
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }

        // Volume slider
        overlayView?.findViewById<SeekBar>(R.id.seekbar_volume)?.apply {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            progress = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_MUSIC,
                            progress,
                            0
                        )
                    }
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) {}
                override fun onStopTrackingTouch(seekBar: SeekBar?) {}
            })
        }

        // Settings button
        overlayView?.findViewById<View>(R.id.btn_settings)?.setOnClickListener {
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun toggleFlashlight(on: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
                val cameraId = cameraManager.cameraIdList[0]
                cameraManager.setTorchMode(cameraId, on)
            }
        } catch (e: Exception) {
            // Camera permission not granted or no flash available
        }
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
