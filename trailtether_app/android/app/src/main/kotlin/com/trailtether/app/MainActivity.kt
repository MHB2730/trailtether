package com.trailtether.app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val inboundChannelName = "com.trailtether.app/inbound_files"
    private var inboundChannel: MethodChannel? = null
    private var initialPayload: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        inboundChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            inboundChannelName,
        )
        inboundChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFile" -> result.success(initialPayload ?: readGpxPayload(intent))
                else -> result.notImplemented()
            }
        }

        initialPayload = readGpxPayload(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payload = readGpxPayload(intent) ?: return
        inboundChannel?.invokeMethod("openGpx", payload)
    }

    private fun readGpxPayload(intent: Intent?): Map<String, Any>? {
        if (intent?.action != Intent.ACTION_VIEW) return null

        val uri = intent.data ?: return null
        val filename = displayName(uri)
        if (!filename.endsWith(".gpx", ignoreCase = true)) return null

        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
        return mapOf(
            "filename" to filename,
            "bytes" to bytes,
        )
    }

    private fun displayName(uri: Uri): String {
        if (uri.scheme == "content") {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0 && cursor.moveToFirst()) {
                    return cursor.getString(nameIndex)
                }
            }
        }

        return uri.lastPathSegment?.substringAfterLast('/') ?: "imported.gpx"
    }
}
