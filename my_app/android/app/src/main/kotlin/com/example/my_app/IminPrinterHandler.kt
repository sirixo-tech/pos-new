package com.example.my_app

import android.content.Context
import android.os.Build
import android.os.Handler
import android.util.Log
import com.imin.printerlib.IminPrintUtils
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/** iMin SDK 1.x: NM2 Pro / I21M01 uses the terminal's SPI printer. */
class IminPrinterHandler(private val context: Context, private val mainHandler: Handler) {
    private val queue = Executors.newSingleThreadExecutor()
    private var initialized = false
    private val printer by lazy { IminPrintUtils.getInstance(context.applicationContext) }
    private val transport get() = if (isMobileSpiDevice())
        IminPrintUtils.PrintConnectType.SPI else IminPrintUtils.PrintConnectType.USB

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method !in listOf("getPrinterStatus", "warmUpPrinter", "warmUpSmartPos", "printEscPos")) return false
        queue.execute {
            try {
                initialize()
                val status = status()
                when (call.method) {
                    "getPrinterStatus" -> mainHandler.post { result.success(status) }
                    "warmUpPrinter", "warmUpSmartPos" -> mainHandler.post { result.success(status == "ready") }
                    "printEscPos" -> {
                        val bytes = call.arguments as? ByteArray
                        when {
                            bytes == null || bytes.isEmpty() -> mainHandler.post {
                                result.error("SMARTPOS_EMPTY_DATA", "Receipt did not contain printable data.", null)
                            }
                            status != "ready" -> mainHandler.post {
                                result.error("SMARTPOS_NOT_READY", when (status) {
                                    "paperOut" -> "Load paper in the iMin printer, then try again."
                                    "coverOpen" -> "Close the iMin printer cover, then try again."
                                    else -> "iMin printer is unavailable. Check paper and restart the terminal."
                                }, null)
                            }
                            else -> {
                                // Submit once. A retry after a transport error could duplicate a receipt.
                                printer.sendRAWData(bytes)
                                mainHandler.post { result.success(0) }
                            }
                        }
                    }
                }
            } catch (error: Throwable) {
                initialized = false
                Log.e("POS_IMIN_PRINTER", "${call.method} failed", error)
                mainHandler.post {
                    when (call.method) {
                        "getPrinterStatus" -> result.success("unavailable")
                        "warmUpPrinter", "warmUpSmartPos" -> result.success(false)
                        else -> result.error("IMIN_PRINTER_UNAVAILABLE", "iMin printer is unavailable. ${error.message ?: "Check the terminal."}", null)
                    }
                }
            }
        }
        return true
    }

    fun destroy() {
        queue.shutdown()
    }

    private fun initialize() {
        if (initialized) return
        printer.initPrinter(transport)
        // The SDK connects asynchronously; allow its first status to arrive.
        val deadline = android.os.SystemClock.elapsedRealtime() + 2000
        while (printer.getPrinterStatus(transport) == -1 && android.os.SystemClock.elapsedRealtime() < deadline) {
            Thread.sleep(100)
        }
        initialized = true
    }

    private fun status(): String {
        return when (printer.getPrinterStatus(transport)) {
            0, 8 -> "ready"
            7 -> "paperOut"
            3 -> "coverOpen"
            else -> {
                initialized = false
                "unavailable"
            }
        }
    }

    companion object {
        fun isIminDevice(): Boolean {
            val identity = "${Build.MANUFACTURER} ${Build.BRAND} ${Build.MODEL}".lowercase(Locale.ROOT)
            return identity.contains("imin") || Build.MODEL.equals("I21M01", true)
        }
        private fun isMobileSpiDevice(): Boolean {
            val model = Build.MODEL.lowercase(Locale.ROOT)
            return model == "i21m01" || ((model.contains("m2") || model.contains("m2 pro")) && !model.contains("max"))
        }
        fun deviceName(): String = if (Build.MODEL.equals("I21M01", true))
            "iMin NM2 Pro (I21M01)" else "iMin ${Build.MODEL}"
    }
}
