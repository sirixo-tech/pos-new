package com.example.my_app

import android.content.Context
import android.os.Build
import android.os.Handler
import android.util.Log
import com.imin.printerlib.IminPrintUtils
import com.imin.printerlib.Callback
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** iMin SDK 1.x inner printer. Handhelds use SPI. Counter units use USB. */
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
                var status = status()
                if (status == "unavailable") {
                    initialize()
                    status = status()
                }
                when (call.method) {
                    "getPrinterStatus" -> mainHandler.post { result.success(status) }
                    "warmUpPrinter", "warmUpSmartPos" -> mainHandler.post { result.success(status == "ready") }
                    "printEscPos" -> {
                        val bytes = call.arguments as? ByteArray
                        when {
                            bytes == null || bytes.isEmpty() -> mainHandler.post {
                                result.error("SMARTPOS_EMPTY_DATA", "Receipt did not contain printable data.", null)
                            }
                            status == "paperOut" || status == "coverOpen" -> mainHandler.post {
                                result.error("SMARTPOS_NOT_READY", when (status) {
                                    "paperOut" -> "Load paper in the iMin printer, then try again."
                                    else -> "Close the iMin printer cover, then try again."
                                }, null)
                            }
                            else -> {
                                // A status miss on the handheld must not cancel an
                                // offline ticket. Paper-out and an open cover still stop it.
                                if (status != "ready") {
                                    initialized = false
                                    initialize()
                                }
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
        initialized = true
    }

    private fun readStatus(): Int {
        if (!isMobileSpiDevice()) return printer.getPrinterStatus(transport)
        // SPI reports status through the callback, not the USB synchronous API.
        // Wait only on the worker queue; never block the Android main thread.
        val response = AtomicInteger(-1)
        val received = CountDownLatch(1)
        printer.getPrinterStatus(transport, object : Callback {
            override fun callback(value: Int) {
                response.set(value)
                received.countDown()
            }
        })
        return if (received.await(1500, TimeUnit.MILLISECONDS)) response.get() else -1
    }

    private fun status(): String {
        return when (readStatus()) {
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
            if (model.contains("max")) return false
            // Counter units with a customer screen speak USB.
            if (listOf("swan", "d1", "d3", "d4", "crane", "falcon").any { model.contains(it) }) {
                return false
            }
            return model == "i21m01" ||
                model.contains("m2") ||
                model.contains("swift") ||
                model.contains("i22") ||
                model.contains("i23")
        }

        fun paperWidth(): String {
            val model = Build.MODEL.lowercase(Locale.ROOT)
            return if (listOf("swan", "d3", "d4", "crane").any { model.contains(it) }) "80mm" else "58mm"
        }

        fun deviceName(): String = if (Build.MODEL.equals("I21M01", true))
            "iMin NM2 Pro (I21M01)" else "iMin ${Build.MODEL}"
    }
}
