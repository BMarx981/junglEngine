package app.hawkstreak.junglengine

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Audio arriving from outside the app.
 *
 * The intent filters in AndroidManifest.xml put junglEngine in the chooser
 * wherever audio turns up: Files, a browser download, a message attachment.
 * This is the other half of that, taking the `content://` URI those hand over
 * and turning it into a path the decoder can open.
 *
 * Incoming files are copied out and queued rather than pushed at Dart, because
 * a file can arrive before the engine exists. Dart asks for what is waiting
 * when it boots and again every time the app comes back to the foreground, and
 * opening a file always does one or the other.
 */
class MainActivity : FlutterActivity() {
    private val pending = mutableListOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        queue(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A second file arriving while the app is already up. singleTop, so the
        // activity is reused rather than stacked.
        setIntent(intent)
        queue(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "takePending") {
                    result.success(drain())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun drain(): List<String> {
        synchronized(pending) {
            val waiting = pending.toList()
            pending.clear()
            return waiting
        }
    }

    private fun queue(intent: Intent?) {
        for (uri in incomingUris(intent)) {
            val path = copyIn(uri) ?: continue
            synchronized(pending) { pending.add(path) }
        }
    }

    private fun incomingUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        return when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(extra(intent, Intent.EXTRA_STREAM))
            Intent.ACTION_SEND_MULTIPLE ->
                @Suppress("DEPRECATION")
                (intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList())
            else -> emptyList()
        }
    }

    private fun extra(
        intent: Intent,
        key: String
    ): Uri? =
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(key)
        }

    /**
     * Copies an incoming file into the app's cache.
     *
     * A `content://` URI is a permission, not a path, and the permission does
     * not outlive the intent. Copying now costs one pass over a few megabytes
     * and removes every question about when it stops working.
     */
    private fun copyIn(uri: Uri): String? {
        return try {
            val inbox = File(cacheDir, "junglengine-incoming").apply { mkdirs() }
            val destination = File(inbox, nameOf(uri))
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) return null
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            destination.absolutePath
        } catch (error: Exception) {
            android.util.Log.w("junglengine", "could not take in $uri", error)
            null
        }
    }

    /** The file's own name where the provider offers one, so the import is
     *  called what the user calls it. */
    private fun nameOf(uri: Uri): String {
        val fromProvider = runCatching {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val column = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (column >= 0 && cursor.moveToFirst()) cursor.getString(column) else null
            }
        }.getOrNull()
        val name = fromProvider ?: uri.lastPathSegment ?: "incoming-audio"
        // Whatever the provider says, this ends up as a file name.
        return name.replace(Regex("[^A-Za-z0-9._ -]"), "_").take(80)
    }

    private companion object {
        const val CHANNEL = "junglengine/incoming"
    }
}
