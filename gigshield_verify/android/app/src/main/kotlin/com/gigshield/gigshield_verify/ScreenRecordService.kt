package com.gigshield.gigshield_verify

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Binder
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScreenRecordService : Service() {

    companion object {
        const val CHANNEL_ID = "gigshield_recording"
        const val NOTIF_ID = 1001
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_DATA = "data"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_WIDTH = "width"
        const val EXTRA_HEIGHT = "height"
        const val EXTRA_DENSITY = "density"
    }

    inner class RecordBinder : Binder() {
        fun getService(): ScreenRecordService = this@ScreenRecordService
    }

    private val binder = RecordBinder()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaRecorder: MediaRecorder? = null
    var outputPath: String? = null
        private set

    var onRecordingStarted: ((Boolean, String?) -> Unit)? = null

    // Required callback for Android 14+ (API 34)
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // MediaProjection was stopped (by system or user revocation)
            cleanupRecording()
        }
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        // Android 14+ requirement: Start with a placeholder or no type first
        // unless we have the permission token already.
        startForeground(NOTIF_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
        val data: Intent? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_DATA)
        }
        val sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: "session"
        val width = intent.getIntExtra(EXTRA_WIDTH, 0)
        val height = intent.getIntExtra(EXTRA_HEIGHT, 0)
        val density = intent.getIntExtra(EXTRA_DENSITY, 0)

        // Only start recording if we received the projection grant data
        if (data != null && width > 0 && height > 0) {
            val mgr = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mgr.getMediaProjection(resultCode, data)

            // Android 14 (API 34+): Update the service type ONLY after we have the projection token
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIF_ID,
                    buildNotification(),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            }

            // Android 14+ (API 34): MUST register callback before createVirtualDisplay
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                mediaProjection!!.registerCallback(projectionCallback, mainHandler)
            }

            val success = startRecording(sessionId, width, height, density)
            onRecordingStarted?.invoke(success, if (success) outputPath else null)
        }

        return START_STICKY
    }

    private fun startRecording(sessionId: String, width: Int, height: Int, density: Int): Boolean {
        return try {
            val outputDir = getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir
            if (!outputDir.exists()) outputDir.mkdirs()

            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            val outputFile = File(outputDir, "verify_${sessionId.take(8)}_$timestamp.mp4")
            outputPath = outputFile.absolutePath

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }

            mediaRecorder!!.apply {
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(outputFile.absolutePath)
                setVideoSize(width, height)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setVideoEncodingBitRate(2_000_000)
                setVideoFrameRate(30)
                prepare()
            }

            virtualDisplay = mediaProjection!!.createVirtualDisplay(
                "GigShieldCapture",
                width,
                height,
                density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder!!.surface,
                null,
                null,
            )

            mediaRecorder!!.start()
            true
        } catch (e: Exception) {
            e.printStackTrace()
            outputPath = null
            false
        }
    }

    fun stopRecording(): String? {
        val path = outputPath
        cleanupRecording()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        return path
    }

    private fun cleanupRecording() {
        try {
            mediaRecorder?.apply {
                stop()
                reset()
                release()
            }
        } catch (_: Exception) { }
        mediaRecorder = null

        virtualDisplay?.release()
        virtualDisplay = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            try { mediaProjection?.unregisterCallback(projectionCallback) } catch (_: Exception) { }
        }
        mediaProjection?.stop()
        mediaProjection = null
        outputPath = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "GigShield Recording",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active while screen verification is in progress"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GigShield Verify")
            .setContentText("Screen verification in progress…")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        cleanupRecording()
        super.onDestroy()
    }
}
