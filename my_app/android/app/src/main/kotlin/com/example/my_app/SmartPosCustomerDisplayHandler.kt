package com.example.my_app

import android.app.Presentation
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import com.imin.image.ILcdManager
import com.zcs.base.SmartPosJni
import com.zcs.sdk.DriverManager
import com.zcs.sdk.SdkResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * TVS / ZCS customer-facing screen. Same LCD + Android Presentation path as Selfx.
 */
class SmartPosCustomerDisplayHandler(
    private val activity: FlutterActivity,
    private val mainHandler: Handler,
) {
    private val logTag = "POS_SMARTPOS_DISPLAY"
    private val iminDisplay = IminCustomerDisplayHandler(activity, mainHandler)
    private val driverManager: DriverManager by lazy { DriverManager.getInstance() }
    @Volatile private var sdkReady = false
    private var customerPresentation: Presentation? = null

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result): Boolean {
        if (iminDisplay.handle(call, result)) return true
        when (call.method) {
            "showUpiQr", "showUpiQrOnCustomerDisplay" -> {
                val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val qr = (
                    arguments["qr"]
                        ?: arguments["qrData"]
                        ?: arguments["upiQrData"]
                    )?.toString()?.trim()
                if (qr.isNullOrEmpty()) {
                    result.error("SMARTPOS_EMPTY_QR", "UPI QR payload was empty.", null)
                } else {
                    showUpiQr(arguments, qr, result)
                }
                return true
            }
            "clearSubDisplay", "clearCustomerDisplay" -> {
                clearDisplay(result)
                return true
            }
            "getCustomerDisplayStatus" -> {
                val mode = when {
                    findCustomerDisplay() != null -> "secondary_display"
                    isIminDevice() -> "imin_lcd"
                    else -> "none"
                }
                result.success(mode)
                return true
            }
            "showIdleCustomerDisplay" -> {
                result.success(false)
                return true
            }
            "showPaymentCancelled",
            "showPaymentExpired",
            "showPaymentSuccess",
            -> {
                clearDisplay(result)
                return true
            }
            else -> return false
        }
    }

    fun destroy() {
        iminDisplay.destroy()
        mainHandler.post {
            customerPresentation?.dismiss()
            customerPresentation = null
        }
    }

    private fun showUpiQr(
        arguments: Map<*, *>,
        qr: String,
        result: MethodChannel.Result,
    ) {
        val orderNumber = arguments["orderNumber"]?.toString()?.trim()
        val payeeName = arguments["payeeName"]?.toString()?.trim()
        val upiId = arguments["upiId"]?.toString()?.trim()
        val amount = when (val value = arguments["amount"]) {
            is Number -> value.toDouble()
            else -> value?.toString()?.toDoubleOrNull()
        }
        val timeoutSeconds = when (val value = arguments["timeoutSeconds"]) {
            is Number -> value.toInt()
            else -> value?.toString()?.toIntOrNull()
        }

        Thread {
            try {
                if (isIminDevice()) {
                    showIminUpiQr(
                        qr,
                        orderNumber,
                        amount,
                        payeeName,
                        upiId,
                        timeoutSeconds,
                        result,
                    )
                    return@Thread
                }
                if (findCustomerDisplay() != null) {
                    val qrBitmap = createQrBitmap(qr, 520)
                    mainHandler.post {
                        if (showOnSecondaryDisplay(
                                qrBitmap,
                                orderNumber,
                                amount,
                                payeeName,
                                upiId,
                                timeoutSeconds,
                            )
                        ) {
                            result.success("secondary_display")
                            return@post
                        }
                        Thread {
                            val lcdResult = tryShowOnLcd(qr)
                            if (lcdResult == SdkResult.SDK_OK) {
                                finishSuccess(result, "lcd")
                            } else {
                                finishError(
                                    result,
                                    "SMARTPOS_LCD_FAILED",
                                    "SmartPOS customer display failed: $lcdResult",
                                )
                            }
                        }.start()
                    }
                    return@Thread
                }

                val lcdResult = tryShowOnLcd(qr)
                Log.d(logTag, "tryShowOnLcd result=$lcdResult")
                if (lcdResult == SdkResult.SDK_OK) {
                    finishSuccess(result, "lcd")
                } else {
                    finishError(
                        result,
                        "SMARTPOS_LCD_FAILED",
                        "SmartPOS customer display failed: $lcdResult",
                    )
                }
            } catch (error: Throwable) {
                Log.e(logTag, "showUpiQr failed", error)
                finishError(
                    result,
                    "SMARTPOS_LCD_EXCEPTION",
                    error.message ?: error.javaClass.simpleName,
                )
            }
        }.start()
    }

    private fun clearDisplay(result: MethodChannel.Result) {
        mainHandler.post {
            customerPresentation?.dismiss()
            customerPresentation = null

            Thread {
                try {
                    if (isIminDevice()) {
                        tryShowOnIminLcd(createIminBlankBitmap())
                    } else if (ensureSdkReady() == SdkResult.SDK_OK) {
                        driverManager.getBaseSysDevice().showLcdMainScreen()
                    }
                } catch (_: Throwable) {
                }
                finishSuccess(result, null)
            }.start()
        }
    }

    @Synchronized
    private fun ensureSdkReady(): Int {
        if (sdkReady) return SdkResult.SDK_OK
        val jni = SmartPosJni.createClass()
        driverManager.setJni(jni)
        val sys = driverManager.getBaseSysDevice()
        var status = sys.sdkInit()
        if (status != SdkResult.SDK_OK) {
            sys.sysPowerOn()
            Thread.sleep(1000)
            status = sys.sdkInit()
        }
        if (status == SdkResult.SDK_OK) {
            sys.showDetailLog(true)
            sdkReady = true
        }
        return status
    }

    private fun tryShowOnLcd(qr: String): Int {
        val initStatus = ensureSdkReady()
        if (initStatus != SdkResult.SDK_OK) return initStatus
        val bitmap = createLcdQrBitmap(qr)
        val status = driverManager.getBaseSysDevice().showBitmapOnLcd(bitmap, true)
        if (status != SdkResult.SDK_OK) {
            driverManager.getBaseSysDevice().showStringOnLcd(
                0,
                0,
                "Scan UPI QR\non main screen",
                true,
            )
        }
        return status
    }

    private fun showIminUpiQr(
        qr: String,
        orderNumber: String?,
        amount: Double?,
        payeeName: String?,
        upiId: String?,
        timeoutSeconds: Int?,
        result: MethodChannel.Result,
    ) {
        val qrBitmap = createQrBitmap(qr, 520)
        val iminBitmap = createIminCustomerDisplayBitmap(
            qr,
            orderNumber,
            amount,
            payeeName,
            timeoutSeconds,
        )
        mainHandler.post {
            if (showOnSecondaryDisplay(
                    qrBitmap,
                    orderNumber,
                    amount,
                    payeeName,
                    upiId,
                    timeoutSeconds,
                )
            ) {
                result.success("secondary_display")
                return@post
            }
            Thread {
                if (tryShowOnIminLcd(iminBitmap)) {
                    finishSuccess(result, "imin_lcd")
                } else {
                    finishError(
                        result,
                        "IMIN_DISPLAY_FAILED",
                        "iMin customer display is unavailable.",
                    )
                }
            }.start()
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
            activity.getSystemService("iminservice") != null
        } catch (_: Throwable) {
            false
        }
        return identity.contains("imin") || hasIminService
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

    private fun createIminBlankBitmap(): Bitmap {
        val bitmap = Bitmap.createBitmap(240, 320, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        return bitmap
    }

    private fun showOnSecondaryDisplay(
        qrBitmap: Bitmap,
        orderNumber: String?,
        amount: Double?,
        payeeName: String?,
        upiId: String?,
        timeoutSeconds: Int?,
    ): Boolean {
        val display = findCustomerDisplay() ?: return false
        return try {
            customerPresentation?.dismiss()
            customerPresentation = UpiQrPresentation(
                display,
                qrBitmap,
                orderNumber,
                amount,
                payeeName,
                upiId,
                timeoutSeconds,
            )
            customerPresentation?.show()
            true
        } catch (error: Throwable) {
            Log.e(logTag, "secondary presentation failed", error)
            customerPresentation = null
            false
        }
    }

    private fun findCustomerDisplay(): Display? {
        val displayManager =
            activity.getSystemService(android.content.Context.DISPLAY_SERVICE) as DisplayManager
        val presentationDisplays =
            displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        if (presentationDisplays.isNotEmpty()) return presentationDisplays[0]
        val defaultDisplayId = activity.windowManager.defaultDisplay.displayId
        return displayManager.displays.firstOrNull { it.displayId != defaultDisplayId }
    }







    private fun createQrBitmap(text: String, size: Int, margin: Int = 1): Bitmap {
        val hints = mapOf(EncodeHintType.MARGIN to margin)
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

    private fun createLcdQrBitmap(text: String): Bitmap {
        val lcdWidth = 128
        val lcdHeight = 56
        val qrSize = 56
        val qrBitmap = createQrBitmap(text, qrSize)
        val bitmap = Bitmap.createBitmap(lcdWidth, lcdHeight, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(Color.WHITE)
        val offsetX = (lcdWidth - qrSize) / 2
        for (x in 0 until qrSize) {
            for (y in 0 until qrSize) {
                bitmap.setPixel(offsetX + x, y, qrBitmap.getPixel(x, y))
            }
        }
        return bitmap
    }

    private fun finishSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun finishError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    private inner class UpiQrPresentation(
        display: Display,
        private val qrBitmap: Bitmap,
        private val orderNumber: String?,
        private val amount: Double?,
        private val payeeName: String?,
        private val upiId: String?,
        private val timeoutSeconds: Int?,
    ) : Presentation(activity, display) {
        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)
            val density = resources.displayMetrics.density
            val root = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.WHITE)
                setPadding(
                    (40 * density).toInt(),
                    (28 * density).toInt(),
                    (40 * density).toInt(),
                    (28 * density).toInt(),
                )
            }
            root.addView(label("Scan to Pay", 34f, true, Color.rgb(15, 23, 42)))
            orderNumber?.takeIf { it.isNotEmpty() }?.let {
                root.addView(label("Order $it", 18f, false, Color.rgb(71, 85, 105)))
            }
            amount?.let {
                root.addView(
                    label(
                        "Rs ${String.format(Locale.US, "%.2f", it)}",
                        42f,
                        true,
                        Color.rgb(2, 44, 34),
                    ),
                )
            }
            val imageSize = (360 * density).toInt().coerceAtMost(520)
            val image = ImageView(context).apply {
                setImageBitmap(qrBitmap)
                scaleType = ImageView.ScaleType.FIT_CENTER
                adjustViewBounds = true
                setBackgroundColor(Color.WHITE)
            }
            root.addView(
                image,
                LinearLayout.LayoutParams(imageSize, imageSize).apply {
                    topMargin = (20 * density).toInt()
                    bottomMargin = (18 * density).toInt()
                    gravity = Gravity.CENTER_HORIZONTAL
                },
            )
            payeeName?.takeIf { it.isNotEmpty() }?.let {
                root.addView(label(it, 20f, true, Color.rgb(15, 23, 42)))
            }
            upiId?.takeIf { it.isNotEmpty() }?.let {
                root.addView(label(it, 16f, false, Color.rgb(71, 85, 105)))
            }
            timeoutSeconds?.takeIf { it > 0 }?.let {
                root.addView(label("Valid for ${it}s", 15f, false, Color.rgb(100, 116, 139)))
            }
            setContentView(
                root,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ),
            )
        }

        private fun label(text: String, sizeSp: Float, bold: Boolean, color: Int): TextView {
            return TextView(context).apply {
                this.text = text
                textSize = sizeSp
                setTextColor(color)
                gravity = Gravity.CENTER
                if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
        }
    }
}
