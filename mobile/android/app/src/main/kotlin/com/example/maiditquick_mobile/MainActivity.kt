package com.example.maiditquick_mobile

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "maiditquick/kyc_document_picker"
    private val pickDocumentRequestCode = 43102
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickDocument" -> openDocumentPicker(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openDocumentPicker(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("PICKER_IN_PROGRESS", "A document picker is already open.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/pdf", "image/jpeg", "image/png"))
        }
        startActivityForResult(intent, pickDocumentRequestCode)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickDocumentRequestCode) return
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        try {
            val uri = data.data!!
            val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
            if (mimeType !in setOf("application/pdf", "image/jpeg", "image/png")) {
                result.error("UNSUPPORTED_FILE", "Choose a PDF, JPG or PNG document.", null)
                return
            }
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            if (bytes == null) {
                result.error("READ_FAILED", "Could not read the selected document.", null)
                return
            }
            result.success(mapOf("name" to displayName(uri), "mimeType" to mimeType, "bytes" to bytes))
        } catch (exception: Exception) {
            result.error("PICK_FAILED", exception.message ?: "Could not choose a document.", null)
        }
    }

    private fun displayName(uri: Uri): String {
        var name = "identity-document"
        val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
        cursor?.use {
            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && it.moveToFirst()) name = it.getString(nameIndex)
        }
        return name
    }
}
