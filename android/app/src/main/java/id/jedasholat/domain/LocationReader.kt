package id.jedasholat.domain

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.CancellationSignal
import android.os.Build
import android.os.Looper
import androidx.core.content.ContextCompat
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

object LocationReader {
    suspend fun current(context: Context): Pair<Double, Double>? {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
        val manager = context.getSystemService(LocationManager::class.java)
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
        val last = providers.filter { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) }
            .mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .filter { it.time > System.currentTimeMillis() - 24 * 60 * 60_000L }
            .maxByOrNull { it.time }
        if (last != null) return last.latitude to last.longitude
        val provider = providers.firstOrNull { runCatching { manager.isProviderEnabled(it) }.getOrDefault(false) } ?: return null
        return withTimeoutOrNull(15_000L) {
            suspendCancellableCoroutine { continuation ->
                val signal = CancellationSignal()
                val listener = android.location.LocationListener { location ->
                    if (continuation.isActive) continuation.resume(location?.let { it.latitude to it.longitude })
                }
                continuation.invokeOnCancellation { signal.cancel() }
                runCatching {
                    if (Build.VERSION.SDK_INT >= 30) {
                        manager.getCurrentLocation(provider, signal, context.mainExecutor) { location ->
                            if (continuation.isActive) continuation.resume(location?.let { it.latitude to it.longitude })
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
                        continuation.invokeOnCancellation { runCatching { manager.removeUpdates(listener) } }
                    }
                }.onFailure { if (continuation.isActive) continuation.resume(null) }
            }
        }
    }
}
