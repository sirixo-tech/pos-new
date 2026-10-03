package com.example.my_app

import android.app.Presentation
import android.graphics.*
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.view.Display
import android.view.ViewGroup
import android.widget.ImageView
import com.imin.image.ILcdManager
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

// Ported from pos-main-web MainActivity's iMin customer display lifecycle.
class IminCustomerDisplayHandler(private val activity: FlutterActivity,
    private val displayHandler: Handler) {
    private val logTag = "POS_IMIN_DISPLAY"
    private val assets get() = activity.assets
    private var customerPresentation: Presentation? = null
    private var iminQrExpiryRunnable: Runnable? = null
    private var iminStatusRestoreRunnable: Runnable? = null
    private var iminRestaurantName: String? = null
    private var iminRestaurantLogoUrl: String? = null
    private var cachedRestaurantLogoUrl: String? = null
    private var cachedRestaurantLogo: Bitmap? = null
    @Volatile private var iminDisplayGeneration = 0L
    private var paymentActive = false
    private fun getSystemService(name: String) = activity.getSystemService(name)
    private fun runOnUiThread(action: () -> Unit) = activity.runOnUiThread(action)

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (!isIminDevice()) return false
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        when (call.method) {
            "getCustomerDisplayStatus" -> result.success(if (findCustomerDisplay() != null) "secondary_display" else "imin_lcd")
            "showUpiQr", "showUpiQrOnCustomerDisplay" -> {
                val qr = (args["qrData"] ?: args["qr"] ?: args["upiQrData"])?.toString()?.trim()
                if (qr.isNullOrEmpty()) result.error("IMIN_EMPTY_QR", "QR payload is empty", null)
                else {
                    paymentActive = true
                    rememberIminBranding(args)
                    cancelIminDisplayTimers()
                    val generation = nextIminDisplayGeneration()
                    val order = args["orderNumber"]?.toString()
                    val amount = args["amount"]?.toString()?.toDoubleOrNull()
                    val timeout = args["timeoutSeconds"]?.toString()?.toIntOrNull()
                    val bitmap = createIminCustomerDisplayBitmap(qr, order, amount, args["payeeName"]?.toString(), timeout)
                    if (showBitmapOnIminCustomerDisplay(bitmap)) {
                        scheduleIminQrExpiry(order, timeout, generation)
                        result.success(if (findCustomerDisplay() != null) "secondary_display" else "imin_lcd")
                    } else result.error("IMIN_DISPLAY_FAILED", "iMin customer display is unavailable", null)
                }
            }
            "showIdleCustomerDisplay" -> {
                rememberIminBranding(args)
                if (paymentActive) result.success(false) else showIminIdleCustomerDisplay(args, result)
            }
            "clearSubDisplay", "clearCustomerDisplay" -> {
                paymentActive = false
                cancelIminDisplayTimers()
                showIminIdleBitmapAsync { result.success(null) }
            }
            "showPaymentSuccess", "showPaymentCancelled", "showPaymentExpired" -> {
                paymentActive = false
                val success = call.method == "showPaymentSuccess"
                val expired = call.method == "showPaymentExpired"
                showIminPaymentState(args,
                    if (success) "PAYMENT SUCCESSFUL" else if (expired) "QR EXPIRED" else "PAYMENT CANCELLED",
                    if (success) "Thank you" else "Please ask staff for a new QR",
                    if (success) Color.rgb(22, 163, 74) else Color.rgb(180, 83, 9), result)
            }
            else -> return false
        }
        return true
    }
    fun destroy() {
        cancelIminDisplayTimers()
        nextIminDisplayGeneration()
        customerPresentation?.dismiss()
        customerPresentation = null
    }
    private fun showIminIdleCustomerDisplay(
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        if (!isIminDevice()) {
            // TVS and other Android customer displays keep their existing
            // vendor/LAN lifecycle.
            result.success(false)
            return
        }
        rememberIminBranding(arguments)
        cancelIminDisplayTimers()
        showIminIdleBitmapAsync { shown -> result.success(shown) }
    }

    private fun showIminPaymentState(
        arguments: Map<*, *>,
        title: String,
        detail: String,
        accentColor: Int,
        result: MethodChannel.Result,
    ) {
        if (!isIminDevice()) {
            result.success(false)
            return
        }
        rememberIminBranding(arguments)
        val orderNumber = arguments["orderNumber"]?.toString()?.trim()
        val amount = when (val value = arguments["amount"]) {
            is Number -> value.toDouble()
            else -> value?.toString()?.toDoubleOrNull()
        }
        val shown = showIminPaymentStateInternal(
            title = title,
            detail = detail,
            accentColor = accentColor,
            orderNumber = orderNumber,
            amount = amount,
        )
        result.success(shown)
    }

    private fun showIminPaymentStateInternal(
        title: String,
        detail: String,
        accentColor: Int,
        orderNumber: String?,
        amount: Double? = null,
    ): Boolean {
        paymentActive = false
        cancelIminDisplayTimers()
        val generation = nextIminDisplayGeneration()
        val bitmap = createIminPaymentStateBitmap(
            title = title,
            detail = detail,
            accentColor = accentColor,
            orderNumber = orderNumber,
            amount = amount,
        )
        val shown = showBitmapOnIminCustomerDisplay(bitmap)
        if (shown) {
            val restore = Runnable {
                if (!isCurrentIminDisplayGeneration(generation)) return@Runnable
                iminStatusRestoreRunnable = null
                showIminIdleBitmapAsync()
            }
            iminStatusRestoreRunnable = restore
            displayHandler.postDelayed(restore, 5000L)
        }
        return shown
    }

    private fun scheduleIminQrExpiry(
        orderNumber: String?,
        timeoutSeconds: Int?,
        generation: Long,
    ) {
        val seconds = timeoutSeconds?.takeIf { it > 0 } ?: return
        val expiry = Runnable {
            if (!isCurrentIminDisplayGeneration(generation)) return@Runnable
            iminQrExpiryRunnable = null
            showIminPaymentStateInternal(
                title = "QR EXPIRED",
                detail = "Please ask staff for a new QR",
                accentColor = Color.rgb(180, 83, 9),
                orderNumber = orderNumber,
            )
        }
        iminQrExpiryRunnable = expiry
        displayHandler.postDelayed(expiry, seconds * 1000L)
    }

    private fun showIminIdleBitmapAsync(onComplete: ((Boolean) -> Unit)? = null) {
        val generation = nextIminDisplayGeneration()
        val restaurantName = iminRestaurantName
        val restaurantLogoUrl = iminRestaurantLogoUrl
        Thread {
            val logo = loadIminBrandLogo(restaurantLogoUrl)
            val bitmap = createIminIdleBitmap(restaurantName, logo)
            runOnUiThread {
                if (!isCurrentIminDisplayGeneration(generation)) {
                    onComplete?.invoke(false)
                    return@runOnUiThread
                }
                val shown = showBitmapOnIminCustomerDisplay(bitmap)
                onComplete?.invoke(shown)
            }
        }.start()
    }

    private fun showBitmapOnIminCustomerDisplay(bitmap: Bitmap): Boolean {
        val display = findCustomerDisplay()
        if (display != null) {
            try {
                customerPresentation?.dismiss()
                customerPresentation = BitmapPresentation(display, bitmap)
                customerPresentation?.show()
                return true
            } catch (error: Throwable) {
                Log.e(logTag, "iMin bitmap presentation failed", error)
                customerPresentation = null
            }
        }
        return tryShowOnIminLcd(bitmap)
    }

    private fun rememberIminBranding(arguments: Map<*, *>) {
        if (arguments.containsKey("restaurantLogoUrl")) {
            val url = arguments["restaurantLogoUrl"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }
            if (iminRestaurantLogoUrl != url) {
                cachedRestaurantLogoUrl = null
                cachedRestaurantLogo = null
            }
            iminRestaurantLogoUrl = url
        }
        arguments["restaurantName"]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let {
            iminRestaurantName = it
        }
    }

    private fun cancelIminDisplayTimers() {
        iminQrExpiryRunnable?.let(displayHandler::removeCallbacks)
        iminStatusRestoreRunnable?.let(displayHandler::removeCallbacks)
        iminQrExpiryRunnable = null
        iminStatusRestoreRunnable = null
    }

    private fun nextIminDisplayGeneration(): Long {
        iminDisplayGeneration += 1
        return iminDisplayGeneration
    }

    private fun isCurrentIminDisplayGeneration(generation: Long): Boolean {
        return iminDisplayGeneration == generation
    }

    private fun loadIminBrandLogo(restaurantLogoUrl: String?): Bitmap? {
        val url = restaurantLogoUrl?.trim()?.takeIf { it.startsWith("http") }
        if (url != null && cachedRestaurantLogoUrl == url) {
            cachedRestaurantLogo?.let { return it }
        }
        if (url != null) {
            var connection: HttpURLConnection? = null
            try {
                connection = URL(url).openConnection() as HttpURLConnection
                connection.connectTimeout = 3500
                connection.readTimeout = 3500
                connection.instanceFollowRedirects = true
                connection.connect()
                if (connection.responseCode in 200..299) {
                    val decoded = connection.inputStream.use(BitmapFactory::decodeStream)
                    if (decoded != null) {
                        cachedRestaurantLogoUrl = url
                        cachedRestaurantLogo = decoded
                        return decoded
                    }
                }
            } catch (error: Throwable) {
                Log.w(logTag, "restaurant logo download failed", error)
            } finally {
                connection?.disconnect()
            }
        }
        return try {
            assets.open("flutter_assets/assets/images/mainlogo.png").use { stream ->
                BitmapFactory.decodeStream(stream)
            }
        } catch (error: Throwable) {
            Log.w(logTag, "bundled logo load failed", error)
            null
        }
    }

    private fun findCustomerDisplay(): Display? {
        val displayManager = getSystemService(android.content.Context.DISPLAY_SERVICE) as DisplayManager
        val presentationDisplays =
            displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        if (presentationDisplays.isNotEmpty()) {
            return presentationDisplays[0]
        }
        val defaultDisplayId = activity.windowManager.defaultDisplay.displayId
        return displayManager.getDisplays().firstOrNull { display ->
            display.displayId != defaultDisplayId
        }
    }

    private fun isIminDevice(): Boolean {
        val identity = listOf(
            Build.MANUFACTURER,
            Build.BRAND,
            Build.MODEL,
            Build.DEVICE,
            Build.PRODUCT,
        ).joinToString(" ").lowercase(Locale.US)
        val hasIminService = try {
            getSystemService("iminservice") != null
        } catch (_: Throwable) {
            false
        }
        val isImin = identity.contains("imin") || hasIminService
        Log.d(
            logTag,
            "device identity=$identity hasIminService=$hasIminService isImin=$isImin",
        )
        return isImin
    }

    private fun tryShowOnIminLcd(bitmap: Bitmap): Boolean {
        if (!isIminDevice()) return false
        return try {
            val lcdManager = ILcdManager.getInstance(activity)
            lcdManager.sendLCDCommand(1)
            lcdManager.sendLCDCommand(2)
            lcdManager.sendLCDCommand(4)
            lcdManager.sendLCDBitmap(bitmap)
            true
        } catch (error: Throwable) {
            Log.e(logTag, "iMin ScreenSDK display failed", error)
            false
        }
    }

    private fun createQrBitmap(text: String, size: Int): Bitmap {
        val hints = mapOf(EncodeHintType.MARGIN to 1)
        val matrix = MultiFormatWriter().encode(
            text,
            BarcodeFormat.QR_CODE,
            size,
            size,
            hints,
        )
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        for (x in 0 until size) {
            for (y in 0 until size) {
                bitmap.setPixel(x, y, if (matrix[x, y]) Color.BLACK else Color.WHITE)
            }
        }
        return bitmap
    }

    private fun createIminCustomerDisplayBitmap(
        qr: String,
        orderNumber: String?,
        amount: Double?,
        payeeName: String?,
        timeoutSeconds: Int?,
    ): Bitmap {
        val width = 240
        val height = 320
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }

        paint.textSize = 18f
        canvas.drawText("SCAN UPI QR", width / 2f, 22f, paint)
        amount?.let {
            paint.textSize = 24f
            canvas.drawText(
                "Rs ${String.format(Locale.US, "%.2f", it)}",
                width / 2f,
                49f,
                paint,
            )
        }

        val qrSize = 190
        val qrBitmap = createQrBitmap(qr, qrSize)
        canvas.drawBitmap(qrBitmap, ((width - qrSize) / 2).toFloat(), 57f, null)

        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textSize = 14f
        payeeName?.takeIf { it.isNotEmpty() }?.let {
            canvas.drawText(it.take(28), width / 2f, 269f, paint)
        }
        paint.typeface = Typeface.DEFAULT
        paint.textSize = 12f
        orderNumber?.takeIf { it.isNotEmpty() }?.let {
            canvas.drawText("Order ${it.take(24)}", width / 2f, 293f, paint)
        }
        timeoutSeconds?.takeIf { it > 0 }?.let {
            canvas.drawText("Valid for ${it}s", width / 2f, 312f, paint)
        }
        return bitmap
    }

    private fun trimTransparentPadding(bitmap: Bitmap): Bitmap {
        var left = bitmap.width
        var top = bitmap.height
        var right = -1
        var bottom = -1
        val pixels = IntArray(bitmap.width * bitmap.height)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        for (y in 0 until bitmap.height) for (x in 0 until bitmap.width) {
            if (Color.alpha(pixels[y * bitmap.width + x]) > 16) {
                left = minOf(left, x)
                top = minOf(top, y)
                right = maxOf(right, x)
                bottom = maxOf(bottom, y)
            }
        }
        return if (right < left) bitmap else
            Bitmap.createBitmap(bitmap, left, top, right - left + 1, bottom - top + 1)
    }

    private fun createIminIdleBitmap(
        restaurantName: String?,
        logo: Bitmap?,
    ): Bitmap {
        val width = 240
        val height = 320
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(255, 99, 25)
        }
        canvas.drawRect(0f, 0f, width.toFloat(), 10f, accentPaint)

        // Keep SELFX branding alongside the restaurant's reference template.
        try {
            val selfx = assets.open("flutter_assets/assets/images/selfx_wordmark.png").use(BitmapFactory::decodeStream)
            if (selfx != null) {
                val mark = trimTransparentPadding(selfx)
                val scale = minOf(190f / mark.width, 58f / mark.height)
                val markWidth = mark.width * scale
                canvas.drawBitmap(mark, null,
                    RectF((width - markWidth) / 2, 18f,
                        (width + markWidth) / 2, 18f + mark.height * scale),
                    Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
            }
        } catch (error: Exception) {
            Log.w(logTag, "SELFX logo unavailable", error)
        }

        if (logo != null && logo.width > 0 && logo.height > 0) {
            val maxWidth = 190f
            val maxHeight = 130f
            val scale = minOf(maxWidth / logo.width, maxHeight / logo.height)
            val drawnWidth = logo.width * scale
            val drawnHeight = logo.height * scale
            val left = (width - drawnWidth) / 2f
            val top = 88f + ((maxHeight - drawnHeight) / 2f)
            canvas.drawBitmap(
                logo,
                null,
                RectF(left, top, left + drawnWidth, top + drawnHeight),
                Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
            )
        } else {
            val markPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.rgb(255, 99, 25)
            }
            canvas.drawCircle(width / 2f, 125f, 46f, markPaint)
        }

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(30, 41, 59)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = 21f
        }
        val name = restaurantName?.takeIf { it.isNotBlank() } ?: "SELFX POS"
        canvas.drawText(name.take(26), width / 2f, 236f, textPaint)
        textPaint.typeface = Typeface.DEFAULT
        textPaint.textSize = 14f
        textPaint.color = Color.rgb(100, 116, 139)
        canvas.drawText("Welcome", width / 2f, 267f, textPaint)
        textPaint.textSize = 11f
        canvas.drawText("Ready for your order", width / 2f, 292f, textPaint)
        return bitmap
    }

    private fun createIminPaymentStateBitmap(
        title: String,
        detail: String,
        accentColor: Int,
        orderNumber: String?,
        amount: Double?,
    ): Bitmap {
        val width = 240
        val height = 320
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val accentPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accentColor }
        canvas.drawRect(0f, 0f, width.toFloat(), 12f, accentPaint)
        canvas.drawCircle(width / 2f, 87f, 43f, accentPaint)

        val symbolPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = 42f
        }
        val symbol = if (title == "PAYMENT SUCCESSFUL") "OK" else "!"
        canvas.drawText(symbol, width / 2f, 101f, symbolPaint)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(15, 23, 42)
            textAlign = Paint.Align.CENTER
            typeface = Typeface.DEFAULT_BOLD
            textSize = 18f
        }
        canvas.drawText(title, width / 2f, 157f, textPaint)
        amount?.let {
            textPaint.textSize = 22f
            textPaint.color = accentColor
            canvas.drawText(
                "Rs ${String.format(Locale.US, "%.2f", it)}",
                width / 2f,
                190f,
                textPaint,
            )
        }
        textPaint.typeface = Typeface.DEFAULT
        textPaint.textSize = 13f
        textPaint.color = Color.rgb(71, 85, 105)
        canvas.drawText(detail.take(36), width / 2f, if (amount == null) 196f else 218f, textPaint)
        orderNumber?.takeIf { it.isNotEmpty() }?.let {
            textPaint.textSize = 12f
            canvas.drawText("Order ${it.take(24)}", width / 2f, 248f, textPaint)
        }
        iminRestaurantName?.takeIf { it.isNotBlank() }?.let {
            textPaint.typeface = Typeface.DEFAULT_BOLD
            textPaint.textSize = 14f
            textPaint.color = Color.rgb(30, 41, 59)
            canvas.drawText(it.take(27), width / 2f, 292f, textPaint)
        }
        return bitmap
    }
    private inner class BitmapPresentation(
        display: Display,
        private val bitmap: Bitmap,
    ) : Presentation(activity, display) {
        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            val image = ImageView(context).apply {
                setImageBitmap(bitmap)
                scaleType = ImageView.ScaleType.FIT_CENTER
                setBackgroundColor(Color.WHITE)
            }
            setContentView(
                image,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }
    }
}
