package com.gigshield.gigshield_verify

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val recordingChannel = "com.gigshield/recording"
    private val appChannel = "com.gigshield/app_detection"
    private val locationNativeChannel = "com.gigshield/location_native"

    private var projectionManager: MediaProjectionManager? = null
    private var pendingRecordingResult: MethodChannel.Result? = null
    private var pendingSessionId: String? = null

    // Bound service reference (non-null while recording)
    private var recordService: ScreenRecordService? = null
    private var serviceBound = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            recordService = (binder as ScreenRecordService.RecordBinder).getService()
            serviceBound = true
        }
        override fun onServiceDisconnected(name: ComponentName?) {
            recordService = null
            serviceBound = false
        }
    }

    private val appDetectionHelper by lazy { AppDetectionHelper(this) }
    private val locationNativeHelper by lazy { LocationNativeHelper(this) }

    companion object {
        const val REQUEST_MEDIA_PROJECTION = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Recording Channel ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, recordingChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val sessionId = call.argument<String>("sessionId") ?: "unknown"
                        pendingRecordingResult = result
                        pendingSessionId = sessionId
                        requestScreenCapture()
                    }
                    "stopRecording" -> {
                        val path = recordService?.stopRecording()
                        unbindRecordService()
                        result.success(path)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── App Detection Channel ────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkInstalledApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        result.success(appDetectionHelper.checkInstalledApps(packages))
                    }
                    "getForegroundApp" -> {
                        result.success(appDetectionHelper.getForegroundApp())
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Location Native Channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationNativeChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeveloperOptionsEnabled" -> {
                        result.success(locationNativeHelper.isDeveloperOptionsEnabled())
                    }
                    "isMockLocationEnabled" -> {
                        result.success(locationNativeHelper.isMockLocationEnabled())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── Screen Capture Request ───────────────────────────────────────────────

    private fun requestScreenCapture() {
        // Step 1: Start + bind the foreground service BEFORE showing the dialog.
        // The service calls startForeground() in onCreate(), so by the time the
        // user interacts with the dialog and onActivityResult fires, the service
        // is guaranteed to be in the foreground state.
        val serviceIntent = Intent(this, ScreenRecordService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)

        // Step 2: Show the system screen-capture consent dialog
        projectionManager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val captureIntent = projectionManager!!.createScreenCaptureIntent()
        startActivityForResult(captureIntent, REQUEST_MEDIA_PROJECTION)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_MEDIA_PROJECTION) return

        if (resultCode == Activity.RESULT_OK && data != null) {
            // Step 3: Pass the grant token to the service via onStartCommand.
            // The service is already in foreground, so getMediaProjection() inside
            // the service will succeed.
            val metrics = resources.displayMetrics
            val width = (metrics.widthPixels / 2) * 2
            val height = (metrics.heightPixels / 2) * 2

            val serviceIntent = Intent(this, ScreenRecordService::class.java).apply {
                putExtra(ScreenRecordService.EXTRA_RESULT_CODE, resultCode)
                putExtra(ScreenRecordService.EXTRA_DATA, data)
                putExtra(ScreenRecordService.EXTRA_SESSION_ID, pendingSessionId ?: "session")
                putExtra(ScreenRecordService.EXTRA_WIDTH, width)
                putExtra(ScreenRecordService.EXTRA_HEIGHT, height)
                putExtra(ScreenRecordService.EXTRA_DENSITY, metrics.densityDpi)
            }

            // Set callback BEFORE starting — the service may call it synchronously
            recordService?.onRecordingStarted = { success, _ ->
                pendingRecordingResult?.success(success)
                pendingRecordingResult = null
                pendingSessionId = null
            }

            // If service not bound yet, reply after a short delay via the intent
            if (!serviceBound) {
                // Fallback: service wasn't bound yet; start with extra and let it reply
                // via a post on the main thread (rare path)
                startService(serviceIntent)
                android.os.Handler(mainLooper).postDelayed({
                    recordService?.onRecordingStarted = { success, _ ->
                        pendingRecordingResult?.success(success)
                        pendingRecordingResult = null
                        pendingSessionId = null
                    }
                }, 200)
            } else {
                startService(serviceIntent)
            }
        } else {
            // User denied or cancelled
            pendingRecordingResult?.success(false)
            pendingRecordingResult = null
            pendingSessionId = null
            unbindRecordService()
            stopService(Intent(this, ScreenRecordService::class.java))
        }
    }

    private fun unbindRecordService() {
        if (serviceBound) {
            unbindService(serviceConnection)
            serviceBound = false
            recordService = null
        }
    }

    override fun onDestroy() {
        unbindRecordService()
        super.onDestroy()
    }
}
