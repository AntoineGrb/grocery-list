package fr.antoinegrb.kadi

import android.content.ClipboardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Presse-papiers de « Photo depuis un lien » : le texte, ou l'image
        // copiée (« Copier l'image » de Chrome met une adresse content://,
        // que le collage texte de Flutter ignore).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kadi/clipboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(
                        try {
                            readClip()
                        } catch (e: Exception) {
                            null
                        },
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun readClip(): Map<String, Any>? {
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val item = clip.getItemAt(0)
        val uri = item.uri
        if (uri != null) {
            val type = contentResolver.getType(uri)
                ?: clip.description.getMimeType(0)
            if (type != null && type.startsWith("image/")) {
                contentResolver.openInputStream(uri)?.use { input ->
                    val bytes = input.readNBytesCompat(MAX_IMAGE_BYTES + 1)
                    if (bytes.size <= MAX_IMAGE_BYTES) return mapOf("image" to bytes)
                }
                return null
            }
        }
        val text = item.text?.toString() ?: item.coerceToText(this)?.toString()
        return if (text.isNullOrBlank()) null else mapOf("text" to text)
    }

    private fun java.io.InputStream.readNBytesCompat(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        var total = 0
        while (total < limit) {
            val read = read(buffer, 0, minOf(buffer.size, limit - total))
            if (read < 0) break
            out.write(buffer, 0, read)
            total += read
        }
        return out.toByteArray()
    }

    companion object {
        private const val MAX_IMAGE_BYTES = 10 * 1024 * 1024
    }
}
