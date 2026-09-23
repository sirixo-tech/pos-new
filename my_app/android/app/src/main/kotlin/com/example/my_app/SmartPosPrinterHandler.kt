package com.example.my_app

import android.os.Handler
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
    private fun ensureSdkReady(): Int {
        if (sdkReady) return SdkResult.SDK_OK
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
        }
        return status
    }

    private fun printerStatus(): String {
        if (ensureSdkReady() != SdkResult.SDK_OK) return "unavailable"
        return when (driverManager.getPrinter()?.getPrinterStatus()) {
            SdkResult.SDK_OK -> "ready"
            SdkResult.SDK_PRN_STATUS_PAPEROUT -> "paperOut"
            SdkResult.SDK_PRN_STATUS_TOOHEAT -> "overheated"
            SdkResult.SDK_PRN_STATUS_PRINTING -> "printing"
            else -> "unavailable"
        }
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
                val printer = driverManager.getPrinter()
                if (printer == null) {
                    sdkReady = false
                    finishError(
                        result,
                        "SMARTPOS_PRINTER_UNAVAILABLE",
                        "Built-in printer is unavailable. Restart the terminal and try again.",
                    )
                    return
                }
                when (printer.getPrinterStatus()) {
                    SdkResult.SDK_PRN_STATUS_PAPEROUT -> {
                        finishError(result, "SMARTPOS_PAPER_OUT", "Printer is out of paper.")
                        return
                    }
                    SdkResult.SDK_PRN_STATUS_TOOHEAT -> {
                        finishError(result, "SMARTPOS_OVERHEATED", "Printer is overheated.")
                        return
                    }
                    SdkResult.SDK_PRN_STATUS_FAULT -> {
                        finishError(result, "SMARTPOS_PRINTER_FAULT", "Printer is in a fault state.")
                        return
                    }
                }
                val printStatus = printer.printEpson(bytes)
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
}
