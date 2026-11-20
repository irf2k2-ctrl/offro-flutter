package com.offro.app

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Phase E: country hint for the phone-number screens. TelephonyManager.getSimCountryIso() and
        // getNetworkCountryIso() need NO permission (no READ_PHONE_STATE). Only the two-letter country codes are
        // returned; no number, no SIM serial, nothing else. Any failure returns nulls and the app falls back to
        // the device locale, then India.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.offro.app/device_country")
            .setMethodCallHandler { call, result ->
                if (call.method == "getCountryIsos") {
                    val out = HashMap<String, String?>()
                    try {
                        val tm = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                        out["sim"] = tm?.simCountryIso?.takeIf { it.isNotBlank() }
                        out["network"] = tm?.networkCountryIso?.takeIf { it.isNotBlank() }
                    } catch (e: Exception) {
                        out["sim"] = null
                        out["network"] = null
                    }
                    result.success(out)
                } else {
                    result.notImplemented()
                }
            }
    }
}
