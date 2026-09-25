package com.example.my_app

import android.os.Handler
import android.os.SystemClock
import android.util.Log
import com.zcs.base.SmartPosJni
import com.zcs.sdk.DriverManager
import com.zcs.sdk.SdkResult
import io.flutter.plugin.common.MethodChannel

/**
 * TVS / ZCS inner printer. Same init + printEpson path as Selfx POS.
 * The built-in mechanism is JNI ([SmartPosJni]), not USB/LAN enumeration.
 */
class SmartPosPrinterHandler(
    private val mainHandler: Handler,
) {
    private val logTag = "POS_SMARTPOS"
    private val printerLock = Any()
    private val driverManager: DriverManager by lazy { DriverManager.getInstance() }
    @Volatile private var sdkReady = false
    private var nextInitAtMs = 0L
    private var initBackoffMs = 0L
    private var paperOutLatched = false
    private var nextPaperRecheckAtMs = 0L

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getPrinterStatus" -> {
                Thread {
                    try {
                        val status = synchronized(printerLock) { printerStatus() }
                        mainHandler.post { result.success(status) }
                    } catch (error: Throwable) {
                        Log.e(logTag, "getPrinterStatus failed", error)
                        mainHandler.post { result.success("unavailable") }
                    }
                }.start()
                return true
            }
            "warmUpPrinter", "warmUpSmartPos" -> {
                Thread {
                    val ready = warmUp()
                    mainHandler.post { result.success(ready) }
                }.start()
                return true
            }
            "printEscPos" -> {
                val bytes = call.arguments as? ByteArray
                if (bytes == null || bytes.isEmpty()) {
                    result.error(
                        "SMARTPOS_EMPTY_DATA",
                        "Receipt did not contain printable data.",
                        null,
                    )
                } else {
                    printEscPos(bytes, result)
                }
                return true
            }
            else -> return false
        }
    }

    @Synchronized
    private fun ensureSdkReady(force: Boolean = false): Int {
        if (sdkReady && !force) return SdkResult.SDK_OK
        val now = SystemClock.elapsedRealtime()
        if (!force && now < nextInitAtMs) return INIT_WAITING
        val jni = SmartPosJni.createClass()
        driverManager.setJni(jni)
        val sys = driverManager.getBaseSysDevice()
        var status = sys.sdkInit()
        Log.d(logTag, "sdkInit status=$status")
        if (status != SdkResult.SDK_OK) {
            sys.sysPowerOn()
            Thread.sleep(1000)
            status = sys.sdkInit()
            Log.d(logTag, "sdkInit after sysPowerOn status=$status")
        }
        if (status == SdkResult.SDK_OK) {
            sys.showDetailLog(true)
            sdkReady = true
            initBackoffMs = 0L
            nextInitAtMs = 0L
        } else {
            noteInitFailure()
        }
        return status
    }

    private fun noteInitFailure() {
        sdkReady = false
        initBackoffMs = when {
            initBackoffMs <= 0L -> 2_000L
            initBackoffMs < 5_000L -> 5_000L
            else -> 15_000L
        }
        nextInitAtMs = SystemClock.elapsedRealtime() + initBackoffMs
    }

    private fun mapPrinterStatus(code: Int?): String = when (code) {
        SdkResult.SDK_OK -> "ready"
        SdkResult.SDK_PRN_STATUS_PAPEROUT -> "paperOut"
        SdkResult.SDK_PRN_STATUS_TOOHEAT -> "overheated"
        SdkResult.SDK_PRN_STATUS_PRINTING -> "printing"
        else -> "unavailable"
    }

    private fun notePaperOut() {
        paperOutLatched = true
        nextPaperRecheckAtMs = SystemClock.elapsedRealtime() + PAPER_RECHECK_MS
    }

    private fun clearPaperOut() {
        paperOutLatched = false
        nextPaperRecheckAtMs = 0L
    }

    /// After paper-out, the SDK handle keeps the empty-roll result. A fresh
    /// sdkInit is the same read a reinstall gets. While the roll is still out,
    /// wait before starting the SDK again.
    private fun currentStatus(forcePaperRecheck: Boolean): String {
        val now = SystemClock.elapsedRealtime()
        val recheck = forcePaperRecheck || (paperOutLatched && now >= nextPaperRecheckAtMs)
        if (paperOutLatched && !recheck) return "paperOut"
        if (recheck) sdkReady = false
        if (ensureSdkReady(force = recheck) != SdkResult.SDK_OK) return "unavailable"
        val mapped = mapPrinterStatus(driverManager.getPrinter()?.getPrinterStatus())
        when (mapped) {
            "paperOut" -> notePaperOut()
            "ready", "printing" -> clearPaperOut()
        }
        return mapped
    }

    private fun printerStatus(): String {
        val mapped = currentStatus(forcePaperRecheck = false)
        if (mapped != "unavailable") return mapped
        // Power cycle, pulled roll, or a dropped inner mechanism leaves a stale
        // SDK handle. Drop it and init once more, then back off if it is still down.
        sdkReady = false
        if (ensureSdkReady(force = true) != SdkResult.SDK_OK) return "unavailable"
        val recovered = mapPrinterStatus(driverManager.getPrinter()?.getPrinterStatus())
        when (recovered) {
            "paperOut" -> notePaperOut()
            "ready", "printing" -> clearPaperOut()
            "unavailable" -> {
                sdkReady = false
                noteInitFailure()
            }
        }
        return recovered
    }

    private fun warmUp(): Boolean {
        return try {
            val initStatus = ensureSdkReady()
            if (initStatus != SdkResult.SDK_OK) {
                Log.e(logTag, "warmUp init failed status=$initStatus")
                return false
            }
            synchronized(printerLock) {
                driverManager.getPrinter()
            }
            true
        } catch (error: Throwable) {
            Log.e(logTag, "warmUp exception", error)
            false
        }
    }

    private fun printEscPos(bytes: ByteArray, result: MethodChannel.Result) {
        try {
            synchronized(printerLock) {
                val initStatus = ensureSdkReady()
                if (initStatus != SdkResult.SDK_OK) {
                    finishError(
                        result,
                        "SMARTPOS_INIT_FAILED",
                        "SmartPOS SDK initialization failed: $initStatus",
                    )
                    return
                }
                var printer = driverManager.getPrinter()
                if (printer == null) {
                    sdkReady = false
                    if (ensureSdkReady(force = true) != SdkResult.SDK_OK) {
                        finishError(
                            result,
                            "SMARTPOS_PRINTER_UNAVAILABLE",
                            "Built-in printer is unavailable. Restart the terminal and try again.",
                        )
                        return
                    }
                    printer = driverManager.getPrinter()
                }
                if (printer == null) {
                    sdkReady = false
                    noteInitFailure()
                    finishError(
                        result,
                        "SMARTPOS_PRINTER_UNAVAILABLE",
                        "Built-in printer is unavailable. Restart the terminal and try again.",
                    )
                    return
                }
                var active = printer
                var statusCode = active.getPrinterStatus()
                if (statusCode == SdkResult.SDK_PRN_STATUS_PAPEROUT) {
                    val now = SystemClock.elapsedRealtime()
                    if (!paperOutLatched || now >= nextPaperRecheckAtMs) {
                        sdkReady = false
                        if (ensureSdkReady(force = true) != SdkResult.SDK_OK) {
                            finishError(
                                result,
                                "SMARTPOS_PRINTER_UNAVAILABLE",
                                "Built-in printer is unavailable. Restart the terminal and try again.",
                            )
                            return
                        }
                        val refreshed = driverManager.getPrinter()
                        if (refreshed == null) {
                            sdkReady = false
                            noteInitFailure()
                            finishError(
                                result,
                                "SMARTPOS_PRINTER_UNAVAILABLE",
                                "Built-in printer is unavailable. Restart the terminal and try again.",
                            )
                            return
                        }
                        active = refreshed
                        statusCode = active.getPrinterStatus()
                    }
                }
                when (statusCode) {
                    SdkResult.SDK_PRN_STATUS_PAPEROUT -> {
                        notePaperOut()
                        finishError(result, "SMARTPOS_PAPER_OUT", "Printer is out of paper.")
                        return
                    }
                    SdkResult.SDK_PRN_STATUS_TOOHEAT -> {
                        finishError(result, "SMARTPOS_OVERHEATED", "Printer is overheated.")
                        return
                    }
                    SdkResult.SDK_PRN_STATUS_FAULT -> {
                        sdkReady = false
                        noteInitFailure()
                        finishError(result, "SMARTPOS_PRINTER_FAULT", "Printer is in a fault state.")
                        return
                    }
                    else -> clearPaperOut()
                }
                val printStatus = active.printEpson(bytes)
                if (printStatus != SdkResult.SDK_OK) {
                    finishError(
                        result,
                        "SMARTPOS_PRINT_FAILED",
                        "SmartPOS print failed: $printStatus",
                    )
                    return
                }
            }
            mainHandler.post { result.success(bytes.size) }
        } catch (error: Throwable) {
            sdkReady = false
            noteInitFailure()
            Log.e(logTag, "print exception", error)
            finishError(
                result,
                "SMARTPOS_EXCEPTION",
                "Built-in printer is unavailable. ${error.message ?: error.javaClass.simpleName}",
            )
        }
    }

    private fun finishError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }

    private companion object {
        const val INIT_WAITING = -2
        const val PAPER_RECHECK_MS = 3_000L
    }
}
