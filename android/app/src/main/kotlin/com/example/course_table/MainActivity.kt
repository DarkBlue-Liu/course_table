package com.example.course_table

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
    private fun certificates(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "course_table/updates").setMethodCallHandler { call, result ->
            try {
                val installed = packageManager.getPackageInfo(packageName, flags())
                when (call.method) {
                    "info" -> result.success(mapOf("applicationId" to packageName, "versionName" to installed.versionName,
                        "versionCode" to version(installed), "certificates" to certificates(installed).toList()))
                    "install" -> {
                        val path = requireNotNull(call.argument<String>("path"))
                        val apk = File(path).canonicalFile
                        val directory = File(cacheDir, "updates").canonicalFile
                        require(apk.parentFile == directory && apk.name == "update.apk") { "Invalid update path" }
                        val candidate = requireNotNull(packageManager.getPackageArchiveInfo(apk.path, flags())) { "无法读取 APK" }
                        require(candidate.packageName == packageName) { "APK 包名不匹配" }
                        require(version(candidate) == call.argument<Number>("versionCode")?.toLong() && version(candidate) > version(installed)) { "APK 版本不匹配或不是新版" }
                        val signing = certificates(installed)
                        require(signing.isNotEmpty() && signing == certificates(candidate)) { "APK 签名不匹配，请勿卸载原应用" }
                        if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                            startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                            result.success("permission")
                        } else {
                            val uri = FileProvider.getUriForFile(this, "$packageName.updates", apk)
                            startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                            result.success("opened")
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("UPDATE_ERROR", e.message, null) }
        }
    }
}
