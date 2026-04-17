package com.gigshield.gigshield_verify

import android.content.Context
import android.os.Build
import android.provider.Settings

class LocationNativeHelper(private val context: Context) {

    /**
     * Returns true if ADB / Developer Options are enabled on the device.
     * Developer Options being on is a soft signal that mock locations could be active.
     */
    fun isDeveloperOptionsEnabled(): Boolean {
        return try {
            Settings.Global.getInt(
                context.contentResolver,
                Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
                0,
            ) == 1
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Returns true if "Allow mock locations" is enabled.
     * On Android >= 6, this is controlled per-app via Developer Options.
     * This setting signals intent to spoof GPS.
     *
     * Note: On API 23+, individual apps need to set themselves as a mock location provider.
     * We check the legacy global setting as a supplementary signal.
     */
    fun isMockLocationEnabled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // On API 23+, the legacy flag is removed; rely on the global dev setting +
                // the isFromMockProvider flag in geolocator instead.
                // We check if any mock location app is set.
                val mockLocationApp = Settings.Secure.getString(
                    context.contentResolver,
                    "mock_location", // not a public constant but works on most ROMs
                )
                !mockLocationApp.isNullOrBlank() && mockLocationApp != "0"
            } else {
                @Suppress("DEPRECATION")
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION,
                    0,
                ) == 1
            }
        } catch (e: Exception) {
            false
        }
    }
}
