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
import android.app.WallpaperManager
import android.graphics.LinearGradient
import android.graphics.Shader
import android.graphics.Paint
import java.io.File
import java.io.FileOutputStream
import io.flutter.FlutterInjector

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ios_launcher/apps"
    private val REQUEST_CODE_PICK_IMAGE = 1002
    private var pendingPickImageResult: MethodChannel.Result? = null

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
                        val success = launchApp(packageName)
                        result.success(success)
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
                "pickImageFromGallery" -> {
                    pendingPickImageResult = result
                    val intent = Intent(Intent.ACTION_PICK).apply {
                        type = "image/*"
                    }
                    try {
                        startActivityForResult(intent, REQUEST_CODE_PICK_IMAGE)
                    } catch (e: Exception) {
                        pendingPickImageResult = null
                        result.error("PICK_ERROR", "Failed to start image picker: ${e.message}", null)
                    }
                }
                "setGradientWallpaper" -> {
                    val color1 = call.argument<Long>("color1")?.toInt()
                    val color2 = call.argument<Long>("color2")?.toInt()
                    if (color1 != null && color2 != null) {
                        Thread {
                            val success = setGradientWallpaper(color1, color2)
                            runOnUiThread {
                                result.success(success)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Colors are null", null)
                    }
                }
                "getWallpaperSettings" -> {
                    result.success(getWallpaperSettings())
                }
                "setAssetWallpaper" -> {
                    val assetPath = call.argument<String>("assetPath")
                    if (assetPath != null) {
                        Thread {
                            val success = setAssetWallpaper(assetPath)
                            runOnUiThread {
                                result.success(success)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Asset path is null", null)
                    }
                }
                "getWidgetSettings" -> {
                    result.success(getWidgetSettings())
                }
                "saveWidgetSettings" -> {
                    val showClock = call.argument<Boolean>("showClock") ?: false
                    val showWeather = call.argument<Boolean>("showWeather") ?: false
                    val showBattery = call.argument<Boolean>("showBattery") ?: false
                    saveWidgetSettings(showClock, showWeather, showBattery)
                    result.success(true)
                }
                "saveGridLayout" -> {
                    val layout = call.argument<List<String>>("layout")
                    if (layout != null) {
                        saveGridLayout(layout)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Layout is null", null)
                    }
                }
                "getGridLayout" -> {
                    result.success(getGridLayout())
                }
                "saveDockLayout" -> {
                    val layout = call.argument<List<String>>("layout")
                    if (layout != null) {
                        saveDockLayout(layout)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Layout is null", null)
                    }
                }
                "getDockLayout" -> {
                    result.success(getDockLayout())
                }
                "getBatteryLevel" -> {
                    val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                    val level = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    result.success(level)
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

    private fun launchApp(packageName: String): Boolean {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        return if (launchIntent != null) {
            try {
                // Add FLAG_ACTIVITY_NO_ANIMATION flag
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                
                // Create options with zero/no custom animations
                val options = android.app.ActivityOptions.makeCustomAnimation(this, 0, 0)
                startActivity(launchIntent, options.toBundle())
                
                // Legacy transition override for immediately removing transition animation
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
                true
            } catch (e: Exception) {
                android.util.Log.e("ios_launcher", "Failed to start activity: ${e.message}", e)
                false
            }
        } else {
            false
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_IMAGE) {
            val result = pendingPickImageResult
            pendingPickImageResult = null
            if (resultCode == RESULT_OK && data?.data != null) {
                val uri = data.data!!
                Thread {
                    try {
                        val imageFile = File(filesDir, "wallpaper.png")
                        contentResolver.openInputStream(uri)?.use { input ->
                            FileOutputStream(imageFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        
                        // Set system wallpaper
                        contentResolver.openInputStream(uri)?.use { input ->
                            WallpaperManager.getInstance(applicationContext).setStream(input)
                        }

                        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
                        prefs.edit().apply {
                            putString("wallpaper_type", "image")
                            putString("wallpaper_image_path", imageFile.absolutePath)
                            apply()
                        }

                        runOnUiThread {
                            result?.success(imageFile.absolutePath)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("ios_launcher", "Failed to save/set wallpaper: ${e.message}", e)
                        runOnUiThread {
                            result?.error("WALLPAPER_ERROR", e.message, null)
                        }
                    }
                }.start()
            } else {
                result?.success(null)
            }
        }
    }

    private fun setGradientWallpaper(color1: Int, color2: Int): Boolean {
        return try {
            val width = 1080
            val height = 2400
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint().apply {
                shader = LinearGradient(
                    0f, 0f, 0f, height.toFloat(),
                    color1, color2,
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
            WallpaperManager.getInstance(applicationContext).setBitmap(bitmap)
            
            val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString("wallpaper_type", "gradient")
                putInt("color1", color1)
                putInt("color2", color2)
                apply()
            }
            true
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "Failed to set gradient wallpaper: ${e.message}", e)
            false
        }
    }

    private fun setAssetWallpaper(assetPath: String): Boolean {
        return try {
            val loader = FlutterInjector.instance().flutterLoader()
            val lookupKey = loader.getLookupKeyForAsset(assetPath)
            assets.open(lookupKey).use { inputStream ->
                WallpaperManager.getInstance(applicationContext).setStream(inputStream)
            }
            
            val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString("wallpaper_type", "asset")
                putString("wallpaper_image_path", assetPath)
                apply()
            }
            true
        } catch (e: Exception) {
            android.util.Log.e("ios_launcher", "Failed to set asset wallpaper: ${e.message}", e)
            false
        }
    }

    private fun getWallpaperSettings(): Map<String, Any?> {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        return mapOf(
            "type" to prefs.getString("wallpaper_type", "gradient"),
            "color1" to prefs.getInt("color1", 0xFF1D2671.toInt()),
            "color2" to prefs.getInt("color2", 0xFFC33764.toInt()),
            "imagePath" to prefs.getString("wallpaper_image_path", null)
        )
    }

    private fun getWidgetSettings(): Map<String, Boolean> {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        return mapOf(
            "showClock" to prefs.getBoolean("show_clock", false),
            "showWeather" to prefs.getBoolean("show_weather", false),
            "showBattery" to prefs.getBoolean("show_battery", false)
        )
    }

    private fun saveWidgetSettings(showClock: Boolean, showWeather: Boolean, showBattery: Boolean) {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("show_clock", showClock)
            putBoolean("show_weather", showWeather)
            putBoolean("show_battery", showBattery)
            apply()
        }
    }

    private fun saveGridLayout(layout: List<String>) {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("grid_layout", layout.joinToString(","))
            apply()
        }
    }

    private fun getGridLayout(): List<String> {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        val layoutStr = prefs.getString("grid_layout", "") ?: ""
        if (layoutStr.isEmpty()) {
            return emptyList()
        }
        return layoutStr.split(",")
    }

    private fun saveDockLayout(layout: List<String>) {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("dock_layout", layout.joinToString(","))
            apply()
        }
    }

    private fun getDockLayout(): List<String> {
        val prefs = getSharedPreferences("ios_launcher_prefs", Context.MODE_PRIVATE)
        val layoutStr = prefs.getString("dock_layout", "") ?: ""
        if (layoutStr.isEmpty()) {
            return emptyList()
        }
        return layoutStr.split(",")
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
