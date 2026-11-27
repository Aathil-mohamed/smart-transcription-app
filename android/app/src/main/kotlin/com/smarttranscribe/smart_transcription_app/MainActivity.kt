package com.smarttranscribe.smart_transcription_app

import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.smarttranscribe/diagnostics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAudioEffectsStatus") {
                try {
                    val effects = mapOf(
                        "noiseSuppressorAvailable" to NoiseSuppressor.isAvailable(),
                        "acousticEchoCancelerAvailable" to AcousticEchoCanceler.isAvailable(),
                        "automaticGainControlAvailable" to AutomaticGainControl.isAvailable()
                    )
                    result.success(effects)
                } catch (e: Exception) {
                    result.error("AUDIOFX_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

