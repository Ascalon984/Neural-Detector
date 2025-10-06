package com.example.ai_text_checker

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedOutputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "ai_text_checker/saveFileToDownloads"

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result ->
			if (call.method == "saveFile") {
				val args = call.arguments as? Map<*, *>
				val filename = args?.get("filename") as? String
				val bytes = args?.get("bytes") as? ByteArray

				if (filename == null || bytes == null) {
					result.error("invalid_args", "filename or bytes missing", null)
					return@setMethodCallHandler
				}

				try {
					val savedUri = saveToDownloads(filename, bytes)
					if (savedUri != null) {
						result.success(savedUri.toString())
					} else {
						result.error("save_failed", "Could not save file", null)
					}
				} catch (e: Exception) {
					Log.e("MainActivity", "save error", e)
					result.error("exception", e.message, null)
				}
			} else {
				result.notImplemented()
			}
		}
	}

	private fun saveToDownloads(filename: String, bytes: ByteArray): android.net.Uri? {
		val resolver = applicationContext.contentResolver

		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val values = ContentValues().apply {
				put(MediaStore.Downloads.DISPLAY_NAME, filename)
				put(MediaStore.Downloads.MIME_TYPE, if (filename.endsWith(".xlsx")) "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" else "text/csv")
				put(MediaStore.Downloads.IS_PENDING, 1)
			}

			val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
			val item = resolver.insert(collection, values)
			if (item != null) {
				var out: OutputStream? = null
				try {
					out = resolver.openOutputStream(item)
					val bos = BufferedOutputStream(out)
					bos.write(bytes)
					bos.flush()
					bos.close()

					values.clear()
					values.put(MediaStore.Downloads.IS_PENDING, 0)
					resolver.update(item, values, null, null)
					return item
				} catch (e: Exception) {
					Log.e("MainActivity", "write error", e)
					try { out?.close() } catch (_: Exception) {}
					// attempt to delete
					try { resolver.delete(item, null, null) } catch (_: Exception) {}
					return null
				}
			} else null
		} else {
			// Pre-Q fallback: write to external public Downloads dir
			try {
				val downloads = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
				val file = java.io.File(downloads, filename)
				val fos = java.io.FileOutputStream(file)
				fos.write(bytes)
				fos.flush()
				fos.close()
				return android.net.Uri.fromFile(file)
			} catch (e: Exception) {
				Log.e("MainActivity", "fallback write error", e)
				return null
			}
		}
	}
}
