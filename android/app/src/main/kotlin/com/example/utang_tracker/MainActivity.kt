package com.example.utang_tracker

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val channel = "com.example.utang_tracker/updater"
    private val exportChannel = "com.example.utang_tracker/export"
    private val importChannel = "com.example.utang_tracker/import"
    private val installSettingsRequest = 8403
    private val pickFileRequest = 8501
    private var pendingInstallSettingsResult: MethodChannel.Result? = null
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> {
                    result.success(Build.SUPPORTED_ABIS.toList())
                }

                "canInstallUnknownApps" -> {
                    val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(can)
                }

                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (pendingInstallSettingsResult != null) {
                            result.error("BUSY", "Install settings are already open", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName"),
                        )
                        pendingInstallSettingsResult = result
                        try {
                            startActivityForResult(intent, installSettingsRequest)
                        } catch (error: Exception) {
                            pendingInstallSettingsResult = null
                            result.error("SETTINGS_FAILED", error.message, null)
                        }
                    } else {
                        result.success(null)
                    }
                }

                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file not found at $path", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file,
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            exportChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFiles" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENT", "paths is required", null)
                        return@setMethodCallHandler
                    }
                    val mimeType = call.argument<String>("mimeType") ?: "text/csv"
                    try {
                        val uris = paths.map { path ->
                            FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                File(path),
                            )
                        }
                        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                            type = mimeType
                            putParcelableArrayListExtra(
                                Intent.EXTRA_STREAM,
                                ArrayList(uris),
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val clipData = ClipData.newUri(contentResolver, "Export", uris.first())
                        uris.drop(1).forEach { clipData.addItem(ClipData.Item(it)) }
                        intent.clipData = clipData
                        startActivity(Intent.createChooser(intent, "Share export"))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SHARE_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            importChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickCsvFiles" -> {
                    if (pendingPickResult != null) {
                        result.error("BUSY", "The file picker is already open", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(
                            Intent.EXTRA_MIME_TYPES,
                            arrayOf(
                                "text/csv",
                                "text/comma-separated-values",
                                "text/plain",
                                "application/vnd.ms-excel",
                                "application/octet-stream",
                            ),
                        )
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                    pendingPickResult = result
                    try {
                        startActivityForResult(intent, pickFileRequest)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.error("PICK_FAILED", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == installSettingsRequest) {
            val result = pendingInstallSettingsResult ?: return
            pendingInstallSettingsResult = null
            result.success(null)
        } else if (requestCode == pickFileRequest) {
            handlePickedFiles(data, resultCode)
        }
    }

    private fun handlePickedFiles(data: Intent?, resultCode: Int) {
        val pending = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return
        }

        val uris = mutableListOf<Uri>()
        val clipData = data?.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                uris.add(clipData.getItemAt(index).uri)
            }
        } else {
            val uri = data?.data
            if (uri != null) {
                uris.add(uri)
            }
        }
        if (uris.isEmpty()) {
            pending.success(null)
            return
        }

        try {
            val files = uris.map { uri ->
                val content = contentResolver.openInputStream(uri)?.use { stream ->
                    stream.readBytes().toString(Charsets.UTF_8)
                } ?: ""
                mapOf("name" to displayName(uri), "content" to content)
            }
            pending.success(files)
        } catch (e: Exception) {
            pending.error("READ_FAILED", e.message, null)
        }
    }

    private fun displayName(uri: Uri): String {
        val fallback = uri.lastPathSegment ?: "import.csv"
        return try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) {
                    cursor.getString(index) ?: fallback
                } else {
                    fallback
                }
            } ?: fallback
        } catch (e: Exception) {
            fallback
        }
    }
}
