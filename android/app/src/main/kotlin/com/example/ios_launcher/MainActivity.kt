package com.example.ios_launcher

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.app.role.RoleManager
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.net.Uri

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ios_launcher/apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    Thread {
                        val apps = getInstalledApps()
                        runOnUiThread {
                            result.success(apps)
                        }
                    }.start()
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        launchApp(packageName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Package name is null", null)
                    }
                }
                "uninstallApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        uninstallApp(packageName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Package name is null", null)
                    }
                }
                "isDefaultLauncher" -> {
                    result.success(isDefaultLauncher())
                }
                "openDefaultLauncherSettings" -> {
                    openDefaultLauncherSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null)
        intent.addCategory(Intent.CATEGORY_LAUNCHER)
        
        val apps = pm.queryIntentActivities(intent, 0)
        val appList = mutableListOf<Map<String, Any>>()

        for (resolveInfo in apps) {
            val packageName = resolveInfo.activityInfo.packageName
            val label = resolveInfo.loadLabel(pm).toString()
            val iconDrawable = resolveInfo.loadIcon(pm)
            
            val iconBytes = drawableToByteArray(iconDrawable)
            
            val appMap = mapOf(
                "packageName" to packageName,
                "label" to label,
                "icon" to (iconBytes ?: ByteArray(0))
            )
            appList.add(appMap)
        }
        
        return appList.sortedBy { (it["label"] as String).lowercase() }
    }

    private fun launchApp(packageName: String) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
    }

    private fun uninstallApp(packageName: String) {
        try {
            val intent = Intent(Intent.ACTION_DELETE).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "Failed to uninstall app: ${e.message}", e)
        }
    }

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
        val currentDefaultPackage = resolveInfo?.activityInfo?.packageName
        return currentDefaultPackage == packageName
    }

    private val REQUEST_CODE_HOME_ROLE = 1001

    private fun openDefaultLauncherSettings() {
        android.util.Log.d("ios_launcher", "openDefaultLauncherSettings called, SDK: ${Build.VERSION.SDK_INT}")

        // Phương án 1: RoleManager (Android 10+) — BẮT BUỘC dùng startActivityForResult
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                    startActivityForResult(intent, REQUEST_CODE_HOME_ROLE)
                    android.util.Log.d("ios_launcher", "RoleManager dialog launched via startActivityForResult")
                    return
                }
            } catch (e: Exception) {
                android.util.Log.e("ios_launcher", "RoleManager failed: ${e.message}", e)
            }
        }

        // Phương án 2: Mở Settings.ACTION_HOME_SETTINGS
        try {
            startActivity(Intent(Settings.ACTION_HOME_SETTINGS))
            android.util.Log.d("ios_launcher", "ACTION_HOME_SETTINGS opened")
            return
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "ACTION_HOME_SETTINGS failed: ${e.message}", e)
        }

        // Phương án 3: Mở Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS
        try {
            startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
            android.util.Log.d("ios_launcher", "ACTION_MANAGE_DEFAULT_APPS_SETTINGS opened")
            return
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "ACTION_MANAGE_DEFAULT_APPS_SETTINGS failed: ${e.message}", e)
        }

        // Phương án 4: Mở trang App Info của ứng dụng
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            android.util.Log.d("ios_launcher", "ACTION_APPLICATION_DETAILS_SETTINGS opened")
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "All methods failed: ${e.message}", e)
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 100
        val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 100
        
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    override fun onResume() {
        super.onResume()
        hideSystemNavigationBar()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemNavigationBar()
        }
    }

    private fun hideSystemNavigationBar() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController
            if (controller != null) {
                controller.hide(android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            )
        }
    }
}
